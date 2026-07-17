#!/usr/bin/env bash
#
# cleanup_lazyvim.sh
# ---------------------------------------------------------------------------
# Nettoyage complet de tout ce qui a ete installe/cree par install_lazyvim.sh,
# pour repartir sur une base propre. Ne touche a rien en dehors de ce que le
# script d'installation a lui-meme cree (aucun droit root requis/utilise).
#
# Par defaut, chaque etape demande une confirmation. Utilise --yes pour tout
# accepter sans prompt (utile si tu es sur que tu veux tout supprimer).
#
# Usage :
#   chmod +x cleanup_lazyvim.sh
#   ./cleanup_lazyvim.sh          # interactif, demande a chaque etape
#   ./cleanup_lazyvim.sh --yes    # supprime tout sans demander
# ---------------------------------------------------------------------------

set -uo pipefail

AUTO_YES=0
[[ "${1:-}" == "--yes" || "${1:-}" == "-y" ]] && AUTO_YES=1

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
info()  { echo -e "${GREEN}[INFO]${NC} $*"; }
warn()  { echo -e "${YELLOW}[ATTENTION]${NC} $*"; }
error() { echo -e "${RED}[ERREUR]${NC} $*" >&2; }

LOCAL_BIN="$HOME/.local/bin"
LOCAL_LIB="$HOME/.local/lib"
LOCAL_SHARE="$HOME/.local/share"
STATE_DIR="$HOME/.local/state/lazyvim_bootstrap"
LOG_FILE="$HOME/.local/state/lazyvim_install.log"
NVIM_CONFIG="$HOME/.config/nvim"

confirm() {
    local prompt="$1"
    if [[ "$AUTO_YES" -eq 1 ]]; then
        return 0
    fi
    read -r -p "$prompt [o/N] " reply
    [[ "$reply" =~ ^[oOyY]$ ]]
}

remove_path() {
    local path="$1"
    if [[ -e "$path" || -L "$path" ]]; then
        rm -rf "$path"
        info "Supprime : $path"
    fi
}

# --- 1. Stopper tout process de bootstrap en arriere-plan encore actif -------
info "=== Etape 1/6 : arret d'un eventuel bootstrap en arriere-plan ==="
BG_PIDS="$(pgrep -f "$STATE_DIR/run.sh" 2>/dev/null || true)"
BG_PIDS="$BG_PIDS $(pgrep -f "nvim --headless.*Lazy" 2>/dev/null || true)"
BG_PIDS="$(echo "$BG_PIDS" | tr ' ' '\n' | grep -E '^[0-9]+$' | sort -u || true)"
if [[ -n "$BG_PIDS" ]]; then
    warn "Process en arriere-plan trouves : $BG_PIDS"
    if confirm "Les arreter avant de continuer ?"; then
        for pid in $BG_PIDS; do
            kill "$pid" 2>/dev/null && info "Process $pid arrete."
        done
        sleep 1
    else
        warn "Poursuite sans arreter ces process (risque de conflit)."
    fi
else
    info "Aucun bootstrap en arriere-plan detecte."
fi

# --- 2. Config / donnees / cache Neovim (+ anciennes sauvegardes .bak.*) -----
info "=== Etape 2/6 : configuration et donnees Neovim ==="
NVIM_DIRS=(
    "$NVIM_CONFIG"
    "$LOCAL_SHARE/nvim"
    "$HOME/.local/state/nvim"
    "$HOME/.cache/nvim"
)
for d in "${NVIM_DIRS[@]}"; do
    if [[ -e "$d" ]]; then
        if confirm "Supprimer $d ?"; then
            remove_path "$d"
        fi
    fi
done

BAKS="$(find "$HOME/.config" "$LOCAL_SHARE" "$HOME/.local/state" "$HOME/.cache" -maxdepth 1 -name "nvim.bak.*" 2>/dev/null || true)"
if [[ -n "$BAKS" ]]; then
    echo "$BAKS"
    if confirm "Supprimer aussi ces anciennes sauvegardes (nvim.bak.*) ci-dessus ?"; then
        while IFS= read -r b; do
            remove_path "$b"
        done <<< "$BAKS"
    fi
fi

# --- 3. Binaires installes par le script (~/.local/bin et ~/.local/lib) -----
info "=== Etape 3/6 : binaires (nvim, rg, fd, lazygit, fzf, node) ==="
BIN_FILES=(nvim rg fd lazygit fzf node npm npx)
LIB_DIRS=(nvim node)

for f in "${BIN_FILES[@]}"; do
    [[ -e "$LOCAL_BIN/$f" || -L "$LOCAL_BIN/$f" ]] && echo "  $LOCAL_BIN/$f"
done
for d in "${LIB_DIRS[@]}"; do
    [[ -e "$LOCAL_LIB/$d" ]] && echo "  $LOCAL_LIB/$d"
done

if confirm "Supprimer tous les binaires ci-dessus (nvim/rg/fd/lazygit/fzf/node/npm/npx) ?"; then
    for f in "${BIN_FILES[@]}"; do
        remove_path "$LOCAL_BIN/$f"
    done
    for d in "${LIB_DIRS[@]}"; do
        remove_path "$LOCAL_LIB/$d"
    done
fi

# --- 4. Police Nerd Font ------------------------------------------------------
info "=== Etape 4/6 : police JetBrainsMono Nerd Font ==="
FONT_DIR="$LOCAL_SHARE/fonts/JetBrainsMonoNerdFont"
if [[ -e "$FONT_DIR" ]]; then
    if confirm "Supprimer la police installee dans $FONT_DIR ?"; then
        remove_path "$FONT_DIR"
        command -v fc-cache &>/dev/null && fc-cache -f "$LOCAL_SHARE/fonts" &>/dev/null
    fi
fi

# --- 5. Etat du bootstrap et logs --------------------------------------------
info "=== Etape 5/6 : fichiers d'etat et logs du bootstrap ==="
if [[ -e "$STATE_DIR" || -e "$LOG_FILE" ]]; then
    if confirm "Supprimer $STATE_DIR et $LOG_FILE ?"; then
        remove_path "$STATE_DIR"
        remove_path "$LOG_FILE"
    fi
fi

# --- 6. Alias "nv" et ligne PATH dans .zshrc ---------------------------------
info "=== Etape 6/6 : alias 'nv' dans ~/.zshrc ==="
if grep -q 'alias nv=' "$HOME/.zshrc" 2>/dev/null; then
    if confirm "Retirer la ligne 'alias nv=\"nvim\"' de ~/.zshrc ?"; then
        sed -i.bak-cleanup '/alias nv="nvim"/d' "$HOME/.zshrc"
        info "Alias retire (sauvegarde : ~/.zshrc.bak-cleanup)."
    fi
fi
warn "La ligne PATH ('export PATH=\"\$HOME/.local/bin:\$PATH\"') est laissee intacte,"
warn "car d'autres outils que tu utilises peuvent en dependre. Supprime-la a la main"
warn "dans ~/.zshrc si tu es sur que ~/.local/bin ne sert a rien d'autre."

echo
info "Nettoyage termine. Tu peux relancer install_lazyvim.sh depuis zero."
