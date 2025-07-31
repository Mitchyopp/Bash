#!/usr/bin/env bash

set -euo pipefail
log() {
  echo -e "\033[1;35m➤ $1\033[0m"
}

# Make sure to to setup git with .gitconfig and ssh before this
log "Welcome to my installer"

USER="Mitchy"
dotfiles="https://github.com/Mitchyopp/dotfiles"
niri="https://github.com/Mitchyopp/niri"
neovim="https://github.com/Mitchyopp/neovim"

log "Cloning repos"
git clone "$dotfiles" "$HOME/dotfiles"
cd dotfiles
stow zsh nvim niri waybar ghostty mako fastfetch starship tmux
cd
log "dotfiles installed"
cd $HOME/.config
rm -rf niri
git clone "$niri" niri
log "niri installed"
git clone "$neovim" nvim
log "neovim installed"

sleep 1

log "Installing Paru"

cd
sudo pacman -S --needed base-devel
git clone https://aur.archlinux.org/paru.git
cd paru
makepkg -si

sleep 5

log "Paru installed"

cd

log "Installing packages, this might take a while."


paru -S --needed --noconfirm base-devel \
  niri xdg-desktop-portal-gtk xdg-desktop-portal-gnome \
  swww waypaper vesktop tmux git neovim fuzzel ghostty alacritty \
  waybar starship pipewire wireplumber blueman zen-browser fzf \
  zoxide fzf nerd-fonts ttf-noto-nerd fastfetch \
  prismlauncher spotify spicetfy-cli zsh

log "Packages installed!"

sleep 1

log "Changing shell to zsh"
chsh -s /bin/zsh "$USER"

export ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"

git clone https://github.com/zsh-users/zsh-autosuggestions.git "$ZSH_CUSTOM/plugins/zsh-autosuggestions"
git clone https://github.com/zsh-users/zsh-syntax-highlighting.git "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting"

[[ -f "$HOME/.zshrc" ]] && mv "$HOME/.zshrc" "$HOME/.zshrc.bak"
[[ -f "$HOME/.zshrc.pre-oh-my-zsh" ]] && mv "$HOME/.zshrc.pre-oh-my-zsh" "$HOME/.zshrc"

log "zsh installed"
