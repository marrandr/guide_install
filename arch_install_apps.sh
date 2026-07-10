#!/usr/bin/env bash

# ==============================================================================
# SCRIPT : INSTALLATION DES OUTILS DE DÉVELOPPEMENT
# Compatible Arch Linux / EndeavourOS
# ==============================================================================

set -euo pipefail

# ------------------------------------------------------------------------------
# Vérification
# ------------------------------------------------------------------------------

if [[ $EUID -eq 0 && -z "${SUDO_USER:-}" ]]; then
    echo "Ne lance pas ce script avec le compte root."
    echo "Utilise : sudo $0"
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

info() {
    echo -e "${BLUE}[INFO]${RESET} $1"
}

success() {
    echo -e "${GREEN}[OK]${RESET} $1"
}

warning() {
    echo -e "${YELLOW}[WARN]${RESET} $1"
}

error() {
    echo -e "${RED}[ERREUR]${RESET} $1"
}

# ------------------------------------------------------------------------------
# Mise à jour
# ------------------------------------------------------------------------------

info "Synchronisation des dépôts..."

pacman -Syu --noconfirm

# ------------------------------------------------------------------------------
# Dépendances
# ------------------------------------------------------------------------------

info "Installation des outils de base..."

pacman -S --needed --noconfirm \
    base-devel \
    git \
    curl \
    wget \
    vim \
    docker \
    code \
    unzip \
    zip \
    tar \
    openssh \
    gnupg

# ------------------------------------------------------------------------------
# Docker
# ------------------------------------------------------------------------------

info "Activation de Docker..."

systemctl enable docker.service
systemctl start docker.service

usermod -aG docker "$REAL_USER"

# ------------------------------------------------------------------------------
# Installation de yay
# ------------------------------------------------------------------------------

if ! command -v yay >/dev/null 2>&1; then

    info "Installation de yay..."

    TEMP_DIR=$(mktemp -d)

    chown "$REAL_USER:$REAL_USER" "$TEMP_DIR"

    sudo -u "$REAL_USER" bash <<EOF
cd "$TEMP_DIR"

git clone https://aur.archlinux.org/yay.git

cd yay

makepkg -si --noconfirm
EOF

    rm -rf "$TEMP_DIR"

    success "yay installé."

else

    success "yay est déjà installé."

fi
# ------------------------------------------------------------------------------
# Installation de Google Chrome (AUR)
# ------------------------------------------------------------------------------

if ! pacman -Q google-chrome >/dev/null 2>&1; then

    info "Installation de Google Chrome..."

    sudo -u "$REAL_USER" yay -S --needed --noconfirm google-chrome

    success "Google Chrome installé."

else

    success "Google Chrome est déjà installé."

fi

# ------------------------------------------------------------------------------
# Vérification de Visual Studio Code
# ------------------------------------------------------------------------------

if pacman -Q code >/dev/null 2>&1; then

    success "Visual Studio Code est installé."

else

    warning "Visual Studio Code ne semble pas installé."

fi

# ------------------------------------------------------------------------------
# Vérification Docker
# ------------------------------------------------------------------------------

info "Vérification de Docker..."

if systemctl is-enabled docker >/dev/null 2>&1; then
    success "Le service Docker est activé."
else
    warning "Le service Docker n'est pas activé."
fi

if systemctl is-active docker >/dev/null 2>&1; then
    success "Le service Docker est démarré."
else
    warning "Le service Docker n'est pas démarré."
fi

# ------------------------------------------------------------------------------
# Nettoyage
# ------------------------------------------------------------------------------

info "Nettoyage..."

pacman -Sc --noconfirm || true

# Nettoyage du cache yay (facultatif)
if command -v yay >/dev/null 2>&1; then
    yes | yay -Sc >/dev/null 2>&1 || true
fi

# ------------------------------------------------------------------------------
# Résumé
# ------------------------------------------------------------------------------

echo
echo "=============================================================="
echo " Installation terminée"
echo "=============================================================="

echo
echo "Logiciels installés :"

echo "  ✓ base-devel"
echo "  ✓ Git"
echo "  ✓ Curl"
echo "  ✓ Wget"
echo "  ✓ Vim"
echo "  ✓ Visual Studio Code"
echo "  ✓ Google Chrome"
echo "  ✓ Docker"
echo "  ✓ yay"

echo
echo "IMPORTANT :"

echo "  • Déconnecte-toi puis reconnecte-toi"
echo "    (ou redémarre la machine)"
echo
echo "afin que ton utilisateur appartienne"
echo "au groupe docker."

echo
echo "Tu pourras ensuite utiliser :"

echo "    docker ps"

echo
echo "sans sudo."

echo
success "Fin du script."

