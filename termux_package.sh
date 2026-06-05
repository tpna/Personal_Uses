#!/data/data/com.termux/files/usr/bin/bash
set -e

echo "Setting up..."

# Storage access (will prompt for permission)
termux-setup-storage

# Update packages
pkg update -y
pkg upgrade -y
pkg install x11-repo -y

# Core packages
pkg install -y zsh python git eza curl wget tmux fdupes neofetch fastfetch bat
alias cat='bat'

# Plugins
mkdir -p ~/.zsh

git clone https://github.com/zsh-users/zsh-autosuggestions.git \
~/.zsh/zsh-autosuggestions

git clone https://github.com/zsh-users/zsh-syntax-highlighting.git \
~/.zsh/zsh-syntax-highlighting

# Zsh config
cat > ~/.zshrc <<'EOF'
autoload -Uz colors && colors

PROMPT='%F{green}%n%f@%F{cyan}%m%f:%F{yellow}%~%f %# '

HISTSIZE=5000
SAVEHIST=5000
setopt HIST_IGNORE_ALL_DUPS
setopt INC_APPEND_HISTORY
setopt SHARE_HISTORY

alias ls='eza'
alias ll='eza -la'
alias lt='eza --tree -L 2'

source ~/.zsh/zsh-autosuggestions/zsh-autosuggestions.zsh
source ~/.zsh/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

alias py='python'
alias gs='git status'
alias ga='git add'
alias gc='git commit'
alias gp='git push'
EOF

# Make zsh default
chsh -s "$(which zsh)"

echo
echo -e "\n✅ Done. Restart Termux or run: termux-reload-settings"
