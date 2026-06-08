#!/bin/sh

# =============================================================================
# setup_inception.sh — Génère la structure du projet Inception (42)
# Usage : sh setup_inception.sh <login>
#   <login> = ton login 42, ex: sh setup_inception.sh wil
# =============================================================================

# --- Vérification de l'argument ---
if [ -z "$1" ]; then
    echo "Erreur : tu dois fournir ton login 42."
    echo "Usage : sh setup_inception.sh <login>"
    exit 1
fi

LOGIN=$1
ROOT="inception"

echo "=== Création de la structure Inception pour le login : $LOGIN ==="

# =============================================================================
# RACINE DU PROJET
# =============================================================================
mkdir -p $ROOT
touch $ROOT/Makefile
touch $ROOT/README.md
touch $ROOT/USER_DOC.md
touch $ROOT/DEV_DOC.md
touch $ROOT/.gitignore

# .gitignore — fichiers sensibles à ne jamais commiter
cat > $ROOT/.gitignore << EOF
secrets/
srcs/.env
*.txt
EOF

# =============================================================================
# DOSSIER secrets/
# Les mots de passe sont stockés ici — jamais dans les Dockerfiles
# =============================================================================
mkdir -p $ROOT/secrets
touch $ROOT/secrets/credentials.txt
touch $ROOT/secrets/db_password.txt
touch $ROOT/secrets/db_root_password.txt

# Permissions restreintes sur les secrets (lecture seul pour le propriétaire)
chmod 600 $ROOT/secrets/credentials.txt
chmod 600 $ROOT/secrets/db_password.txt
chmod 600 $ROOT/secrets/db_root_password.txt

# =============================================================================
# DOSSIER srcs/
# =============================================================================
mkdir -p $ROOT/srcs
touch $ROOT/srcs/docker-compose.yml
touch $ROOT/srcs/.env

# =============================================================================
# srcs/requirements/ — un sous-dossier par service
# =============================================================================

# --- NGINX ---
mkdir -p $ROOT/srcs/requirements/nginx/conf
mkdir -p $ROOT/srcs/requirements/nginx/tools
touch $ROOT/srcs/requirements/nginx/Dockerfile
touch $ROOT/srcs/requirements/nginx/.dockerignore
touch $ROOT/srcs/requirements/nginx/conf/nginx.conf
touch $ROOT/srcs/requirements/nginx/tools/generate-cert.sh

# --- WORDPRESS ---
mkdir -p $ROOT/srcs/requirements/wordpress/conf
mkdir -p $ROOT/srcs/requirements/wordpress/tools
touch $ROOT/srcs/requirements/wordpress/Dockerfile
touch $ROOT/srcs/requirements/wordpress/.dockerignore
touch $ROOT/srcs/requirements/wordpress/conf/www.conf
touch $ROOT/srcs/requirements/wordpress/tools/wp-setup.sh

# --- MARIADB ---
mkdir -p $ROOT/srcs/requirements/mariadb/conf
mkdir -p $ROOT/srcs/requirements/mariadb/tools
touch $ROOT/srcs/requirements/mariadb/Dockerfile
touch $ROOT/srcs/requirements/mariadb/.dockerignore
touch $ROOT/srcs/requirements/mariadb/conf/my.cnf
touch $ROOT/srcs/requirements/mariadb/tools/init-db.sh

# --- TOOLS (scripts utilitaires partagés) ---
mkdir -p $ROOT/srcs/requirements/tools

# --- BONUS ---
mkdir -p $ROOT/srcs/requirements/bonus/redis/conf
mkdir -p $ROOT/srcs/requirements/bonus/redis/tools
touch $ROOT/srcs/requirements/bonus/redis/Dockerfile
touch $ROOT/srcs/requirements/bonus/redis/.dockerignore
touch $ROOT/srcs/requirements/bonus/redis/conf/redis.conf

mkdir -p $ROOT/srcs/requirements/bonus/ftp/conf
mkdir -p $ROOT/srcs/requirements/bonus/ftp/tools
touch $ROOT/srcs/requirements/bonus/ftp/Dockerfile
touch $ROOT/srcs/requirements/bonus/ftp/.dockerignore
touch $ROOT/srcs/requirements/bonus/ftp/conf/vsftpd.conf
touch $ROOT/srcs/requirements/bonus/ftp/tools/ftp-setup.sh

mkdir -p $ROOT/srcs/requirements/bonus/adminer/conf
mkdir -p $ROOT/srcs/requirements/bonus/adminer/tools
touch $ROOT/srcs/requirements/bonus/adminer/Dockerfile
touch $ROOT/srcs/requirements/bonus/adminer/.dockerignore

mkdir -p $ROOT/srcs/requirements/bonus/static/site
touch $ROOT/srcs/requirements/bonus/static/Dockerfile
touch $ROOT/srcs/requirements/bonus/static/.dockerignore
touch $ROOT/srcs/requirements/bonus/static/site/index.html

# =============================================================================
# DOSSIERS DE DONNÉES sur la machine hôte (volumes Docker)
# Le sujet impose : /home/login/data/
# =============================================================================
mkdir -p /home/$LOGIN/data/wordpress
mkdir -p /home/$LOGIN/data/mariadb

# =============================================================================
# Rendre les scripts shell exécutables
# =============================================================================
chmod +x $ROOT/srcs/requirements/nginx/tools/generate-cert.sh
chmod +x $ROOT/srcs/requirements/wordpress/tools/wp-setup.sh
chmod +x $ROOT/srcs/requirements/mariadb/tools/init-db.sh
chmod +x $ROOT/srcs/requirements/bonus/ftp/tools/ftp-setup.sh

# =============================================================================
# RÉSUMÉ
# =============================================================================
echo ""
echo "=== Structure créée avec succès ==="
echo ""
echo "Arborescence du projet :"
find $ROOT -not -path '*/\.*' | sort | sed 's|[^/]*/|  |g'
echo ""
echo "Dossiers de données Docker :"
echo "  /home/$LOGIN/data/wordpress"
echo "  /home/$LOGIN/data/mariadb"
echo ""
echo "=== Prochaine étape : remplir les fichiers un par un ==="
echo "  Commencer par : $ROOT/srcs/.env"
echo "  Puis          : $ROOT/secrets/db_password.txt"
echo "  Puis          : $ROOT/srcs/requirements/mariadb/Dockerfile"
EOF
