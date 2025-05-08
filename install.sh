#!/bin/bash

set -e

# Cores para mensagens
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Diretório base dos dotfiles (assumimos que é onde este script está localizado)
DOTFILES_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$DOTFILES_DIR"

CACHE_FILE="$DOTFILES_DIR/.install_cache"
TODAY=$(date +%Y-%m-%d)

# Ajuda
show_help() {
  echo -e "\n${YELLOW}Uso: ./install.sh [OPÇÕES]${NC}"
  echo -e "\nOpções disponíveis:"
  echo -e "  --all         Instala tudo (zsh, git, ssh, ambiente dev, etc.)"
  echo -e "  --zsh         Instala apenas o ZSH e configurações relacionadas"
  echo -e "  --git         Aplica apenas configurações do Git e SSH (juntos)"
  echo -e "  --ssh         Aplica apenas configurações de SSH"
  echo -e "  --dev         Instala ferramentas de desenvolvimento (eza, nvm, lazygit, starship)"
  echo -e "  --force       Remove links anteriores com stow antes de aplicar"
  echo -e "  --help, -h    Exibe esta mensagem de ajuda\n"
  exit 0
}

# Flags por linha de comando
INSTALL_ALL=false
INSTALL_ZSH=false
INSTALL_GIT=false
INSTALL_SSH=false
INSTALL_DEV=false
FORCE=false

# Verifica argumentos
while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --all) INSTALL_ALL=true ;;
    --zsh) INSTALL_ZSH=true ;;
    --git) INSTALL_GIT=true ; INSTALL_SSH=true ;;
    --ssh) INSTALL_SSH=true ;;
    --dev) INSTALL_DEV=true ;;
    --force) FORCE=true ;;
    --help|-h) show_help ;;
    *) echo -e "${RED}⚠️  Opção inválida: $1${NC}"; show_help ;;
  esac
  shift
done

# Menu interativo se nada for passado
if ! $INSTALL_ALL && ! $INSTALL_ZSH && ! $INSTALL_GIT && ! $INSTALL_SSH && ! $INSTALL_DEV; then
  echo -e "\n${YELLOW}🚀 Nenhuma opção foi fornecida. Selecione o que deseja instalar:${NC}\n"
  options=("Tudo" "ZSH" "Git + SSH" "Apenas SSH" "Ambiente Dev" "Sair")
  select opt in "${options[@]}"; do
    case $REPLY in
      1) INSTALL_ALL=true; break;;
      2) INSTALL_ZSH=true; break;;
      3) INSTALL_GIT=true; INSTALL_SSH=true; break;;
      4) INSTALL_SSH=true; break;;
      5) INSTALL_DEV=true; break;;
      6) exit 0;;
      *) echo "Opção inválida";;
    esac
  done
fi

#--------------------------------------------------------------
# Funções por módulo
#--------------------------------------------------------------
update_if_needed() {
  if [ -f "$CACHE_FILE" ] && grep -q "$TODAY" "$CACHE_FILE"; then
    return
  fi

  echo -e "${YELLOW}📦 Atualizando índices de pacotes (apt update)...${NC}"
  sudo apt update
  echo "$TODAY" > "$CACHE_FILE"
}

install_common_packages() {
  update_if_needed

  PACKAGES=(git curl stow)
  TO_INSTALL=()
  echo -e "\n"

  for pkg in "${PACKAGES[@]}"; do
    if dpkg -s "$pkg" &>/dev/null; then
      echo -e "${GREEN}✔️ $pkg já está instalado.${NC}"
    else
      TO_INSTALL+=("$pkg")
    fi
  done

  echo -e "\n"

  if [ "${#TO_INSTALL[@]}" -gt 0 ]; then
    echo -e "${YELLOW}📦 Instalando pacotes essenciais: ${TO_INSTALL[*]}...${NC}"
    sudo apt install -y "${TO_INSTALL[@]}"
  else
    echo -e "${GREEN}✔️ Todos os pacotes essenciais já estão instalados.${NC}"
  fi
}

