#!/usr/bin/env bash

set -Eeuo pipefail

echo -e "\n🔧 Setting up Linux Mint KDE terminal with ParrotOS + Powerlevel10k aesthetics..."

# ==============================
# Basic settings
# ==============================

SCRIPT_NAME="mint-parrot-terminal-setup"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP_DIR="$HOME/.config/${SCRIPT_NAME}/backups/$TIMESTAMP"
TMP_DIR="$(mktemp -d "/tmp/${SCRIPT_NAME}.XXXXXX")"

ZSH_DIR="$HOME/.oh-my-zsh"
ZSH_CUSTOM_DIR="${ZSH_CUSTOM:-$ZSH_DIR/custom}"
THEME_DIR="$ZSH_CUSTOM_DIR/themes/powerlevel10k"

SYNTAX_PLUGIN_DIR="$ZSH_CUSTOM_DIR/plugins/zsh-syntax-highlighting"
AUTOSUGGEST_PLUGIN_DIR="$ZSH_CUSTOM_DIR/plugins/zsh-autosuggestions"

FONT_DIR="$HOME/.local/share/fonts/MesloLGS-NF"

RETRY_COUNT=5
RETRY_DELAY=5

# ==============================
# Cleanup / failure handling
# ==============================

cleanup() {
    rm -rf "$TMP_DIR"

    # Remove stale temp dirs from interrupted previous runs.
    find /tmp -maxdepth 1 -type d -name "${SCRIPT_NAME}.*" -mtime +1 -exec rm -rf {} + 2>/dev/null || true

    # Clean apt cache safely.
    if command -v apt-get >/dev/null 2>&1; then
        sudo apt-get autoremove -y >/dev/null 2>&1 || true
        sudo apt-get autoclean -y >/dev/null 2>&1 || true
    fi
}

on_error() {
    echo -e "\n❌ Setup stopped because something failed."
    echo "   Your existing config backups, if created, are here:"
    echo "   $BACKUP_DIR"
    echo "   Temporary install files were cleaned."
    echo "   Re-run this script when your internet connection is stable."
}

trap cleanup EXIT
trap on_error ERR

mkdir -p "$BACKUP_DIR"

# ==============================
# Helper functions
# ==============================

log() {
    echo -e "\n➜ $*"
}

warn() {
    echo -e "\n⚠️  $*"
}

retry() {
    local attempt=1

    until "$@"; do
        if [ "$attempt" -ge "$RETRY_COUNT" ]; then
            echo "Command failed after $RETRY_COUNT attempts:"
            printf ' %q' "$@"
            echo
            return 1
        fi

        warn "Command failed. Retrying in ${RETRY_DELAY}s... attempt $((attempt + 1))/$RETRY_COUNT"
        sleep "$RETRY_DELAY"
        attempt=$((attempt + 1))
    done
}

backup_file() {
    local file="$1"

    if [ -f "$file" ] || [ -d "$file" ]; then
        mkdir -p "$BACKUP_DIR"
        cp -a "$file" "$BACKUP_DIR/"
        echo "Backed up: $file"
    fi
}

safe_git_clone_or_update() {
    local repo_url="$1"
    local target_dir="$2"
    local label="$3"

    mkdir -p "$(dirname "$target_dir")"

    if [ -d "$target_dir/.git" ]; then
        log "Updating $label..."
        retry git -C "$target_dir" pull --ff-only
        return
    fi

    if [ -e "$target_dir" ]; then
        warn "$label directory exists but is not a valid git repo. Backing it up."
        mv "$target_dir" "$BACKUP_DIR/$(basename "$target_dir").backup-$TIMESTAMP"
    fi

    log "Installing $label..."
    local temp_clone="$TMP_DIR/$(basename "$target_dir")"

    retry git clone --depth=1 "$repo_url" "$temp_clone"
    mv "$temp_clone" "$target_dir"
}

download_file() {
    local url="$1"
    local output="$2"

    retry curl -fL \
        --connect-timeout 15 \
        --retry 3 \
        --retry-delay 3 \
        --retry-all-errors \
        "$url" \
        -o "$output"
}

