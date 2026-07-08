#!/bin/bash

# ==============================================================================
# SCRIPT 3 : INSTALLATION DES LOGICIELS DE TRAVAIL & ENVIRONNEMENT
# Installe : Dev-Utile, Vim, Chrome, VS Code, Docker.
# ==============================================================================

# Sécurité : Vérifier si le script est exécuté en tant que root (sudo)
if [ "$EUID" -ne 0 ]; then
  echo "Erreur : Ce script doit être exécuté avec sudo."
  echo "Relance-le avec : sudo $0"
  exit 1
fi

# Récupérer l'utilisateur non-root qui a lancé sudo
REAL_USER=${SUDO_USER:-$USER}

echo "=== MISE À JOUR DES DÉPÔTS ==="
apt update && apt upgrade -y


# #DEV-UTILE
echo "=== INSTALLATION DES PACKS DEV-UTILE ==="
apt install -y build-essential git curl wget gpg checkinstall


# #VIM
echo "=== INSTALLATION DE VIM ==="
apt install -y vim


# #CHROME
echo "=== INSTALLATION DE GOOGLE CHROME ==="
wget https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb -O /tmp/google-chrome-stable_current_amd64.deb
dpkg -i /tmp/google-chrome-stable_current_amd64.deb
apt install -f -y


# #VS-CODE
echo "=== INSTALLATION DE VISUAL STUDIO CODE ==="
wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > /tmp/packages.microsoft.gpg
install -o root -g root -m 644 /tmp/packages.microsoft.gpg /etc/apt/trusted.gpg.d/
echo "deb [arch=amd64,arm64,armhf signed-by=/etc/apt/trusted.gpg.d/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" | tee /etc/apt/sources.list.d/vscode.list
apt update
apt install -y code


# #DOCKER
echo "=== INSTALLATION DE DOCKER ==="
curl -fsSL https://get.docker.com -o /tmp/get-docker.sh
sh /tmp/get-docker.sh
usermod -aG docker "$REAL_USER"


# #CLEANUP
echo "=== NETTOYAGE DES FICHIERS TEMPORAIRES ==="
rm -f /tmp/packages.microsoft.gpg
rm -f /tmp/google-chrome-stable_current_amd64.deb
rm -f /tmp/get-docker.sh
apt autoremove -y

echo "=============================================================================="
echo " [SUCCÈS] Tous les logiciels de travail ont été installés !"
echo " IMPORTANT : Redémarre la VM pour pouvoir utiliser Docker sans 'sudo'."
echo "=============================================================================="