install_zsh() {
  if command -v zsh >/dev/null 2>&1; then
    echo -e "\n${GREEN}✔️ ZSH já está instalado.${NC}"
    return
  fi

  update_if_needed

  echo -e "${YELLOW}📦 Instalando ZSH...${NC}"
  sudo apt install -y zsh
}

install_ohmyzsh() {
  if [ ! -d "$HOME/.oh-my-zsh" ]; then
    echo -e "${YELLOW}Instalando oh-my-zsh...${NC}"
    export RUNZSH=no
    export KEEP_ZSHRC=yes
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
  else
    echo -e "\n${GREEN}✔️ Oh-my-zsh já está instalado.${NC}"
  fi
}

install_zsh_plugins() {
  ZSH_CUSTOM=${ZSH_CUSTOM:-~/.oh-my-zsh/custom}
  if [ ! -d "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" ]; then
    echo -e "${YELLOW}Instalando plugin do ZSH... Syntax Highlighting${NC}"
    git clone https://github.com/zsh-users/zsh-syntax-highlighting.git "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting"
  fi
  if [ ! -d "$ZSH_CUSTOM/plugins/zsh-autosuggestions" ]; then
    echo -e "${YELLOW}Instalando plugin do ZSH... Autosuggestions${NC}"
    git clone https://github.com/zsh-users/zsh-autosuggestions "$ZSH_CUSTOM/plugins/zsh-autosuggestions"
  fi
}

install_lazy_git() {
  if [ -f /usr/local/bin/lazygit ]; then
    echo -e "\n${GREEN}✔️ LazyGit já está instalado.${NC}"
    return
  fi
  echo -e "\n${YELLOW}Instalando LazyGit...${NC}"
  LAZYGIT_VERSION=$(curl -s "https://api.github.com/repos/jesseduffield/lazygit/releases/latest" | grep -Po '"tag_name": *"v[^"]*"' | sed 's/"tag_name": *"v//;s/"//g')
  curl -Lo lazygit.tar.gz "https://github.com/jesseduffield/lazygit/releases/download/v${LAZYGIT_VERSION}/lazygit_${LAZYGIT_VERSION}_Linux_x86_64.tar.gz"
  tar xf lazygit.tar.gz lazygit
  sudo install lazygit -D -t /usr/local/bin/
  rm -rf lazygit lazygit.tar.gz
}

install_eza() {
  if command -v eza >/dev/null 2>&1; then
    echo -e "\n${GREEN}✔️ EZA já está instalado.${NC}"
    return
  fi
  echo -e "\n${YELLOW}🔧 Instalando EZA (substituto do ls)...${NC}"
  sudo mkdir -p /etc/apt/keyrings

  if [ ! -f /etc/apt/keyrings/gierens.gpg ]; then
    wget -qO- https://raw.githubusercontent.com/eza-community/eza/main/deb.asc \
      | sudo gpg --dearmor -o /etc/apt/keyrings/gierens.gpg
  fi
  echo "deb [signed-by=/etc/apt/keyrings/gierens.gpg] http://deb.gierens.de stable main" \
    | sudo tee /etc/apt/sources.list.d/gierens.list > /dev/null

  sudo chmod 644 /etc/apt/keyrings/gierens.gpg /etc/apt/sources.list.d/gierens.list
  update_if_needed

  sudo apt install -y eza
}

install_nvm() {
  if [ -d "$HOME/.nvm" ]; then
    echo -e "\n${GREEN}✔️ NVM já está instalado.${NC}"
    return
  fi
  echo -e "\n${YELLOW}🔧 Instalando NVM...${NC}"
  curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash
}

