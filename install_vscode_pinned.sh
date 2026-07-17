#!/usr/bin/env bash
#
# install_vscode_pinned.sh
# ---------------------------------------------------------------------------
# Supprime completement l'installation VS Code existante dans ~/.local et
# installe une version PRECISE et FIGEE (pinned), au lieu de la derniere
# version stable. Utile car les toutes dernieres versions (1.108+) ont un
# bug connu sur Ubuntu 24.04 : crash du process principal + boucle infinie
# de processus "zygote" orphelins (voir microsoft/vscode#288893).
#
# Structure installee (sous ~/.local) :
#   ~/.local/share/vscode/        -> contenu de l'archive VS Code (l'appli)
#   ~/.local/bin/code              -> wrapper qui lance code avec les bons flags
#   ~/.local/share/applications/   -> fichier .desktop (menu, optionnel)
#
# Usage :
#   chmod +x install_vscode_pinned.sh
#   ./install_vscode_pinned.sh [VERSION]
#
# Exemple :
#   ./install_vscode_pinned.sh 1.103.0
#   (si aucune version n'est donnee, 1.103.0 est utilisee par defaut)
# ---------------------------------------------------------------------------

set -euo pipefail

# --- Configuration ----------------------------------------------------------
VERSION="${1:-1.103.0}"
INSTALL_DIR="$HOME/.local/share/vscode"
BIN_DIR="$HOME/.local/bin"
DESKTOP_DIR="$HOME/.local/share/applications"
TMP_DIR="$(mktemp -d)"
ARCHIVE_URL="https://update.code.visualstudio.com/${VERSION}/linux-x64/stable"

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
        error "La commande '$1' est requise mais introuvable."
        exit 1
    fi
}
require_cmd curl
require_cmd tar

# --- Etape 1 : tuer tout processus VS Code existant --------------------------
info "Arret de toute instance de VS Code en cours d'execution..."
pkill -9 -f "$INSTALL_DIR/bin/code" 2>/dev/null || true
pkill -9 -f "vscode/bin/code" 2>/dev/null || true
sleep 1

# --- Etape 2 : suppression complete de l'installation existante -------------
info "Suppression de l'installation existante..."
rm -rf "$INSTALL_DIR"
rm -f "$BIN_DIR/code"
rm -f "$DESKTOP_DIR/code.desktop"

# Optionnel : purge des donnees utilisateur (extensions, settings, cache).
# Decommente les lignes suivantes si tu veux repartir totalement a zero
# (attention, ca supprime aussi tes extensions et tes preferences) :
# rm -rf "$HOME/.config/Code"
# rm -rf "$HOME/.vscode"

info "Ancienne installation supprimee."

# --- Etape 3 : telechargement de la version figee ---------------------------
mkdir -p "$INSTALL_DIR" "$BIN_DIR" "$DESKTOP_DIR"

info "Telechargement de VS Code $VERSION..."
ARCHIVE_PATH="$TMP_DIR/vscode.tar.gz"
if ! curl -fL --progress-bar -o "$ARCHIVE_PATH" "$ARCHIVE_URL"; then
    error "Echec du telechargement. Verifie que la version '$VERSION' existe bien"
    error "(voir https://code.visualstudio.com/updates pour la liste des versions)."
    exit 1
fi

info "Extraction de l'archive..."
EXTRACT_DIR="$TMP_DIR/extracted"
mkdir -p "$EXTRACT_DIR"
tar -xzf "$ARCHIVE_PATH" -C "$EXTRACT_DIR"

SRC_DIR="$(find "$EXTRACT_DIR" -maxdepth 1 -type d -name 'VSCode-linux-x64')"
if [[ -z "$SRC_DIR" ]]; then
    error "Structure d'archive inattendue, installation annulee."
    exit 1
fi

rmdir "$INSTALL_DIR" 2>/dev/null || true
mv "$SRC_DIR" "$INSTALL_DIR"
info "VS Code $VERSION installe dans $INSTALL_DIR"

# --- Etape 4 : wrapper avec les flags necessaires ----------------------------
# --no-sandbox : requis car chrome-sandbox ne peut pas avoir le bit setuid
#                sans droits root.
# --disable-gpu / --disable-gpu-sandbox : evite les soucis de rendu GPU dans
#                un environnement conteneurise/restreint.
# --disable-crash-reporter : evite que crashpad ne parte en boucle si un
#                crash survient malgre tout.
cat > "$BIN_DIR/code" <<EOF
#!/usr/bin/env bash
exec "$INSTALL_DIR/bin/code" --no-sandbox --disable-gpu --disable-gpu-sandbox --disable-crash-reporter "\$@"
EOF
chmod +x "$BIN_DIR/code"
info "Wrapper cree : $BIN_DIR/code"

# --- Etape 5 : fichier .desktop (menu, optionnel) ---------------------------
ICON_PATH="$INSTALL_DIR/resources/app/resources/linux/code.png"
cat > "$DESKTOP_DIR/code.desktop" <<EOF
[Desktop Entry]
Name=Visual Studio Code ($VERSION)
Comment=Editeur de code (installation locale figee ~/.local)
Exec=$BIN_DIR/code %F
Icon=$ICON_PATH
Terminal=false
Type=Application
Categories=Development;IDE;
StartupWMClass=Code
EOF
info "Fichier .desktop cree."

# --- Etape 6 : verification du PATH (zsh) -----------------------------------
if [[ ":$PATH:" != *":$BIN_DIR:"* ]]; then
    warn "$BIN_DIR n'est pas dans ton PATH actuel."
    if ! grep -q '.local/bin' "$HOME/.zshrc" 2>/dev/null; then
        echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.zshrc"
        warn "Ligne ajoutee a ~/.zshrc. Recharge ton shell avec : source ~/.zshrc"
    else
        warn "Une entree .local/bin semble deja presente dans ~/.zshrc."
    fi
fi

# --- Verification finale -----------------------------------------------------
info "Test de lancement (--version, ne demarre pas l'interface graphique)..."
INSTALLED_VERSION_CHECK="$("$INSTALL_DIR/bin/code" --no-sandbox --version | head -1)"
info "VS Code installe avec succes. Version : $INSTALLED_VERSION_CHECK"
info "Lance-le avec la commande : code"
