#!/bin/bash

# install configs
# default_path: $HOME/.config
install-config() {
  local list="$1"
  local path="$HOME/.config"
  if [ $# -eq 2 ]; then
    path="$2"
  fi
  for conf in ${list[@]}; do
    stow -t $path $conf || {
      echo "Error: stow failed for $conf"
      return 1
    }
  done
}

# general configs
config_list="neovim doomemacs kitty waybar"
install-config "$config_list"

# OS specific configs
OS=$(uname -s)
case "$OS" in
Dawin)
  install-config "nushell" "$HOME/Library/Application\ Support"
  ;;
Linux)
  install-config "nushell hyprland"
  ;;
*)
  echo "Error: unknown system: $OS"
  return 1
  ;;
esac
