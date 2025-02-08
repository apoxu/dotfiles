#!/bin/bash

# default_path: $HOME
install() {
  local list="$1"
  local path="$HOME"
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

# confs in .$HOME/config
config_list="neovim doomemacs kitty"
install "$config_list" "$HOME/.config"

# OS specific configurations
OS=$(uname -s)
case "$OS" in
Dawin)
  install "nushell" "$HOME/Library/Application\ Support"
  ;;
Linux)
  install "nushell" "$HOME/.config"
  install "hyprland" "$HOME/.config"

  ;;
*)
  echo "Error: unknown system: $OS"
  return 1
  ;;
esac
