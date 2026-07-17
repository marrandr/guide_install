#!/usr/bin/env bash
#
# update_vscode.sh
# ---------------------------------------------------------------------------
# Installe ou met a jour VS Code (Stable, linux-x64) sans droits root,
# dans l'arborescence ~/.local (utile pour 42 / Ubuntu 24.04 / zsh).
#
# Structure utilisee (respecte la convention XDG ~/.local) :
#   ~/.local/share/vscode/        -> contenu de l'archive VS Code (l'appli)
#   ~/.local/bin/code              -> lien symbolique vers le binaire "code"
#   ~/.local/share/applications/   -> fichier .desktop (menu, optionnel)
#   ~/.local/share/vscode/.version -> version actuellement installee (cache)
#
# Usage :
#   chmod +x update_vscode.sh
#   ./update_vscode.sh
# ---------------------------------------------------------------------------

set -euo pipefail

# --- Configuration ----------------------------------------------------------
INSTALL_DIR="$HOME/.local/share/vscode"
BIN_DIR="$HOME/.local/bin"
DESKTOP_DIR="$HOME/.local/share/applications"
TMP_DIR="$(mktemp -d)"
ARCHIVE_URL="https://update.code.visualstudio.com/latest/linux-x64/stable"
# On interroge l'API "update" avec un faux hash de commit (40 zeros) : comme
# aucune installation locale n'a jamais ce hash, le service repond toujours
# avec les infos de la toute derniere version disponible.
API_URL="https://update.code.visualstudio.com/api/update/linux-x64/stable/0000000000000000000000000000000000000000"

trap 'rm -rf "$TMP_DIR"' EXIT

# --- Couleurs pour les messages ---------------------------------------------
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

info()  { echo -e "${GREEN}[INFO]${NC} $*"; }
warn()  { echo -e "${YELLOW}[ATTENTION]${NC} $*"; }
error() { echo -e "${RED}[ERREUR]${NC} $*" >&2; }

# --- Verification des dependances -------------------------------------------
require_cmd() {
    if ! command -v "$1" &>/dev/null; then
        error "La commande '$1' est requise mais introuvable. Installe-la (ex: sudo apt install $1) ou demande a un admin du poste."
        exit 1
    fi
}
require_cmd curl
require_cmd tar

HAS_JQ=1
if ! command -v jq &>/dev/null; then
    HAS_JQ=0
    warn "jq n'est pas installe : le script utilisera une extraction de version moins fiable (grep/sed)."
fi

mkdir -p "$INSTALL_DIR" "$BIN_DIR" "$DESKTOP_DIR"

# --- Recuperation des infos de la derniere version disponible ---------------
info "Recuperation des informations sur la derniere version de VS Code..."
API_JSON="$(curl -fsSL "$API_URL")"

if [[ "$HAS_JQ" -eq 1 ]]; then
    LATEST_VERSION="$(echo "$API_JSON" | jq -r '.productVersion')"
    LATEST_HASH="$(echo "$API_JSON" | jq -r '.version')"