install_fetch_tool() {
    log "Trying to install Fastfetch first..."

    if apt-cache show fastfetch >/dev/null 2>&1; then
        if retry sudo DEBIAN_FRONTEND=noninteractive apt-get install -y fastfetch; then
            echo "Fastfetch installed."
            FETCH_TOOL="fastfetch"
            return 0
        fi

        warn "Fastfetch package exists, but installation failed."
    else
        warn "Fastfetch not available in current apt repositories."
    fi

    log "Falling back to Neofetch..."

    if retry sudo DEBIAN_FRONTEND=noninteractive apt-get install -y neofetch; then
        echo "Neofetch installed."
        FETCH_TOOL="neofetch"
        return 0
    fi

    warn "Neither Fastfetch nor Neofetch could be installed. Continuing without fetch display."
    FETCH_TOOL="none"
    return 0
}

install_meslo_fonts() {
    log "Checking MesloLGS NF fonts..."

    mkdir -p "$FONT_DIR"

    local base_url="https://github.com/romkatv/powerlevel10k-media/raw/master"
    local fonts=(
        "MesloLGS NF Regular.ttf"
        "MesloLGS NF Bold.ttf"
        "MesloLGS NF Italic.ttf"
        "MesloLGS NF Bold Italic.ttf"
    )

    local font
    local encoded_font

    for font in "${fonts[@]}"; do
        if [ -f "$FONT_DIR/$font" ]; then
            echo "Already installed: $font"
            continue
        fi

        encoded_font="${font// /%20}"
        echo "Downloading: $font"
        download_file "$base_url/$encoded_font" "$TMP_DIR/$font"
        mv "$TMP_DIR/$font" "$FONT_DIR/$font"
    done

    fc-cache -f "$HOME/.local/share/fonts" >/dev/null 2>&1 || true

    echo "MesloLGS NF installed."
    echo "In KDE Konsole, set font to: MesloLGS NF"
}

write_zshrc() {
    log "Writing ~/.zshrc..."

    backup_file "$HOME/.zshrc"

    cat > "$HOME/.zshrc" << 'EOF'
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="powerlevel10k/powerlevel10k"

plugins=(
  git
  zsh-autosuggestions
  zsh-syntax-highlighting
)

source "$ZSH/oh-my-zsh.sh"

# Fancy Parrot-style startup banner.
# Comment this block if you want faster terminal startup.
if command -v toilet >/dev/null 2>&1 && command -v lolcat >/dev/null 2>&1; then
  clear
  toilet -f pagga "ParrotOS" | lolcat
fi

if command -v fastfetch >/dev/null 2>&1; then
	fastfetch
elif command -v neofetch >/dev/null 2>&1; then
	neofetch
fi

# Powerlevel10k config
[[ -f "$HOME/.p10k.zsh" ]] && source "$HOME/.p10k.zsh"
EOF
}

write_p10k_config() {
    log "Writing ~/.p10k.zsh..."

    backup_file "$HOME/.p10k.zsh"

    cat > "$HOME/.p10k.zsh" << 'EOF'
# Minimal Parrot-style Powerlevel10k config.
# For full interactive customization, run: p10k configure

POWERLEVEL9K_LEFT_PROMPT_ELEMENTS=(os_icon dir vcs)
POWERLEVEL9K_RIGHT_PROMPT_ELEMENTS=(status command_execution_time time)

POWERLEVEL9K_PROMPT_ADD_NEWLINE=true

POWERLEVEL9K_MULTILINE_FIRST_PROMPT_PREFIX="╭─"
POWERLEVEL9K_MULTILINE_LAST_PROMPT_PREFIX="╰→ "

POWERLEVEL9K_LEFT_SEGMENT_SEPARATOR=""
POWERLEVEL9K_RIGHT_SEGMENT_SEPARATOR=" | "

POWERLEVEL9K_OS_ICON_FOREGROUND=cyan
POWERLEVEL9K_DIR_FOREGROUND=green
POWERLEVEL9K_VCS_CLEAN_FOREGROUND=green
POWERLEVEL9K_VCS_MODIFIED_FOREGROUND=yellow
POWERLEVEL9K_STATUS_OK_FOREGROUND=green
POWERLEVEL9K_STATUS_ERROR_FOREGROUND=red
POWERLEVEL9K_TIME_FOREGROUND=cyan

POWERLEVEL9K_COMMAND_EXECUTION_TIME_THRESHOLD=3
EOF
}

