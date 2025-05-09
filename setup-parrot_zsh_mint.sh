#!/bin/bash

echo -e "\n🔧 Setting up your Linux Mint terminal with Parrot OS + Powerlevel10k aesthetics..."

# Step 1: Update and install required packages
sudo apt update && sudo apt upgrade -y
sudo apt install -y zsh git curl neofetch figlet toilet lolcat fonts-powerline

# Step 2: Change shell to Zsh
if ! grep -q "/zsh" <<< "$SHELL"; then
    echo "Changing default shell to zsh..."
    chsh -s $(which zsh)
fi

# Step 3: Install Oh My Zsh
if [ ! -d "$HOME/.oh-my-zsh" ]; then
    echo "Installing Oh My Zsh..."
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
fi

# Step 4: Install Powerlevel10k theme
if [ ! -d "$HOME/.oh-my-zsh/custom/themes/powerlevel10k" ]; then
    echo "Installing Powerlevel10k theme..."
    git clone --depth=1 https://github.com/romkatv/powerlevel10k.git \
        "$HOME/.oh-my-zsh/custom/themes/powerlevel10k"
fi

# Step 5: Install useful plugins
git clone https://github.com/zsh-users/zsh-syntax-highlighting.git \
    ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting

git clone https://github.com/zsh-users/zsh-autosuggestions.git \
    ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-autosuggestions

# Step 6: Configure Neofetch to show Parrot ASCII
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

# Step 7: Create .zshrc
cat > ~/.zshrc << 'EOF'
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="powerlevel10k/powerlevel10k"

plugins=(
  git
  zsh-syntax-highlighting
  zsh-autosuggestions
)

source $ZSH/oh-my-zsh.sh

# Fancy Parrot ASCII banner
clear
toilet -f pagga "ParrotOS" | lolcat
neofetch

# Powerlevel10k config
[[ -f ~/.p10k.zsh ]] && source ~/.p10k.zsh
EOF

# Step 8: Generate basic Powerlevel10k config
cat > ~/.p10k.zsh << 'EOF'
POWERLEVEL9K_LEFT_PROMPT_ELEMENTS=(os_icon dir vcs)
POWERLEVEL9K_RIGHT_PROMPT_ELEMENTS=(status command_execution_time time)
POWERLEVEL9K_PROMPT_ADD_NEWLINE=true
POWERLEVEL9K_MULTILINE_FIRST_PROMPT_PREFIX="╭─"
POWERLEVEL9K_MULTILINE_LAST_PROMPT_PREFIX="╰→ "
POWERLEVEL9K_RIGHT_SEGMENT_SEPARATOR=" | "
EOF

# Done!
echo -e "\n✅ Setup complete!"
echo -e "👉 Please log out and back in or run \033[1;32mzsh\033[0m to start using your new Parrot-style terminal."
echo -e "🧙‍♂️ To customize your prompt, run \033[1;36mp10k configure\033[0m\n"