else
    LATEST_VERSION="$(echo "$API_JSON" | grep -o '"productVersion":"[^"]*"' | head -1 | cut -d'"' -f4)"
    LATEST_HASH="$(echo "$API_JSON" | grep -o '"version":"[^"]*"' | head -1 | cut -d'"' -f4)"
fi

if [[ -z "$LATEST_VERSION" ]]; then
    error "Impossible de determiner la derniere version disponible. Verifie ta connexion reseau."
    exit 1
fi

info "Derniere version disponible : $LATEST_VERSION (build $LATEST_HASH)"

# --- Detection de la version actuellement installee -------------------------
CURRENT_VERSION=""
if [[ -x "$INSTALL_DIR/bin/code" ]]; then
    if [[ -f "$INSTALL_DIR/resources/app/package.json" ]]; then
        if [[ "$HAS_JQ" -eq 1 ]]; then
            CURRENT_VERSION="$(jq -r '.version' "$INSTALL_DIR/resources/app/package.json")"
        else
            CURRENT_VERSION="$(grep -o '"version": *"[^"]*"' "$INSTALL_DIR/resources/app/package.json" | head -1 | cut -d'"' -f4)"
        fi
    fi
fi

if [[ -n "$CURRENT_VERSION" ]]; then
    info "Version actuellement installee : $CURRENT_VERSION"
else
    info "Aucune installation de VS Code detectee dans $INSTALL_DIR"
fi

# --- Decision : installer / mettre a jour / ne rien faire --------------------
if [[ "$CURRENT_VERSION" == "$LATEST_VERSION" ]]; then
    info "VS Code est deja a jour (version $CURRENT_VERSION). Rien a faire."
    exit 0
fi

if [[ -z "$CURRENT_VERSION" ]]; then
    info "Installation de VS Code $LATEST_VERSION..."
else
    info "Mise a jour de VS Code : $CURRENT_VERSION -> $LATEST_VERSION"
fi

# --- Telechargement et extraction -------------------------------------------
ARCHIVE_PATH="$TMP_DIR/vscode.tar.gz"
info "Telechargement de l'archive (cela peut prendre un moment)..."
curl -fL --progress-bar -o "$ARCHIVE_PATH" "$ARCHIVE_URL"

info "Extraction de l'archive..."
EXTRACT_DIR="$TMP_DIR/extracted"
mkdir -p "$EXTRACT_DIR"
tar -xzf "$ARCHIVE_PATH" -C "$EXTRACT_DIR"

# L'archive contient un unique dossier "VSCode-linux-x64"
SRC_DIR="$(find "$EXTRACT_DIR" -maxdepth 1 -type d -name 'VSCode-linux-x64')"
if [[ -z "$SRC_DIR" ]]; then
    error "Structure d'archive inattendue, installation annulee."
    exit 1
fi

# --- Remplacement propre de l'installation existante -------------------------
info "Mise en place dans $INSTALL_DIR..."
rm -rf "$INSTALL_DIR"
mkdir -p "$(dirname "$INSTALL_DIR")"
mv "$SRC_DIR" "$INSTALL_DIR"

# --- Wrapper dans ~/.local/bin ----------------------------------------------
# Un simple lien symbolique ne suffit pas : sans droits root, le binaire
# "chrome-sandbox" ne peut pas obtenir le bit setuid dont il a besoin, et
# Electron plante au demarrage (crashpad / "trace trap"). On force donc
# --no-sandbox via un petit script wrapper plutot qu'un lien direct.
cat > "$BIN_DIR/code" <<EOF
#!/usr/bin/env bash
exec "$INSTALL_DIR/bin/code" --no-sandbox "\$@"
EOF
chmod +x "$BIN_DIR/code"
info "Wrapper cree : $BIN_DIR/code (lance avec --no-sandbox, requis sans droits root)"

# --- Fichier .desktop (integration menu, optionnel) --------------------------
ICON_PATH="$INSTALL_DIR/resources/app/resources/linux/code.png"
DESKTOP_FILE="$DESKTOP_DIR/code.desktop"
cat > "$DESKTOP_FILE" <<EOF
[Desktop Entry]
Name=Visual Studio Code
Comment=Editeur de code (installation locale ~/.local)
Exec=$INSTALL_DIR/bin/code --no-sandbox %F
Icon=$ICON_PATH
Terminal=false
Type=Application
Categories=Development;IDE;
StartupWMClass=Code
EOF
info "Fichier .desktop cree : $DESKTOP_FILE"

# --- Verification que ~/.local/bin est dans le PATH (zsh) -------------------
if [[ ":$PATH:" != *":$BIN_DIR:"* ]]; then
    warn "$BIN_DIR n'est pas dans ton PATH actuel."
    if ! grep -q '.local/bin' "$HOME/.zshrc" 2>/dev/null; then
        echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.zshrc"
        warn "Ligne ajoutee a ~/.zshrc. Recharge ton shell avec : source ~/.zshrc"
    else
        warn "Une entree .local/bin semble deja presente dans ~/.zshrc, mais le PATH courant n'est pas a jour. Fais : source ~/.zshrc"
    fi
fi

# --- Verification finale -----------------------------------------------------
INSTALLED_VERSION_CHECK="$("$INSTALL_DIR/bin/code" --version | head -1)"
info "VS Code installe avec succes. Version : $INSTALLED_VERSION_CHECK"
info "Lance-le avec la commande : code"
