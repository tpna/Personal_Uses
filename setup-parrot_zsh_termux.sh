#!/data/data/com.termux/files/usr/bin/bash
set -e

echo -e "\n🔧 Setting up Termux with ParrotOS-style Zsh + Powerlevel10k..."

pkg update -y
pkg upgrade -y
pkg install -y zsh git curl neofetch figlet toilet lolcat wget

# Change shell safely
chsh -s "$(which zsh)"

# Backup existing configs
[ -f "$HOME/.zshrc" ] && cp "$HOME/.zshrc" "$HOME/.zshrc.backup.$(date +%s)"
[ -f "$HOME/.p10k.zsh" ] && cp "$HOME/.p10k.zsh" "$HOME/.p10k.zsh.backup.$(date +%s)"

# Install Oh My Zsh non-interactively
if [ ! -d "$HOME/.oh-my-zsh" ]; then
  RUNZSH=no CHSH=no KEEP_ZSHRC=yes sh -c \
  "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
fi

ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"

# Plugins
[ ! -d "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" ] && \
git clone https://github.com/zsh-users/zsh-syntax-highlighting.git "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting"

[ ! -d "$ZSH_CUSTOM/plugins/zsh-autosuggestions" ] && \
git clone https://github.com/zsh-users/zsh-autosuggestions "$ZSH_CUSTOM/plugins/zsh-autosuggestions"

# Powerlevel10k
[ ! -d "$ZSH_CUSTOM/themes/powerlevel10k" ] && \
git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$ZSH_CUSTOM/themes/powerlevel10k"

# Neofetch config
mkdir -p "$HOME/.config/neofetch"
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
}

image_backend="ascii"
ascii_distro="parrot"
EOF

# Zsh config
cat > "$HOME/.zshrc" << 'EOF'
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="powerlevel10k/powerlevel10k"

plugins=(
  git
  zsh-autosuggestions
  zsh-syntax-highlighting
)

source "$ZSH/oh-my-zsh.sh"

# Show banner once per session
if [[ -z "$PARROT_BANNER_SHOWN" ]]; then
  export PARROT_BANNER_SHOWN=1
  clear
  toilet -f pagga "ParrotOS" | lolcat
  neofetch
fi

setopt HIST_IGNORE_ALL_DUPS
setopt INC_APPEND_HISTORY
setopt SHARE_HISTORY

[[ -f "$HOME/.p10k.zsh" ]] && source "$HOME/.p10k.zsh"
EOF

cat > "$HOME/.p10k.zsh" << 'EOF'
POWERLEVEL9K_LEFT_PROMPT_ELEMENTS=(os_icon dir vcs)
POWERLEVEL9K_RIGHT_PROMPT_ELEMENTS=(status command_execution_time time)
POWERLEVEL9K_PROMPT_ADD_NEWLINE=true
POWERLEVEL9K_MULTILINE_FIRST_PROMPT_PREFIX="╭─"
POWERLEVEL9K_MULTILINE_LAST_PROMPT_PREFIX="╰→ "
POWERLEVEL9K_RIGHT_SEGMENT_SEPARATOR=" | "
EOF

echo -e "\n✅ Done. Restart Termux or run: zsh"
echo -e "📝 Later customize with: p10k configure\n"
