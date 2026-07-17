#!/usr/bin/env bash
#
# install_lazyvim.sh
# ---------------------------------------------------------------------------
# Installation complete et sans droits root de :
#   - Neovim (derniere version stable, binaire officiel)
#   - ripgrep, fd, lazygit, fzf, Node.js (dependances de LazyVim)
#   - LazyVim (starter officiel) avec theme Tokyonight
#   - Support NestJS / Next.js : TypeScript, Tailwind, ESLint, Prettier,
#     JSON, YAML, Docker, Prisma
#   - Alias "nv" pour lancer nvim
#
# Tous les binaires vont dans ~/.local (lib/bin), tout est verifie via les
# sources officielles (API GitHub releases, nodejs.org) : pas de scripts
# tiers non verifies.
#
# Une fois les prerequis installes, l'etape la plus longue (telechargement
# de tous les plugins + serveurs LSP/formatters/linters) tourne en ARRIERE
# PLAN (nohup) pour que tu puisses continuer a utiliser ton terminal. Un
# fichier de log te permet de suivre la progression, et une notification
# desktop (si disponible) t'avertit a la fin.
#
# Usage :
#   chmod +x install_lazyvim.sh
#   ./install_lazyvim.sh
# ---------------------------------------------------------------------------

set -uo pipefail

# --- Chemins -----------------------------------------------------------------
LOCAL_BIN="$HOME/.local/bin"
LOCAL_LIB="$HOME/.local/lib"
LOCAL_SHARE="$HOME/.local/share"
STATE_DIR="$HOME/.local/state/lazyvim_bootstrap"
LOG_FILE="$HOME/.local/state/lazyvim_install.log"
NVIM_CONFIG="$HOME/.config/nvim"

mkdir -p "$LOCAL_BIN" "$LOCAL_LIB" "$LOCAL_SHARE/fonts" "$STATE_DIR" "$HOME/.local/state"

# --- Couleurs / helpers --------------------------------------------------------
GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
info()  { echo -e "${GREEN}[INFO]${NC} $*"; }
warn()  { echo -e "${YELLOW}[ATTENTION]${NC} $*"; }
error() { echo -e "${RED}[ERREUR]${NC} $*" >&2; }

require_cmd() {
    if ! command -v "$1" &>/dev/null; then
        error "La commande '$1' est requise mais introuvable sur ce systeme."
        return 1
    fi
    return 0
}

# --- Verification des prerequis systeme (ne peuvent pas etre installes sans root) ---
MISSING=0
for cmd in curl tar git python3 unzip; do
    require_cmd "$cmd" || MISSING=1
done
if ! command -v cc &>/dev/null && ! command -v gcc &>/dev/null && ! command -v clang &>/dev/null; then
    error "Aucun compilateur C trouve (gcc/clang/cc). Necessaire pour compiler les parsers Treesitter."
    MISSING=1
fi
if ! command -v make &>/dev/null; then
    error "'make' est requis (pour compiler certains parsers Treesitter)."
    MISSING=1
fi
if [[ "$MISSING" -eq 1 ]]; then
    error "Prerequis manquants, installation annulee. Ce sont des outils systeme de base"
    error "qui devraient deja etre presents sur un poste 42 (gcc, make, git, python3...)."
    exit 1
fi

# --- Detection de l'architecture ------------------------------------------------
ARCH="$(uname -m)"
case "$ARCH" in
    x86_64)
        NVIM_ARCH="x86_64"; RG_ARCH="x86_64"; FD_ARCH="x86_64"; LG_ARCH="x86_64"; NODE_ARCH="x64"; FZF_ARCH="amd64" ;;
    aarch64|arm64)
        NVIM_ARCH="arm64"; RG_ARCH="aarch64"; FD_ARCH="aarch64"; LG_ARCH="arm64"; NODE_ARCH="arm64"; FZF_ARCH="arm64" ;;
    *)
        error "Architecture non supportee : $ARCH"
        exit 1 ;;
esac

# --- Helpers GitHub API (releases officielles) ---------------------------------
github_latest_tag() {
    curl -fsSL "https://api.github.com/repos/$1/releases/latest" | python3 -c '
import json, sys
print(json.load(sys.stdin).get("tag_name", ""))
'
}

