#!/usr/bin/env bash
# ==============================================================================
# setup-js-env.sh
#
# Verifie / installe un environnement JavaScript complet (nvm, node LTS,
# npm, pnpm) SANS droits root, en gardant tout ce qui prend de la place
# (caches, store pnpm) dans goinfre, et les binaires/installations dans
# ~/.local pour rester dispo meme apres un reboot (goinfre est efface a
# la deconnexion sur les postes 42).
#
# A relancer sur n'importe quel poste 42 : il ne reinstalle que ce qui
# manque et ne casse rien si c'est deja en place.
# ==============================================================================

set -eo pipefail
# Note : pas de "set -u" (nounset) ici, car nvm.sh utilise en interne des
# variables non initialisees dans certains cas (ex: PROVIDED_VERSION) -
# c'est un comportement connu et sans danger, mais incompatible avec -u.

# ---- Chemins (adapte ici si besoin) -----------------------------------------
GOINFRE="/home/marrandr/goinfre"
LOCAL="/home/marrandr/.local"

NVM_DIR="$LOCAL/nvm"                 # nvm lui-meme (petit, reste dans .local)
NPM_CACHE_DIR="$GOINFRE/npm-cache"   # cache npm (gros, va dans goinfre)
PNPM_HOME="$LOCAL/share/pnpm"        # binaire pnpm (petit)
PNPM_STORE_DIR="$GOINFRE/pnpm-store" # store des packages pnpm (gros)
NPM_GLOBAL_PREFIX="$LOCAL"           # packages installes en -g (npm install -g)

ZSHRC="$HOME/.zshrc"
MARK_START="# >>> 42-js-env (genere par setup-js-env.sh) >>>"
MARK_END="# <<< 42-js-env <<<"

NVM_VERSION="v0.40.1"  # derniere version stable de nvm au moment de l'ecriture

# ---- Petits helpers ----------------------------------------------------------
info() { printf '\033[1;34m==>\033[0m %s\n' "$1"; }
ok()   { printf '\033[1;32m[ok]\033[0m %s\n' "$1"; }

mkdir -p "$GOINFRE" "$LOCAL" "$NVM_DIR" "$NPM_CACHE_DIR" "$PNPM_HOME" "$PNPM_STORE_DIR"

# ------------------------------------------------------------------------------
# 1. NVM
# ------------------------------------------------------------------------------
info "Verification de nvm dans $NVM_DIR"
export NVM_DIR

if [ -s "$NVM_DIR/nvm.sh" ]; then
    ok "nvm deja installe."
else
    info "nvm absent, installation (telechargement du script officiel)..."
    PROFILE=/dev/null curl -o- \
        "https://raw.githubusercontent.com/nvm-sh/nvm/${NVM_VERSION}/install.sh" | bash
fi

# Charger nvm dans CE script (indispensable pour la suite)
# shellcheck disable=SC1091
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

if ! command -v nvm >/dev/null 2>&1; then
    echo "Erreur : nvm ne s'est pas charge correctement. Verifie $NVM_DIR/nvm.sh" >&2
    exit 1
fi

# ------------------------------------------------------------------------------
# 2. Node.js (derniere LTS stable)
# ------------------------------------------------------------------------------
info "Verification de Node.js (derniere version LTS)"
if nvm ls --no-colors 2>/dev/null | grep -q 'lts/\*' ; then
    ok "Une version LTS est deja installee via nvm : $(nvm current)"
else
    info "Installation de la derniere version LTS de Node..."
fi
nvm install --lts >/dev/null
nvm use --lts >/dev/null
nvm alias default 'lts/*' >/dev/null

ok "Node actif : $(node -v)  (npm fourni : $(npm -v))"

# ------------------------------------------------------------------------------
# 3. npm : cache dans goinfre, prefix global dans .local
# ------------------------------------------------------------------------------
info "Configuration de npm (cache -> goinfre)"
npm config set cache "$NPM_CACHE_DIR" --global
ok "npm cache=$(npm config get cache)"
# NB: on ne touche PAS a 'prefix' ici : nvm gere deja un dossier global par
# version de Node, situe dans $NVM_DIR/versions/node/vX.X.X/lib/node_modules.
# Comme NVM_DIR est deja sous .local, les packages globaux npm sont donc
# deja hors du home sans rien configurer de plus. Forcer un prefix casse
# le mecanisme de nvm (message "incompatible with nvm").

