#!/usr/bin/env bash

# ==============================================================================
# INSTALLATION DE ZSH + OH MY ZSH + ALANPEABODY
# Compatible Arch Linux / EndeavourOS
# ==============================================================================

set -euo pipefail

# ------------------------------------------------------------------------------
# Vérification
# ------------------------------------------------------------------------------

if [[ $EUID -ne 0 ]]; then
    echo "Ce script doit être exécuté avec sudo."
    echo "Utilisation : sudo $0"
    exit 1
fi

REAL_USER="${SUDO_USER:-$USER}"
REAL_HOME=$(eval echo "~$REAL_USER")

# ------------------------------------------------------------------------------
# Couleurs
# ------------------------------------------------------------------------------

GREEN="\033[1;32m"
BLUE="\033[1;34m"
YELLOW="\033[1;33m"
RED="\033[1;31m"
RESET="\033[0m"

info()    { echo -e "${BLUE}[INFO]${RESET} $1"; }
success() { echo -e "${GREEN}[OK]${RESET} $1"; }
warning() { echo -e "${YELLOW}[WARN]${RESET} $1"; }
error()   { echo -e "${RED}[ERREUR]${RESET} $1"; }

# ------------------------------------------------------------------------------
# Mise à jour
# ------------------------------------------------------------------------------

info "Mise à jour du système..."

pacman -Syu --noconfirm

# ------------------------------------------------------------------------------
# Dépendances
# ------------------------------------------------------------------------------

info "Installation des dépendances..."

pacman -S --needed --noconfirm \
    zsh \
    git \
    curl \
    fzf

# ------------------------------------------------------------------------------
# Installation Oh My Zsh
# ------------------------------------------------------------------------------

if [[ ! -d "$REAL_HOME/.oh-my-zsh" ]]; then

    info "Installation de Oh My Zsh..."

    sudo -u "$REAL_USER" \
        RUNZSH=no \
        CHSH=no \
        KEEP_ZSHRC=yes \
        sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"

else

    warning "Oh My Zsh est déjà installé."

fi

# ------------------------------------------------------------------------------
# Plugins
# ------------------------------------------------------------------------------

install_plugin() {

    local NAME=$1
    local URL=$2
    local DEST="$REAL_HOME/.oh-my-zsh/custom/plugins/$NAME"

    if [[ ! -d "$DEST" ]]; then

        info "Installation de $NAME..."

        sudo -u "$REAL_USER" git clone "$URL" "$DEST"

    else

        success "$NAME déjà installé."

    fi

}

install_plugin \
    zsh-autosuggestions \
    https://github.com/zsh-users/zsh-autosuggestions

install_plugin \
    zsh-syntax-highlighting \
    https://github.com/zsh-users/zsh-syntax-highlighting.git

install_plugin \
    zsh-completions \
    https://github.com/zsh-users/zsh-completions.git

# ------------------------------------------------------------------------------
# Configuration .zshrc
# ------------------------------------------------------------------------------

info "Configuration de .zshrc..."

cat > "$REAL_HOME/.zshrc" <<'EOF'
export ZSH="$HOME/.oh-my-zsh"

ZSH_THEME="alanpeabody"

plugins=(
    git
    fzf
    zsh-autosuggestions
    zsh-syntax-highlighting
    zsh-completions
)

source $ZSH/oh-my-zsh.sh

# --------------------------------------------------------------------
# Historique
# --------------------------------------------------------------------

HISTFILE=$HOME/.zsh_history
HISTSIZE=100000
SAVEHIST=100000

setopt APPEND_HISTORY
setopt SHARE_HISTORY
setopt HIST_IGNORE_ALL_DUPS
setopt HIST_IGNORE_SPACE
setopt HIST_FIND_NO_DUPS
setopt HIST_REDUCE_BLANKS
setopt INC_APPEND_HISTORY
setopt EXTENDED_HISTORY

# --------------------------------------------------------------------
# Recherche intelligente ↑ ↓
# --------------------------------------------------------------------

autoload -U up-line-or-beginning-search
autoload -U down-line-or-beginning-search

zle -N up-line-or-beginning-search
zle -N down-line-or-beginning-search

bindkey '^[[A' up-line-or-beginning-search
bindkey '^[[B' down-line-or-beginning-search

# --------------------------------------------------------------------
# Completion
# --------------------------------------------------------------------

autoload -Uz compinit
compinit

# --------------------------------------------------------------------
# fzf
# --------------------------------------------------------------------

if command -v fzf >/dev/null; then
    source <(fzf --zsh)
fi

# --------------------------------------------------------------------
# Aliases utiles
# --------------------------------------------------------------------

alias ll='ls -lah'
alias la='ls -A'
alias l='ls -CF'
alias gs='git status'
alias gc='git commit'
alias gp='git push'
alias gl='git pull'
alias cls='clear'

EOF

chown "$REAL_USER:$REAL_USER" "$REAL_HOME/.zshrc"

# ------------------------------------------------------------------------------
# Shell par défaut
# ------------------------------------------------------------------------------

if [[ "$(getent passwd "$REAL_USER" | cut -d: -f7)" != "$(which zsh)" ]]; then

    info "Définition de Zsh comme shell par défaut..."

    chsh -s "$(which zsh)" "$REAL_USER"

fi

# ------------------------------------------------------------------------------
# Fin
# ------------------------------------------------------------------------------

echo
echo "======================================================"
success "Installation terminée."
echo
echo "Configuration installée :"
echo
echo "  ✓ Oh My Zsh"
echo "  ✓ Thème alanpeabody"
echo "  ✓ zsh-autosuggestions"
echo "  ✓ zsh-syntax-highlighting"
echo "  ✓ zsh-completions"
echo "  ✓ fzf"
echo "  ✓ Historique intelligent"
echo "  ✓ Completion avancée"
echo "  ✓ Aliases Git"
echo
echo "Déconnecte-toi puis reconnecte-toi"
echo "ou ouvre un nouveau terminal."
echo "======================================================"