#!/usr/bin/env bash
#
# update_code_server.sh
# ---------------------------------------------------------------------------
# Installe ou met a jour "code-server" (VS Code servi via un navigateur web,
# aucune fenetre Electron, aucun probleme de sandbox/zygote) sans droits
# root, dans l'arborescence ~/.local.
#
# Structure utilisee :
#   ~/.local/lib/code-server-<VERSION>/  -> une installation par version
#   ~/.local/bin/code-server              -> lien symbolique vers la version active
#   ~/.config/code-server/config.yaml     -> config auto-generee par code-server
#                                            (mot de passe, port, etc.) au 1er lancement
#
# Usage :
#   chmod +x update_code_server.sh
#   ./update_code_server.sh
# ---------------------------------------------------------------------------

set -euo pipefail

# --- Configuration ------------------------------------------------------------
LIB_DIR="$HOME/.local/lib"
BIN_DIR="$HOME/.local/bin"
TMP_DIR="$(mktemp -d)"
API_URL="https://api.github.com/repos/coder/code-server/releases/latest"

trap 'rm -rf "$TMP_DIR"' EXIT

# --- Couleurs -------------------------------------------------------------
GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
info()  { echo -e "${GREEN}[INFO]${NC} $*"; }
warn()  { echo -e "${YELLOW}[ATTENTION]${NC} $*"; }
error() { echo -e "${RED}[ERREUR]${NC} $*" >&2; }

require_cmd() {
    if ! command -v "$1" &>/dev/null; then
        error "La commande '$1' est requise mais introuvable."
        exit 1
    fi
}
require_cmd curl
require_cmd tar

mkdir -p "$LIB_DIR" "$BIN_DIR"

# --- Detection de l'architecture ---------------------------------------------
ARCH="$(uname -m)"
case "$ARCH" in
    x86_64) CS_ARCH="amd64" ;;
    aarch64|arm64) CS_ARCH="arm64" ;;
    *) error "Architecture non supportee par ce script : $ARCH"; exit 1 ;;
esac

# --- Recuperation de la derniere version disponible --------------------------
info "Recuperation de la derniere version de code-server..."
API_JSON="$(curl -fsSL "$API_URL")"

if command -v jq &>/dev/null; then
    LATEST_TAG="$(echo "$API_JSON" | jq -r '.tag_name')"
else
    LATEST_TAG="$(echo "$API_JSON" | grep -o '"tag_name": *"[^"]*"' | head -1 | cut -d'"' -f4)"
fi

if [[ -z "$LATEST_TAG" || "$LATEST_TAG" == "null" ]]; then
    error "Impossible de determiner la derniere version disponible."
    exit 1
fi
LATEST_VERSION="${LATEST_TAG#v}"
info "Derniere version disponible : $LATEST_VERSION"

# --- Version actuellement installee ------------------------------------------
CURRENT_VERSION=""
if [[ -x "$BIN_DIR/code-server" ]]; then
    CURRENT_VERSION="$("$BIN_DIR/code-server" --version 2>/dev/null | head -1 | awk '{print $1}')"
fi

if [[ -n "$CURRENT_VERSION" ]]; then
    info "Version actuellement installee : $CURRENT_VERSION"
else
    info "Aucune installation detectee dans $BIN_DIR"
fi

if [[ "$CURRENT_VERSION" == "$LATEST_VERSION" ]]; then
    info "code-server est deja a jour (version $CURRENT_VERSION). Rien a faire."
    exit 0
fi

if [[ -z "$CURRENT_VERSION" ]]; then
    info "Installation de code-server $LATEST_VERSION..."
else
    info "Mise a jour : $CURRENT_VERSION -> $LATEST_VERSION"
fi

# --- Telechargement et extraction --------------------------------------------
ASSET_NAME="code-server-${LATEST_VERSION}-linux-${CS_ARCH}.tar.gz"
DOWNLOAD_URL="https://github.com/coder/code-server/releases/download/${LATEST_TAG}/${ASSET_NAME}"
ARCHIVE_PATH="$TMP_DIR/$ASSET_NAME"

info "Telechargement de $ASSET_NAME (environ 190 Mo, patience)..."
curl -fL --progress-bar -o "$ARCHIVE_PATH" "$DOWNLOAD_URL"

info "Extraction..."
tar -xzf "$ARCHIVE_PATH" -C "$TMP_DIR"

SRC_DIR="$TMP_DIR/code-server-${LATEST_VERSION}-linux-${CS_ARCH}"
if [[ ! -d "$SRC_DIR" ]]; then
    error "Structure d'archive inattendue, installation annulee."
    exit 1
fi

TARGET_DIR="$LIB_DIR/code-server-${LATEST_VERSION}"
rm -rf "$TARGET_DIR"
mv "$SRC_DIR" "$TARGET_DIR"

# --- Lien symbolique dans ~/.local/bin ---------------------------------------
ln -sf "$TARGET_DIR/bin/code-server" "$BIN_DIR/code-server"
info "Lien symbolique mis a jour : $BIN_DIR/code-server -> $TARGET_DIR/bin/code-server"

# --- Nettoyage des anciennes versions (on garde uniquement la derniere) ------
for OLD_DIR in "$LIB_DIR"/code-server-*; do
    [[ -d "$OLD_DIR" ]] || continue
    if [[ "$OLD_DIR" != "$TARGET_DIR" ]]; then
        info "Suppression de l'ancienne version : $(basename "$OLD_DIR")"
        rm -rf "$OLD_DIR"
    fi
done

# --- Verification du PATH (zsh) -----------------------------------------------
if [[ ":$PATH:" != *":$BIN_DIR:"* ]]; then
    warn "$BIN_DIR n'est pas dans ton PATH actuel."
    if ! grep -q '.local/bin' "$HOME/.zshrc" 2>/dev/null; then
        echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.zshrc"
        warn "Ligne ajoutee a ~/.zshrc. Recharge ton shell avec : source ~/.zshrc"
    else
        warn "Une entree .local/bin semble deja presente dans ~/.zshrc."
    fi
fi

# --- Message final -------------------------------------------------------------
INSTALLED_CHECK="$("$BIN_DIR/code-server" --version | head -1)"
info "code-server installe/mis a jour avec succes : $INSTALLED_CHECK"
echo
info "Pour le lancer :"
echo "    code-server"
echo
info "Il ecoutera par defaut sur http://127.0.0.1:8080"
info "Le mot de passe genere automatiquement se trouve dans :"
echo "    ~/.config/code-server/config.yaml"
info "Ouvre ensuite cette adresse dans ton navigateur (Firefox, etc.)."