# Si un prefix/globalconfig avait ete force par erreur precedemment
# (par une version anterieure de ce script, par exemple), on le nettoie
# pour ne pas rester dans un etat casse :
CURRENT_NODE_VERSION="$(nvm current)"
EXISTING_PREFIX="$(npm config get prefix --global 2>/dev/null || true)"
if [ -n "$EXISTING_PREFIX" ] && [ "$EXISTING_PREFIX" != "null" ]; then
    info "Nettoyage d'un ancien prefix npm incompatible avec nvm..."
    nvm use --delete-prefix "$CURRENT_NODE_VERSION" --silent || true
    npm config delete prefix --global 2>/dev/null || true
    npm config delete globalconfig --global 2>/dev/null || true
fi

# ------------------------------------------------------------------------------
# 4. pnpm : via corepack (fourni par Node) si possible, sinon via npm
# ------------------------------------------------------------------------------
info "Verification de pnpm"
export PNPM_HOME
export PATH="$PNPM_HOME:$PNPM_HOME/bin:$NPM_GLOBAL_PREFIX/bin:$PATH"

if command -v pnpm >/dev/null 2>&1; then
    ok "pnpm deja installe : $(pnpm -v)"
else
    info "pnpm absent, installation..."
    if command -v corepack >/dev/null 2>&1; then
        corepack enable --install-directory "$NPM_GLOBAL_PREFIX/bin" || true
        corepack prepare pnpm@latest --activate
    else
        npm install -g pnpm
    fi
fi

if command -v pnpm >/dev/null 2>&1; then
    pnpm config set store-dir "$PNPM_STORE_DIR" --global
    ok "pnpm store-dir=$(pnpm config get store-dir)"
else
    echo "Attention : pnpm ne semble pas accessible dans le PATH apres installation." >&2
fi

# ------------------------------------------------------------------------------
# 5. Persistance dans ~/.zshrc (idempotent : ne duplique jamais le bloc)
# ------------------------------------------------------------------------------
info "Mise a jour de $ZSHRC"

if grep -qF "$MARK_START" "$ZSHRC" 2>/dev/null; then
    ok "Bloc de config deja present dans $ZSHRC (rien a faire)."
else
    {
        echo ""
        echo "$MARK_START"
        echo "export NVM_DIR=\"$NVM_DIR\""
        echo "[ -s \"\$NVM_DIR/nvm.sh\" ] && \\. \"\$NVM_DIR/nvm.sh\""
        echo "export PNPM_HOME=\"$PNPM_HOME\""
        echo "export PATH=\"$NPM_GLOBAL_PREFIX/bin:\$PNPM_HOME:\$PNPM_HOME/bin:\$PATH\""
        echo "$MARK_END"
    } >> "$ZSHRC"
    ok "Bloc ajoute a $ZSHRC. Fais 'source ~/.zshrc' ou ouvre un nouveau terminal."
fi

# ------------------------------------------------------------------------------
# 6. Recapitulatif
# ------------------------------------------------------------------------------
echo ""
info "Recapitulatif"
echo "  nvm     : $NVM_DIR"
echo "  node    : $(node -v)"
echo "  npm     : $(npm -v)  (cache: $NPM_CACHE_DIR)"
if command -v pnpm >/dev/null 2>&1; then
    echo "  pnpm    : $(pnpm -v)  (store: $PNPM_STORE_DIR)"
fi
echo ""
echo "Note : Next.js (create-next-app) et Nest CLI (@nestjs/cli) ne sont pas"
echo "installes ici, car ce sont normalement des dependances de PROJET"
echo "(package.json), pas des outils globaux. npm/pnpm les installeront"
echo "automatiquement dans le cache goinfre configure ci-dessus des que tu"
echo "feras 'npm install' / 'pnpm install' dans le repo VoxFlip."
echo ""
ok "Environnement JS pret."
