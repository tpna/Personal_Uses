#!/data/data/com.termux/files/usr/bin/bash

echo -e "\n🔧 Setting up your Termux with Parrot OS + Powerlevel10k aesthetics..."

# Step 1: Update and install essentials
pkg update -y && pkg upgrade -y
pkg install -y zsh git curl neofetch figlet toilet lolcat wget

# Step 2: Change shell to Zsh
chsh -s zsh

# Step 3: Install Oh My Zsh
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"

# Step 4: Install plugins
git clone https://github.com/zsh-users/zsh-syntax-highlighting.git $HOME/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting
git clone https://github.com/zsh-users/zsh-autosuggestions $HOME/.oh-my-zsh/custom/plugins/zsh-autosuggestions

# Step 5: Install Powerlevel10k
git clone --depth=1 https://github.com/romkatv/powerlevel10k.git $HOME/.oh-my-zsh/custom/themes/powerlevel10k

# Step 6: Configure Neofetch
mkdir -p ~/.config/neofetch
cat > ~/.config/neofetch/config.conf << 'EOF'
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

# Step 7: Create .zshrc with Powerlevel10k and Parrot flair
cat > $HOME/.zshrc << 'EOF'
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="powerlevel10k/powerlevel10k"

plugins=(
  git
  zsh-syntax-highlighting
  zsh-autosuggestions
)

source $ZSH/oh-my-zsh.sh

# Fancy Parrot banner
clear
toilet -f pagga "ParrotOS" | lolcat
neofetch

# History and shell options
setopt HIST_IGNORE_ALL_DUPS
setopt INC_APPEND_HISTORY
setopt SHARE_HISTORY

# Source Powerlevel10k config if exists
[[ -f ~/.p10k.zsh ]] && source ~/.p10k.zsh
EOF

# Step 8: Create default Powerlevel10k config if missing
cat > ~/.p10k.zsh << 'EOF'
# Basic P10k config - you can customize later via `p10k configure`
POWERLEVEL9K_LEFT_PROMPT_ELEMENTS=(os_icon dir vcs)
POWERLEVEL9K_RIGHT_PROMPT_ELEMENTS=(status command_execution_time time)
POWERLEVEL9K_PROMPT_ADD_NEWLINE=true
POWERLEVEL9K_MULTILINE_FIRST_PROMPT_PREFIX="╭─"
POWERLEVEL9K_MULTILINE_LAST_PROMPT_PREFIX="╰→ "
POWERLEVEL9K_RIGHT_SEGMENT_SEPARATOR=" | "
EOF

# Final message
echo -e "\n✅ Done! You now have a Parrot OS–style Termux with Powerlevel10k."
echo -e "👉 Restart Termux or type \033[1;32mzsh\033[0m to launch it."
echo -e "📝 You can run \033[1;36mp10k configure\033[0m to personalize your prompt.\n"