github_asset_url() {
    local repo="$1" pattern="$2"
    curl -fsSL "https://api.github.com/repos/$repo/releases/latest" | python3 -c '
import json, sys, re
data = json.load(sys.stdin)
pattern = re.compile(sys.argv[1])
for asset in data.get("assets", []):
    if pattern.search(asset["name"]):
        print(asset["browser_download_url"])
        sys.exit(0)
sys.exit(1)
' "$pattern"
}

# --- Installation de Neovim (binaire officiel neovim/neovim) -------------------
install_neovim() {
    info "Verification de Neovim..."
    local latest_tag current_version
    latest_tag="$(github_latest_tag neovim/neovim)"
    if [[ -z "$latest_tag" ]]; then
        error "Impossible de recuperer la derniere version de Neovim."
        return 1
    fi

    current_version=""
    if [[ -x "$LOCAL_BIN/nvim" ]]; then
        current_version="$("$LOCAL_BIN/nvim" --version 2>/dev/null | head -1 | awk '{print $2}')"
    fi

    if [[ "$current_version" == "$latest_tag" ]]; then
        info "Neovim deja a jour ($current_version)."
        return 0
    fi

    info "Installation de Neovim $latest_tag..."
    local url tmp
    url="https://github.com/neovim/neovim/releases/download/${latest_tag}/nvim-linux-${NVIM_ARCH}.tar.gz"
    tmp="$(mktemp -d)"
    curl -fL --progress-bar -o "$tmp/nvim.tar.gz" "$url"
    tar -xzf "$tmp/nvim.tar.gz" -C "$tmp"
    rm -rf "$LOCAL_LIB/nvim"
    mv "$tmp/nvim-linux-${NVIM_ARCH}" "$LOCAL_LIB/nvim"
    ln -sf "$LOCAL_LIB/nvim/bin/nvim" "$LOCAL_BIN/nvim"
    rm -rf "$tmp"
    info "Neovim $latest_tag installe."
}

# --- Installation de ripgrep (binaire statique musl, officiel) -----------------
install_ripgrep() {
    info "Verification de ripgrep..."
    if [[ -x "$LOCAL_BIN/rg" ]] && "$LOCAL_BIN/rg" --version &>/dev/null; then
        info "ripgrep deja installe : $("$LOCAL_BIN/rg" --version | head -1)"
        return 0
    fi
    info "Installation de ripgrep..."
    local url tmp bin
    url="$(github_asset_url BurntSushi/ripgrep "${RG_ARCH}-unknown-linux-musl\.tar\.gz$")"
    if [[ -z "$url" ]]; then
        error "Impossible de trouver l'archive ripgrep pour $RG_ARCH."
        return 1
    fi
    tmp="$(mktemp -d)"
    curl -fL --progress-bar -o "$tmp/rg.tar.gz" "$url"
    tar -xzf "$tmp/rg.tar.gz" -C "$tmp"
    bin="$(find "$tmp" -type f -name rg | head -1)"
    if [[ -z "$bin" ]]; then
        error "Binaire rg introuvable dans l'archive."
        rm -rf "$tmp"; return 1
    fi
    cp "$bin" "$LOCAL_BIN/rg"
    chmod +x "$LOCAL_BIN/rg"
    rm -rf "$tmp"
    info "ripgrep installe."
}

# --- Installation de fd (binaire statique musl, officiel) ----------------------
install_fd() {
    info "Verification de fd..."
    if [[ -x "$LOCAL_BIN/fd" ]] && "$LOCAL_BIN/fd" --version &>/dev/null; then
        info "fd deja installe : $("$LOCAL_BIN/fd" --version)"
        return 0
    fi
    info "Installation de fd..."
    local url tmp bin
    url="$(github_asset_url sharkdp/fd "${FD_ARCH}-unknown-linux-musl\.tar\.gz$")"
    if [[ -z "$url" ]]; then
        error "Impossible de trouver l'archive fd pour $FD_ARCH."
        return 1
    fi
    tmp="$(mktemp -d)"
    curl -fL --progress-bar -o "$tmp/fd.tar.gz" "$url"
    tar -xzf "$tmp/fd.tar.gz" -C "$tmp"
    bin="$(find "$tmp" -type f -name fd | head -1)"
    if [[ -z "$bin" ]]; then
        error "Binaire fd introuvable dans l'archive."
        rm -rf "$tmp"; return 1
    fi
    cp "$bin" "$LOCAL_BIN/fd"
    chmod +x "$LOCAL_BIN/fd"
    rm -rf "$tmp"
    info "fd installe."
}

