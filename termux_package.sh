pkg update -y && pkg upgrade -y

# Core packages
pkg install -y zsh python git eza

# Plugins
mkdir -p ~/.zsh

git clone https://github.com/zsh-users/zsh-autosuggestions.git \
~/.zsh/zsh-autosuggestions

git clone https://github.com/zsh-users/zsh-syntax-highlighting.git \
~/.zsh/zsh-syntax-highlighting

# Create .zshrc
cat > ~/.zshrc <<'EOF'
# Colors
autoload -Uz colors && colors

# Prompt
PROMPT='%F{green}%n%f@%F{cyan}%m%f:%F{yellow}%~%f %# '

# History
HISTSIZE=5000
SAVEHIST=5000
setopt HIST_IGNORE_ALL_DUPS
setopt INC_APPEND_HISTORY
setopt SHARE_HISTORY

# Better ls
alias ls='eza'
alias ll='eza -la'
alias lt='eza --tree -L 2'

# Plugins
source ~/.zsh/zsh-autosuggestions/zsh-autosuggestions.zsh
source ~/.zsh/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

# Useful aliases
alias py='python'
alias gs='git status'
alias ga='git add'
alias gc='git commit'
alias gp='git push'
EOF

# Set zsh as default shell
chsh -s $(which zsh)

echo
echo "Done."
echo "Restart Termux or run: zsh"
