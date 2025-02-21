#!/bin/bash
set -eo pipefail

# define color
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# ==================== Configuration Definition Section ====================
# Format: PlatformType|ConfigName|TargetPath (relative to $HOME)
declare -a CONFIG_ENTRIES=(
  # Common configurations (apply to all platforms)
  "common|neovim|.config"
  "common|doomemacs|.config"
  "common|kitty|.config"
  "common|zed|.config"

  # macOS specific configurations
  "Darwin|nushell|Library/Application Support"

  # Linux specific configurations
  "Linux|nushell|.config"
  "Linux|hyprland|.config"
  "Linux|wlogout|.config"
  "Linux|rofi|.config"
  "Linux|waybar|.config"
  "Linux|mako|.config"
)
# =========================================================================

check_dependencies() {
  if ! command -v stow &>/dev/null; then
    echo -e "${RED}Error:${NC} 'stow' not found"
    exit 1
  fi
}

validate_entry() {
  local entry="$1"
  if [[ $(echo "$entry" | tr -cd '|' | wc -c) -ne 2 ]]; then
    echo -e "${RED}Error:${NC} Invalid entry format: [$entry]"
    echo "Expected format: PlatformType|ConfigName|RelativeTargetPath"
    exit 1
  fi
}

# Get current OS type
get_os_type() {
  uname -s
}

# Main installation logic
install_configs() {
  local os_type=$(get_os_type)
  local home_dir="$HOME"
  local exit_code=0

  # Process all configuration entries
  for entry in "${CONFIG_ENTRIES[@]}"; do
    validate_entry "$entry"
    # Parse configuration entry
    IFS='|' read -r target_os config_name relative_path <<<"$entry"

    # Skip entries not for current platform
    if [[ "$target_os" != "common" && "$target_os" != "$os_type" ]]; then
      continue
    fi

    # Build full target path
    local target_path="${home_dir}/${relative_path}"

    # Create target directory (handle spaces in path)
    mkdir -p "$target_path" || {
      echo -e "${RED}Error:${NC} Failed to create directory [$target_path]"
      exit_code=1
      continue
    }

    # Verify configuration directory exists
    if [[ ! -d "$config_name" ]]; then
      echo -e "${YELLOW}Warning:${NC} Config directory [$config_name] does not exist"
      continue
    fi

    # Perform installation
    echo -e "${GREEN}==> Deploying:${NC} $config_name → $target_path"
    stow -v -t "$target_path" "$config_name" || {
      echo -e "${RED}Error:${NC} Failed to deploy $config_name"
      exit_code=1
    }
  done

  return $exit_code
}

# Main function
main() {
  check_dependencies
  install_configs
  echo -e "${GREEN}✅ All configurations deployed successfully${NC}"
}

# Execution entry point
main "$@"