# --- Installation de lazygit (binaire officiel) --------------------------------
install_lazygit() {
    info "Verification de lazygit..."
    if [[ -x "$LOCAL_BIN/lazygit" ]] && "$LOCAL_BIN/lazygit" --version &>/dev/null; then
        info "lazygit deja installe."
        return 0
    fi
    info "Installation de lazygit..."
    local url tmp bin
    url="$(github_asset_url jesseduffield/lazygit "[Ll]inux_${LG_ARCH}\.tar\.gz$")"
    if [[ -z "$url" ]]; then
        error "Impossible de trouver l'archive lazygit pour $LG_ARCH."
        return 1
    fi
    tmp="$(mktemp -d)"
    curl -fL --progress-bar -o "$tmp/lazygit.tar.gz" "$url"
    tar -xzf "$tmp/lazygit.tar.gz" -C "$tmp"
    bin="$(find "$tmp" -type f -name lazygit | head -1)"
    if [[ -z "$bin" ]]; then
        error "Binaire lazygit introuvable dans l'archive."
        rm -rf "$tmp"; return 1
    fi
    cp "$bin" "$LOCAL_BIN/lazygit"
    chmod +x "$LOCAL_BIN/lazygit"
    rm -rf "$tmp"
    info "lazygit installe."
}

# --- Installation de fzf (binaire officiel, requis par le picker Fzf-lua/snacks) ---
install_fzf() {
    info "Verification de fzf..."
    if [[ -x "$LOCAL_BIN/fzf" ]] && "$LOCAL_BIN/fzf" --version &>/dev/null; then
        info "fzf deja installe : $("$LOCAL_BIN/fzf" --version)"
        return 0
    fi
    info "Installation de fzf..."
    local url tmp bin
    url="$(github_asset_url junegunn/fzf "linux_${FZF_ARCH}\.tar\.gz$")"
    if [[ -z "$url" ]]; then
        error "Impossible de trouver l'archive fzf pour $FZF_ARCH."
        return 1
    fi
    tmp="$(mktemp -d)"
    curl -fL --progress-bar -o "$tmp/fzf.tar.gz" "$url"
    tar -xzf "$tmp/fzf.tar.gz" -C "$tmp"
    bin="$(find "$tmp" -type f -name fzf | head -1)"
    if [[ -z "$bin" ]]; then
        error "Binaire fzf introuvable dans l'archive."
        rm -rf "$tmp"; return 1
    fi
    cp "$bin" "$LOCAL_BIN/fzf"
    chmod +x "$LOCAL_BIN/fzf"
    rm -rf "$tmp"
    info "fzf installe."
}

# --- Installation de Node.js LTS (binaire officiel nodejs.org) -----------------
install_node() {
    info "Verification de Node.js..."
    local version current
    version="$(curl -fsSL https://nodejs.org/dist/index.json | python3 -c '
import json, sys
data = json.load(sys.stdin)
for entry in data:
    if entry.get("lts"):
        print(entry["version"])
        break
')"
    if [[ -z "$version" ]]; then
        error "Impossible de determiner la version LTS de Node.js."
        return 1
    fi

    current=""
    if [[ -x "$LOCAL_BIN/node" ]]; then
        current="$("$LOCAL_BIN/node" --version 2>/dev/null)"
    fi
    if [[ "$current" == "$version" ]]; then
        info "Node.js deja a jour ($current)."
        return 0
    fi

    info "Installation de Node.js $version..."
    local url tmp
    url="https://nodejs.org/dist/${version}/node-${version}-linux-${NODE_ARCH}.tar.xz"
    tmp="$(mktemp -d)"
    curl -fL --progress-bar -o "$tmp/node.tar.xz" "$url"
    tar -xJf "$tmp/node.tar.xz" -C "$tmp"
    rm -rf "$LOCAL_LIB/node"
    mv "$tmp/node-${version}-linux-${NODE_ARCH}" "$LOCAL_LIB/node"
    ln -sf "$LOCAL_LIB/node/bin/node" "$LOCAL_BIN/node"
    ln -sf "$LOCAL_LIB/node/bin/npm" "$LOCAL_BIN/npm"
    ln -sf "$LOCAL_LIB/node/bin/npx" "$LOCAL_BIN/npx"
    rm -rf "$tmp"
    info "Node.js $version installe."
}

