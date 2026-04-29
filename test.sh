#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
DOT_SCRIPT="$SCRIPT_DIR/dot"

pass() {
  printf 'PASS %s\n' "$1"
}

fail() {
  printf 'FAIL %s\n' "$1" >&2
  exit 1
}

assert_contains() {
  local needle="$1"
  local haystack_file="$2"
  local message="$3"
  if ! rg -F --quiet -- "$needle" "$haystack_file"; then
    printf 'Expected to find: %s\n' "$needle" >&2
    printf 'In file: %s\n' "$haystack_file" >&2
    fail "$message"
  fi
}

assert_path_absent() {
  local path="$1"
  local message="$2"
  if [[ -e "$path" || -L "$path" ]]; then
    fail "$message"
  fi
}

assert_symlink_exists() {
  local path="$1"
  local message="$2"
  if [[ ! -L "$path" ]]; then
    fail "$message"
  fi
}

make_fake_stow() {
  local bin_dir="$1"
  local log_file="$2"

  mkdir -p "$bin_dir"
  cat >"$bin_dir/stow" <<EOF
#!/usr/bin/env bash
printf '%s\n' "\$*" >>"$log_file"
exit 0
EOF
  chmod +x "$bin_dir/stow"
}

test_dry_run_defaults_to_install() {
  local tmp_dir tmp_home tmp_bin output_file stow_log
  tmp_dir=$(mktemp -d)
  tmp_home="$tmp_dir/home"
  tmp_bin="$tmp_dir/bin"
  output_file="$tmp_dir/output.txt"
  stow_log="$tmp_dir/stow.log"

  mkdir -p "$tmp_home"
  make_fake_stow "$tmp_bin" "$stow_log"

  TERM=xterm HOME="$tmp_home" PATH="$tmp_bin:$PATH" "$DOT_SCRIPT" --dry-run >"$output_file"

  assert_contains "Would deploy: neovim" "$output_file" "dry-run should trigger install mode"
  assert_contains "--no-folding" "$stow_log" "dry-run should disable tree folding"
  assert_contains "-n -t $tmp_home/.config neovim" "$stow_log" "dry-run should call stow with -n"
  pass "dry-run defaults to install"
}

test_adopt_flag_reaches_stow() {
  local tmp_dir tmp_home tmp_bin stow_log
  tmp_dir=$(mktemp -d)
  tmp_home="$tmp_dir/home"
  tmp_bin="$tmp_dir/bin"
  stow_log="$tmp_dir/stow.log"

  mkdir -p "$tmp_home"
  make_fake_stow "$tmp_bin" "$stow_log"

  TERM=xterm HOME="$tmp_home" PATH="$tmp_bin:$PATH" "$DOT_SCRIPT" install --adopt --dry-run >/dev/null

  assert_contains "--adopt -t $tmp_home/.config neovim" "$stow_log" "install --adopt should pass --adopt to stow"
  pass "adopt flag reaches stow"
}

test_help_mentions_new_flags() {
  local tmp_dir output_file
  tmp_dir=$(mktemp -d)
  output_file="$tmp_dir/help.txt"

  TERM=xterm "$DOT_SCRIPT" --help >"$output_file"

  assert_contains "--adopt" "$output_file" "help should mention adopt flag"
  assert_contains "./dot --dry-run" "$output_file" "help should document flag-only dry-run"
  pass "help mentions new flags"
}

test_help_works_without_term() {
  local tmp_dir output_file
  tmp_dir=$(mktemp -d)
  output_file="$tmp_dir/help-no-term.txt"

  env -u TERM "$DOT_SCRIPT" --help >"$output_file"

  assert_contains "Dotfiles Management Script" "$output_file" "help should not require TERM"
  pass "help works without TERM"
}

test_dry_run_reports_stale_package_links() {
  local tmp_dir tmp_home tmp_bin output_file stow_log stale_link stale_target
  tmp_dir=$(mktemp -d)
  tmp_home="$tmp_dir/home"
  tmp_bin="$tmp_dir/bin"
  output_file="$tmp_dir/output.txt"
  stow_log="$tmp_dir/stow.log"
  stale_link="$tmp_home/.config/nvim/deleted.lua"
  stale_target="$SCRIPT_DIR/neovim/nvim/deleted.lua"

  mkdir -p "$tmp_home/.config/nvim"
  ln -s "$stale_target" "$stale_link"
  make_fake_stow "$tmp_bin" "$stow_log"

  TERM=xterm HOME="$tmp_home" PATH="$tmp_bin:$PATH" "$DOT_SCRIPT" install --dry-run >"$output_file"

  assert_contains "Would remove stale symlink: $stale_link -> $stale_target" "$output_file" "dry-run should report stale package links"
  assert_symlink_exists "$stale_link" "dry-run should not remove stale links"
  pass "dry-run reports stale package links"
}

test_install_prunes_only_stale_package_links() {
  local tmp_dir tmp_home tmp_bin output_file stow_log stale_link stale_target local_link local_target
  tmp_dir=$(mktemp -d)
  tmp_home="$tmp_dir/home"
  tmp_bin="$tmp_dir/bin"
  output_file="$tmp_dir/output.txt"
  stow_log="$tmp_dir/stow.log"
  stale_link="$tmp_home/.config/nvim/deleted.lua"
  stale_target="$SCRIPT_DIR/neovim/nvim/deleted.lua"
  local_link="$tmp_home/.config/nvim/local-deleted.lua"
  local_target="$tmp_dir/local-deleted.lua"

  mkdir -p "$tmp_home/.config/nvim"
  ln -s "$stale_target" "$stale_link"
  ln -s "$local_target" "$local_link"
  make_fake_stow "$tmp_bin" "$stow_log"

  TERM=xterm HOME="$tmp_home" PATH="$tmp_bin:$PATH" "$DOT_SCRIPT" install >"$output_file"

  assert_contains "Removed stale symlink: $stale_link -> $stale_target" "$output_file" "install should remove stale package links"
  assert_path_absent "$stale_link" "install should delete stale package links"
  assert_symlink_exists "$local_link" "install should not delete stale links outside the package"
  pass "install prunes only stale package links"
}

main() {
  test_dry_run_defaults_to_install
  test_adopt_flag_reaches_stow
  test_help_mentions_new_flags
  test_help_works_without_term
  test_dry_run_reports_stale_package_links
  test_install_prunes_only_stale_package_links
}

main "$@"
