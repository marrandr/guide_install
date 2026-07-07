#!/bin/bash

# ==============================================================================
# SCRIPT DE POST-INSTALLATION ET CONFIGURATION POUR KUBUNTU 24.04
# ==============================================================================

# Sécurité : Vérifier si le script est exécuté en tant que root (sudo)
if [ "$EUID" -ne 0 ]; then
  echo "Erreur : Ce script doit être exécuté avec sudo."
  echo "Relance-le avec : sudo $0"
  exit 1
fi

# Récupérer l'utilisateur non-root qui a lancé sudo et son dossier Home
REAL_USER=${SUDO_USER:-$USER}
REAL_HOME=$(eval echo "~$REAL_USER")

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


# #ZSH-AND-OH-MY-ZSH
echo "=== CONFIGURATION DE ZSH ET OH-MY-ZSH POUR L'UTILISATEUR ==="
# 1. Installer Zsh
apt install -y zsh

# 2. Installer Oh My Zsh proprement dans le Home de l'utilisateur (sans bloquer le script)
if [ ! -d "$REAL_HOME/.oh-my-zsh" ]; then
  sudo -u "$REAL_USER" RUNZSH=no CHSH=no sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
fi

# 3. Installer l'extension de suggestions d'historique (zsh-autosuggestions)
AUTO_SUGGEST_DIR="$REAL_HOME/.oh-my-zsh/custom/plugins/zsh-autosuggestions"
if [ ! -d "$AUTO_SUGGEST_DIR" ]; then
  sudo -u "$REAL_USER" git clone https://github.com/zsh-users/zsh-autosuggestions "$AUTO_SUGGEST_DIR"
fi

# 4. Appliquer le thème Jovial
# Le thème Jovial demande simplement d'être téléchargé et sourcé ou mis dans les thèmes personnalisés.
JOVIAL_DIR="$REAL_HOME/.oh-my-zsh/custom/themes/jovial"
if [ ! -d "$JOVIAL_DIR" ]; then
  sudo -u "$REAL_USER" git clone https://github.com/caiogondim/jovial.zsh.git "$JOVIAL_DIR"
  # Créer le lien symbolique pour que Oh My Zsh le détecte comme un thème valide
  sudo -u "$REAL_USER" ln -sf "$JOVIAL_DIR/jovial.zsh-theme" "$REAL_HOME/.oh-my-zsh/custom/themes/jovial.zsh-theme"
fi

# 5. Configurer le fichier .zshrc de l'utilisateur
# On injecte le thème, le plugin de suggestion et la recherche intelligente dans l'historique
sudo -u "$REAL_USER" bash -c "cat << 'EOF' > $REAL_HOME/.zshrc
# Raccourci vers Oh My Zsh
export ZSH=\"\$HOME/.oh-my-zsh\"

# Thème Jovial
ZSH_THEME=\"jovial\"

# Plugins à charger (Ajout de zsh-autosuggestions)
plugins=(git zsh-autosuggestions)

source \$ZSH/oh-my-zsh.sh

# --- CONFIGURATION RECHERCHE HISTORIQUE INTELLIGENTE ---
# Flèche du haut : cherche les commandes qui COMMENCENT par ce qui est déjà écrit
autoload -U up-line-or-beginning-search
autoload -U down-line-or-beginning-search
zle -N up-line-or-beginning-search
zle -N down-line-or-beginning-search
bindkey '^[[A' up-line-or-beginning-search # Touche flèche du haut
bindkey '^[[B' down-line-or-beginning-search # Touche flèche du bas
EOF"

# 6. Changer le shell par défaut de l'utilisateur vers Zsh
chsh -s $(which zsh) "$REAL_USER"


# #CLEANUP
echo "=== NETTOYAGE DES FICHIERS TEMPORAIRES ==="
rm -f /tmp/packages.microsoft.gpg
rm -f /tmp/google-chrome-stable_current_amd64.deb
rm -f /tmp/get-docker.sh
apt autoremove -y

echo "=============================================================================="
echo " Tout est installé et configuré avec succès !"
echo " IMPORTANT : Redémarre la machine virtuelle pour appliquer Zsh par défaut"
echo " et valider les permissions Docker sans sudo."
echo "=============================================================================="