# --- Nerd Font (JetBrainsMono) pour les icones -- best effort, non bloquant ----
install_nerd_font() {
    info "Installation de la police JetBrainsMono Nerd Font (pour les icones)..."
    local url tmp
    url="$(github_asset_url ryanoasis/nerd-fonts '^JetBrainsMono\.zip$')"
    if [[ -z "$url" ]]; then
        warn "Impossible de trouver la police, etape ignoree (pas bloquant)."
        return 0
    fi
    tmp="$(mktemp -d)"
    if curl -fL --progress-bar -o "$tmp/font.zip" "$url"; then
        mkdir -p "$LOCAL_SHARE/fonts/JetBrainsMonoNerdFont"
        unzip -oq "$tmp/font.zip" -d "$LOCAL_SHARE/fonts/JetBrainsMonoNerdFont"
        command -v fc-cache &>/dev/null && fc-cache -f "$LOCAL_SHARE/fonts" &>/dev/null
        info "Police installee dans $LOCAL_SHARE/fonts/JetBrainsMonoNerdFont"
        warn "Pense a selectionner 'JetBrainsMono Nerd Font' dans les preferences de ton terminal."
    else
        warn "Echec du telechargement de la police, etape ignoree (pas bloquant)."
    fi
    rm -rf "$tmp"
}

# --- Backup de la config Neovim existante --------------------------------------
backup_existing_nvim() {
    local ts
    ts="$(date +%Y%m%d_%H%M%S)"
    for d in "$HOME/.config/nvim" "$HOME/.local/share/nvim" "$HOME/.local/state/nvim" "$HOME/.cache/nvim"; do
        if [[ -e "$d" ]]; then
            mv "$d" "${d}.bak.${ts}"
            info "Sauvegarde : $d -> ${d}.bak.${ts}"
        fi
    done
}

# --- Clone du starter LazyVim officiel ------------------------------------------
install_lazyvim_starter() {
    info "Clonage du starter LazyVim officiel..."
    git clone --depth=1 https://github.com/LazyVim/starter "$NVIM_CONFIG"
    rm -rf "$NVIM_CONFIG/.git"
}

# --- Fichiers de configuration : extras, theme, prisma -------------------------
write_lazyvim_config() {
    mkdir -p "$NVIM_CONFIG/lua/plugins"

    # Extras officiels LazyVim (active via lazyvim.json)
    cat > "$NVIM_CONFIG/lazyvim.json" <<'EOF'
{
  "extras": [
    "lang.json",
    "lang.markdown",
    "lang.tailwind",
    "lang.typescript",
    "lang.docker",
    "lang.yaml",
    "formatting.prettier",
    "linting.eslint"
  ]
}
EOF

    # Theme Tokyonight (methode officielle documentee par LazyVim)
    cat > "$NVIM_CONFIG/lua/plugins/colorscheme.lua" <<'EOF'
return {
  { "folke/tokyonight.nvim", lazy = false, priority = 1000 },
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "tokyonight",
    },
  },
}
EOF

    # Support Prisma (utilise par NestJS), pas d'extra officiel LazyVim pour ca
    cat > "$NVIM_CONFIG/lua/plugins/prisma.lua" <<'EOF'
-- Support pour les fichiers .prisma (schema NestJS/Prisma ORM)
vim.filetype.add({ extension = { prisma = "prisma" } })

return {
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        prismals = {},
      },
    },
  },
  {
    "mason-org/mason.nvim",
    opts = function(_, opts)
      opts.ensure_installed = opts.ensure_installed or {}
      vim.list_extend(opts.ensure_installed, { "prisma-language-server" })
    end,
  },
  {
    "nvim-treesitter/nvim-treesitter",
    opts = function(_, opts)
      opts.ensure_installed = opts.ensure_installed or {}
      vim.list_extend(opts.ensure_installed, { "prisma" })
    end,
  },
}
EOF

    info "Fichiers de config LazyVim ecrits dans $NVIM_CONFIG"
}

