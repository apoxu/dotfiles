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

main() {
  test_dry_run_defaults_to_install
  test_adopt_flag_reaches_stow
  test_help_mentions_new_flags
}

main "$@"