install_starship() {
  if command -v starship >/dev/null 2>&1; then
    echo -e "\n${GREEN}✔️ Starship já está instalado.${NC}"
    return
  fi

  echo -e "\n${YELLOW}🔧 Instalando Starship prompt...${NC}"
  curl -sS https://starship.rs/install.sh | sh -s -- -y
}

apply_dotfiles() {
  for module in "$@"; do
    echo -e "\n${YELLOW}🔗 Aplicando dotfiles para $module...${NC}"

    if [ "$module" = "ssh" ]; then
      mkdir -p "$HOME/.ssh"
      target="$HOME/.ssh/config"
      source="$DOTFILES_DIR/ssh/.ssh/config"
      bkp="$DOTFILES_DIR/ssh-config.backup"

      if [ -e "$target" ] && [ ! -L "$target" ]; then
        if $FORCE; then
          echo -e "${YELLOW}⚠️  Movendo $target para $bkp${NC}"
          mv "$target" "$bkp"
        else
          echo -e "${RED}❌ Conflito: $target já existe e não é um link simbólico.${NC}"
          echo -e "${YELLOW}ℹ️  Use '--force' para sobrescrever ou mova manualmente.${NC}"
        fi
      fi

      ln -sf "$source" "$target"
      echo -e "${GREEN}✔️ Link criado: $target → $source${NC}"
      continue  
    fi

    # Tratamento padrão
    for file in $(find "$DOTFILES_DIR/$module" -maxdepth 1 -mindepth 1 -printf "%f\n"); do
      target="$HOME/$file"
      bkp="$DOTFILES_DIR/$file.backup"
      if [ -e "$target" ] && [ ! -L "$target" ]; then
        if $FORCE; then
          echo -e "${YELLOW}⚠️  Movendo $target para $bkp${NC}"
          mv "$target" "$bkp"
        else
          echo -e "${RED}❌ Conflito: $target já existe e não é um link simbólico. Use --force para mover.${NC}"
          continue
        fi
      fi
    done

    if $FORCE; then
      stow -D "$module"
    fi
    stow "$module"
  done
}




finalize_setup() {
  mkdir -p ~/projects/{work,personal}
  if [[ "$INSTALL_ZSH" = true || "$INSTALL_ALL" = true ]] && [[ "$SHELL" != "$(which zsh)" ]]; then
    echo -e "\n${YELLOW}Trocando shell padrão para zsh...${NC}"
    echo -e "${YELLOW}⚠️  Você pode precisar reiniciar o terminal para aplicar as mudanças ou digite 'zsh'.${NC}"
    chsh -s $(which zsh)
  fi
}

#--------------------------------------------------------------
# Execução com base nas escolhas
#--------------------------------------------------------------

install_zsh_kit() {
  install_zsh
  install_ohmyzsh
  install_zsh_plugins
  apply_dotfiles zsh
}

install_git_kit() {
  apply_dotfiles git ssh
    echo -e "\n${YELLOW}🔎 Verificando se as chaves SSH estão presentes...${NC}"
    for key in "$HOME/.ssh/github-work" "$HOME/.ssh/github-personal"; do
      if [ ! -f "$key" ]; then
        echo -e "  ${RED}❌ Chave não encontrada: $key${NC}"
      else
        echo -e "  ${GREEN}✔️  Chave encontrada: $key${NC}"
      fi
    done
}

install_dev_kit() {
  install_lazy_git
  install_eza
  install_nvm
  install_starship
}

#----------------------------

install_common_packages

if $INSTALL_ZSH; then
  install_zsh_kit
fi

if $INSTALL_GIT; then
  install_git_kit
fi

if [ "$INSTALL_SSH" = true ] && [ "$INSTALL_GIT" != true ]; then
  apply_dotfiles ssh
fi

if $INSTALL_DEV; then
 install_dev_kit
fi

if $INSTALL_ALL; then
  install_zsh_kit
  install_git_kit
  install_dev_kit
fi

finalize_setup

echo -e "\n${GREEN}✅ Pronto. Instalação finalizada.${NC}"