# --- Preparation du bootstrap headless (arriere-plan) ---------------------------
prepare_background_bootstrap() {
    cat > "$STATE_DIR/mason_install.lua" <<'LUAEOF'
-- Force le chargement du plugin mason.nvim avant de le requerir
pcall(function()
  require("lazy").load({ plugins = { "mason.nvim" } })
end)

local ok_mr, mr = pcall(require, "mason-registry")
if not ok_mr then
  vim.cmd("qa!")
  return
end

local pkgs = {
  "vtsls",
  "eslint-lsp",
  "prettier",
  "tailwindcss-language-server",
  "json-lsp",
  "yaml-language-server",
  "dockerfile-language-server",
  "prisma-language-server",
  "js-debug-adapter",
}

local function finish()
  vim.schedule(function()
    vim.cmd("qa!")
  end)
end

local ok_refresh = pcall(mr.refresh, function()
  local to_install = {}
  for _, name in ipairs(pkgs) do
    local ok, pkg = pcall(mr.get_package, name)
    if ok and not pkg:is_installed() then
      table.insert(to_install, pkg)
    end
  end

  if #to_install == 0 then
    finish()
    return
  end

  local remaining = #to_install
  for _, pkg in ipairs(to_install) do
    pkg:install():once("closed", function()
      remaining = remaining - 1
      if remaining == 0 then
        finish()
      end
    end)
  end
end)

if not ok_refresh then
  finish()
end
LUAEOF

    cat > "$STATE_DIR/run.sh" <<RUNEOF
#!/usr/bin/env bash
export PATH="$LOCAL_BIN:\$PATH"
LOGFILE="$LOG_FILE"
{
    echo "[\$(date '+%H:%M:%S')] Etape 1/3 : telechargement de tous les plugins (Lazy.nvim)..."
    timeout 1800 nvim --headless -c "lua require('lazy').sync({ wait = true }); vim.cmd('qa')"
    echo "[\$(date '+%H:%M:%S')] Etape 2/3 : installation des serveurs LSP / formatters / linters (Mason)..."
    timeout 900 nvim --headless -S "$STATE_DIR/mason_install.lua"
    echo "[\$(date '+%H:%M:%S')] Etape 3/3 : compilation des parsers Treesitter..."
    timeout 900 nvim --headless -c "TSUpdateSync" -c "qa"
    echo "[\$(date '+%H:%M:%S')] INSTALLATION_TERMINEE"
    if command -v notify-send &>/dev/null; then
        notify-send "LazyVim" "Installation terminee, tu peux lancer 'nv' !"
    fi
} >> "\$LOGFILE" 2>&1
RUNEOF
    chmod +x "$STATE_DIR/run.sh"
}

# --- Alias "nv" et PATH dans .zshrc ---------------------------------------------
configure_zshrc() {
    if [[ ":$PATH:" != *":$LOCAL_BIN:"* ]]; then
        if ! grep -q '.local/bin' "$HOME/.zshrc" 2>/dev/null; then
            echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.zshrc"
            warn "Ligne PATH ajoutee a ~/.zshrc."
        fi
    fi
    if ! grep -q 'alias nv=' "$HOME/.zshrc" 2>/dev/null; then
        echo 'alias nv="nvim"' >> "$HOME/.zshrc"
        info "Alias 'nv' ajoute a ~/.zshrc."
    else
        info "Alias 'nv' deja present dans ~/.zshrc."
    fi
    warn "Recharge ton shell avec : source ~/.zshrc"
}

# =============================================================================
# EXECUTION
# =============================================================================
info "=== Installation des outils requis ==="
install_neovim || exit 1
install_ripgrep || exit 1
install_fd || exit 1
install_lazygit || exit 1
install_fzf || exit 1
install_node || exit 1
install_nerd_font

info "=== Configuration de LazyVim ==="
backup_existing_nvim
install_lazyvim_starter
write_lazyvim_config
configure_zshrc
prepare_background_bootstrap

info "=== Lancement du telechargement des plugins en arriere-plan ==="
: > "$LOG_FILE"
export PATH="$LOCAL_BIN:$PATH"
nohup "$STATE_DIR/run.sh" >/dev/null 2>&1 &
disown
BG_PID=$!

echo
info "Les outils systeme sont installes et prets."
info "Le telechargement des plugins/LSP tourne maintenant en arriere-plan (PID $BG_PID)."
echo
echo "  Pour suivre la progression en direct :"
echo "      tail -f $LOG_FILE"
echo
echo "  Pour verifier si c'est termine :"
echo "      grep INSTALLATION_TERMINEE $LOG_FILE"
echo
warn "Ne lance pas 'nv' avant de voir INSTALLATION_TERMINEE dans le log,"
warn "sinon Neovim tentera de re-synchroniser les plugins en meme temps que le script."
echo
info "Une fois termine : source ~/.zshrc puis lance simplement : nv"
