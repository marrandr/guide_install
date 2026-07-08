#!/bin/bash

# ==============================================================================
# SCRIPT 1 : CONFIGURATION UNIQUEMENT POUR ZSH & OH MY ZSH (THEME SPACESHIP)
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

# #ZSH-AND-OH-MY-ZSH
echo "=== CONFIGURATION DE ZSH ET OH-MY-ZSH POUR L'UTILISATEUR ==="

# 1. Installer Zsh, Git et Curl
apt update && apt install -y zsh git curl

# 2. Installer Oh My Zsh proprement dans le Home de l'utilisateur
if [ ! -d "$REAL_HOME/.oh-my-zsh" ]; then
  sudo -u "$REAL_USER" RUNZSH=no CHSH=no sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
fi

# 3. Installer l'extension de suggestions d'historique (zsh-autosuggestions)
AUTO_SUGGEST_DIR="$REAL_HOME/.oh-my-zsh/custom/plugins/zsh-autosuggestions"
if [ ! -d "$AUTO_SUGGEST_DIR" ]; then
  sudo -u "$REAL_USER" git clone https://github.com/zsh-users/zsh-autosuggestions "$AUTO_SUGGEST_DIR"
fi

# 4. Appliquer le thème moderne Spaceship
SPACESHIP_DIR="$REAL_HOME/.oh-my-zsh/custom/themes/spaceship-prompt"
if [ ! -d "$SPACESHIP_DIR" ]; then
  sudo -u "$REAL_USER" git clone https://github.com/spaceship-prompt/spaceship-prompt.git "$SPACESHIP_DIR" --depth=1
  sudo -u "$REAL_USER" ln -sf "$SPACESHIP_DIR/spaceship.zsh-theme" "$REAL_HOME/.oh-my-zsh/custom/themes/spaceship.zsh-theme"
fi

# 5. Configurer le fichier .zshrc de l'utilisateur
sudo -u "$REAL_USER" bash -c "cat << 'EOF' > $REAL_HOME/.zshrc
# Raccourci vers Oh My Zsh
export ZSH=\"\$HOME/.oh-my-zsh\"

# Thème moderne Spaceship
ZSH_THEME=\"spaceship\"

# Plugins à charger
plugins=(git zsh-autosuggestions)

source \$ZSH/oh-my-zsh.sh

# --- CONFIGURATION RECHERCHE HISTORIQUE INTELLIGENTE ---
autoload -U up-line-or-beginning-search
autoload -U down-line-or-beginning-search
zle -N up-line-or-beginning-search
zle -N down-line-or-beginning-search
bindkey '^[[A' up-line-or-beginning-search # Touche flèche du haut
bindkey '^[[B' down-line-or-beginning-search # Touche flèche du bas
EOF"

# 6. Changer le shell par défaut de l'utilisateur vers Zsh
chsh -s $(which zsh) "$REAL_USER"

echo "=============================================================================="
echo " [SUCCÈS] Configuration de Zsh avec Spaceship terminée !"
echo " Ouvre un nouveau terminal ou redémarre pour appliquer."
echo "=============================================================================="