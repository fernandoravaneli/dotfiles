#!/bin/bash

set -e

# Cores para mensagens
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Diretório base dos dotfiles (assumimos que é onde este script está localizado)
DOTFILES_DIR="$(cd "$(dirname "$0")" && pwd)"

# Lista de pacotes essenciais
PACKAGES=(zsh git curl stow gpg)

echo -e "${YELLOW}Atualizando pacotes e instalando dependências...${NC}"
sudo apt update && sudo apt install -y "${PACKAGES[@]}"

#LAZYGIT INSTALATION
LAZYGIT_VERSION=$(curl -s "https://api.github.com/repos/jesseduffield/lazygit/releases/latest" | \grep -Po '"tag_name": *"v\K[^"]*')
curl -Lo lazygit.tar.gz "https://github.com/jesseduffield/lazygit/releases/download/v${LAZYGIT_VERSION}/lazygit_${LAZYGIT_VERSION}_Linux_x86_64.tar.gz"
tar xf lazygit.tar.gz lazygit
sudo install lazygit -D -t /usr/local/bin/
rm -rf lazygit

# Instalar o eza (substituto do ls)
sudo mkdir -p /etc/apt/keyrings
wget -qO- https://raw.githubusercontent.com/eza-community/eza/main/deb.asc | sudo gpg --dearmor -o /etc/apt/keyrings/gierens.gpg
echo "deb [signed-by=/etc/apt/keyrings/gierens.gpg] http://deb.gierens.de stable main" | sudo tee /etc/apt/sources.list.d/gierens.list
sudo chmod 644 /etc/apt/keyrings/gierens.gpg /etc/apt/sources.list.d/gierens.list
sudo apt update
sudo apt install -y eza

# Instalar Oh My Zsh sem executar o shell e sem sobrescrever o .zshrc
if [ ! -d "$HOME/.oh-my-zsh" ]; then
  echo -e "${YELLOW}Instalando oh-my-zsh...${NC}"
  export RUNZSH=no
  export KEEP_ZSHRC=yes
  sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
else
  echo -e "${GREEN}Oh-my-zsh já está instalado.${NC}"
fi

# Instalar plugins adicionais
git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting
git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions

#nvm
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash

#Sparship
curl -sS https://starship.rs/install.sh | sh

# Aplicando dotfiles com stow
cd "$DOTFILES_DIR"
echo -e "${YELLOW}Aplicando dotfiles com stow...${NC}"
stow zsh
stow git
#stow tmux

# Trocar shell padrão para zsh
if [ "$SHELL" != "$(which zsh)" ]; then
  echo -e "${YELLOW}Trocando shell padrão para zsh...${NC}"
  chsh -s $(which zsh)
fi

#------------
mkdir ~/Projects
mkdir ~/Projects/Work
mkdir ~/Projects/Personal
# mkdir ~/Projects/Forks # for GitHub fork
# mkdir ~/Projects/Job # for job projects
# mkdir ~/Projects/Playground # for short-term experiments
# mkdir ~/Projects/Repos # for long-term projects
#------------
echo -e "\n${GREEN}Instalação concluída! Reinicie o terminal ou digite 'zsh'.${NC}"