write_neofetch_config() {
    log "Writing Neofetch config..."

    mkdir -p "$HOME/.config/neofetch"
    backup_file "$HOME/.config/neofetch/config.conf"

    cat > "$HOME/.config/neofetch/config.conf" << 'EOF'
print_info() {
    info title
    info underline
    info "OS" distro
    info "Host" model
    info "Kernel" kernel
    info "Uptime" uptime
    info "Shell" shell
    info "Packages" packages
    info "DE" de
    info "WM" wm
    info "Terminal" term
}

image_backend="ascii"
ascii_distro="parrot"
EOF
}

remove_duplicate_leftovers() {
    log "Cleaning unnecessary duplicate/setup leftovers..."

    # Remove common failed clone leftovers created by interrupted git operations.
    find "$ZSH_CUSTOM_DIR" \
        -type d \
        \( -name "*.tmp" -o -name "*.lock" -o -name ".setup-tmp-*" \) \
        -exec rm -rf {} + 2>/dev/null || true

    # Remove empty duplicate backup dirs from this script if any were created accidentally.
    find "$HOME/.config/${SCRIPT_NAME}/backups" \
        -type d \
        -empty \
        -delete 2>/dev/null || true

    # Do NOT delete actual backups. They are intentionally kept for rollback.
    echo "Cleanup complete."
}

# ==============================
# Preflight
# ==============================

if ! command -v sudo >/dev/null 2>&1; then
    echo "sudo is required but was not found."
    exit 1
fi

if ! command -v apt-get >/dev/null 2>&1; then
    echo "This script expects a Debian/Ubuntu/Mint system with apt-get."
    exit 1
fi

# ==============================
# Step 1: Install packages
# ==============================

log "Updating package lists..."
retry sudo apt-get update

log "Installing required packages..."
retry sudo DEBIAN_FRONTEND=noninteractive apt-get install -y \
    zsh \
    git \
    curl \
    ca-certificates \
    fontconfig \
    figlet \
    toilet \
    lolcat \
    fonts-powerline

install_fetch_tool

# ==============================
# Step 2: Install MesloLGS NF font
# ==============================

install_meslo_fonts

# ==============================
# Step 3: Install Oh My Zsh
# ==============================

if [ ! -d "$ZSH_DIR" ]; then
    log "Installing Oh My Zsh..."

    download_file \
        "https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh" \
        "$TMP_DIR/oh-my-zsh-install.sh"

    chmod +x "$TMP_DIR/oh-my-zsh-install.sh"

    # Unattended avoids launching zsh or changing shell during install.
    RUNZSH=no CHSH=no sh "$TMP_DIR/oh-my-zsh-install.sh" --unattended
else
    log "Oh My Zsh already installed."
fi

# ==============================
# Step 4: Install / update Powerlevel10k and plugins
# ==============================

safe_git_clone_or_update \
    "https://github.com/romkatv/powerlevel10k.git" \
    "$THEME_DIR" \
    "Powerlevel10k"

safe_git_clone_or_update \
    "https://github.com/zsh-users/zsh-autosuggestions.git" \
    "$AUTOSUGGEST_PLUGIN_DIR" \
    "zsh-autosuggestions"

safe_git_clone_or_update \
    "https://github.com/zsh-users/zsh-syntax-highlighting.git" \
    "$SYNTAX_PLUGIN_DIR" \
    "zsh-syntax-highlighting"

# ==============================
# Step 5: Write configs
# ==============================

write_neofetch_config
write_zshrc
write_p10k_config

# ==============================
# Step 6: Change default shell
# ==============================

ZSH_PATH="$(command -v zsh)"

if [ "${SHELL:-}" != "$ZSH_PATH" ]; then
    log "Changing default shell to Zsh..."
    chsh -s "$ZSH_PATH"
else
    log "Default shell is already Zsh."
fi

# ==============================
# Step 7: Cleanup
# ==============================

remove_duplicate_leftovers

echo -e "\n✅ Setup complete!"
echo -e "👉 Log out and back in, or run: \033[1;32mzsh\033[0m"
echo -e "🎨 KDE Konsole font: set it to \033[1;36mMesloLGS NF\033[0m for best icons."
echo -e "🧙 To customize your prompt later, run: \033[1;36mp10k configure\033[0m"
echo -e "🗂️ Backups saved at: $BACKUP_DIR\n"
