#!/bin/bash

# ==============================================================================
# SCRIPT D'AUTOMATISATION DE POST-INSTALLATION POUR KUBUNTU 24.04
# Installe : Vim, Chrome (.deb officiel via dpkg), VS Code, Docker & outils dev.
# ==============================================================================

# Sécurité : Vérifier si le script est exécuté en tant que root (sudo)
if [ "$EUID" -ne 0 ]; then
  echo "Erreur : Ce script doit être exécuté avec sudo."
  echo "Relance-le avec : sudo $0"
  exit 1
fi

# Récupérer le vrai nom de l'utilisateur non-root qui a lancé sudo
REAL_USER=${SUDO_USER:-$USER}

echo "=== 1. Mise à jour initiale des dépôts ==="
apt update && apt upgrade -y

echo "=== 2. Installation de Vim et des outils de dev essentiels ==="
apt install -y vim build-essential git curl wget gpg checkinstall

echo "=== 3. Installation de Google Chrome via paquet .deb officiel ==="
# 1. Téléchargement du fichier .deb officiel depuis les serveurs de Google
wget https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb -O /tmp/google-chrome-stable_current_amd64.deb

# 2. Installation du fichier avec dpkg -i comme demandé
dpkg -i /tmp/google-chrome-stable_current_amd64.deb

# 3. Sécurité : Corriger les dépendances si jamais il en manque
apt install -f -y

echo "=== 4. Installation de Visual Studio Code ==="
wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > /tmp/packages.microsoft.gpg
install -o root -g root -m 644 /tmp/packages.microsoft.gpg /etc/apt/trusted.gpg.d/

echo "deb [arch=amd64,arm64,armhf signed-by=/etc/apt/trusted.gpg.d/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" | tee /etc/apt/sources.list.d/vscode.list

apt update
apt install -y code

echo "=== 5. Installation de Docker ==="
curl -fsSL https://get.docker.com -o /tmp/get-docker.sh
sh /tmp/get-docker.sh

# Configuration du groupe Docker pour ton utilisateur
echo "Configuration de Docker pour l'utilisateur : $REAL_USER"
usermod -aG docker "$REAL_USER"

echo "=== 6. Nettoyage des fichiers temporaires ==="
rm -f /tmp/packages.microsoft.gpg
rm -f /tmp/google-chrome-stable_current_amd64.deb
rm -f /tmp/get-docker.sh
apt autoremove -y

echo "=============================================================================="
echo " Tout est installé avec succès !"
echo " IMPORTANT : Pour que l'accès à Docker sans 'sudo' soit effectif,"
echo " tu dois redémarrer ta machine ou fermer/rouvrir ta session."
echo "=============================================================================="