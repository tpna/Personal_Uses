# Storage access (will prompt for permission)
# termux-setup-storage

#!/data/data/com.termux/files/usr/bin/bash

set -Eeuo pipefail

echo -e "\n🔧 Setting up lightweight Termux Zsh environment..."

# ==============================
# Basic settings
# ==============================

SCRIPT_NAME="termux-light-zsh-setup"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP_DIR="$HOME/.config/${SCRIPT_NAME}/backups/$TIMESTAMP"
TMP_DIR="$(mktemp -d "$PREFIX/tmp/${SCRIPT_NAME}.XXXXXX")"

ZSH_PLUGIN_DIR="$HOME/.zsh"
AUTOSUGGEST_DIR="$ZSH_PLUGIN_DIR/zsh-autosuggestions"
SYNTAX_DIR="$ZSH_PLUGIN_DIR/zsh-syntax-highlighting"

RETRY_COUNT=5
RETRY_DELAY=5

# ==============================
# Cleanup / error handling
# ==============================

cleanup() {
    rm -rf "$TMP_DIR"

    find "$PREFIX/tmp" \
        -maxdepth 1 \
        -type d \
        -name "${SCRIPT_NAME}.*" \
        -mtime +1 \
        -exec rm -rf {} + 2>/dev/null || true

    pkg autoclean -y >/dev/null 2>&1 || true
}

on_error() {
    echo -e "\n❌ Setup stopped because something failed."
    echo "   Backups, if created, are here:"
    echo "   $BACKUP_DIR"
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

install_fetch_tool() {
    log "Trying to install Fastfetch first..."

    if pkg search fastfetch 2>/dev/null | grep -q '^fastfetch/'; then
        if retry pkg install -y fastfetch; then
            echo "Fastfetch installed."
            return
        fi

        warn "Fastfetch exists but failed to install."
    else
        warn "Fastfetch not available in current Termux repositories."
    fi

    log "Falling back to Neofetch..."

    if pkg search neofetch 2>/dev/null | grep -q '^neofetch/'; then
        retry pkg install -y neofetch
        echo "Neofetch installed."
        return
    fi

    warn "Neither Fastfetch nor Neofetch is available. Continuing without fetch display."
}

write_zshrc() {
    log "Writing ~/.zshrc..."

    backup_file "$HOME/.zshrc"

    cat > "$HOME/.zshrc" <<'EOF'
autoload -Uz colors && colors

# Lightweight colorful prompt
PROMPT='%F{green}%n%f@%F{cyan}%m%f:%F{yellow}%~%f %# '

# History
HISTSIZE=5000
SAVEHIST=5000
HISTFILE="$HOME/.zsh_history"

setopt HIST_IGNORE_ALL_DUPS
setopt INC_APPEND_HISTORY
setopt SHARE_HISTORY
setopt AUTO_CD
setopt CORRECT

# Quality-of-life aliases
alias ls='eza'
alias ll='eza -la'
alias lt='eza --tree -L 2'
alias cat='bat'
alias py='python'
alias gs='git status'
alias ga='git add'
alias gc='git commit'
alias gp='git push'
alias cls='clear'

# Fetch display
if command -v fastfetch >/dev/null 2>&1; then
  fastfetch
elif command -v neofetch >/dev/null 2>&1; then
  neofetch
fi

# Zsh plugins
if [ -f "$HOME/.zsh/zsh-autosuggestions/zsh-autosuggestions.zsh" ]; then
  source "$HOME/.zsh/zsh-autosuggestions/zsh-autosuggestions.zsh"
fi

if [ -f "$HOME/.zsh/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" ]; then
  source "$HOME/.zsh/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
fi
EOF
}

remove_duplicate_leftovers() {
    log "Cleaning unnecessary duplicate/setup leftovers..."

    find "$ZSH_PLUGIN_DIR" \
        -type d \
        \( -name "*.tmp" -o -name "*.lock" -o -name ".setup-tmp-*" \) \
        -exec rm -rf {} + 2>/dev/null || true

    find "$HOME/.config/${SCRIPT_NAME}/backups" \
        -type d \
        -empty \
        -delete 2>/dev/null || true

    echo "Cleanup complete."
}

# ==============================
# Preflight
# ==============================

if [ -z "${PREFIX:-}" ] || [ ! -d "$PREFIX" ]; then
    echo "This script must be run inside Termux."
    exit 1
fi

# ==============================
# Step 1: Storage access
# ==============================

log "Requesting storage access..."
termux-setup-storage || warn "Storage permission skipped or denied. Continuing anyway."

# ==============================
# Step 2: Update packages
# ==============================

log "Updating package lists..."
retry pkg update -y

# Optional, but lighter than forcing full upgrade every time.
log "Installing core packages..."
retry pkg install -y \
    zsh \
    python \
    git \
    eza \
    curl \
    wget \
    tmux \
    fdupes \
    bat

# ==============================
# Step 3: Fastfetch first, Neofetch fallback
# ==============================

install_fetch_tool

# ==============================
# Step 4: Install / update Zsh plugins
# ==============================

safe_git_clone_or_update \
    "https://github.com/zsh-users/zsh-autosuggestions.git" \
    "$AUTOSUGGEST_DIR" \
    "zsh-autosuggestions"

safe_git_clone_or_update \
    "https://github.com/zsh-users/zsh-syntax-highlighting.git" \
    "$SYNTAX_DIR" \
    "zsh-syntax-highlighting"

# ==============================
# Step 5: Write Zsh config
# ==============================

write_zshrc

# ==============================
# Step 6: Make Zsh default
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

echo -e "\n✅ Done."
echo -e "👉 Restart Termux, or run: \033[1;32mzsh\033[0m"
echo -e "🗂️ Backups saved at: $BACKUP_DIR\n"
