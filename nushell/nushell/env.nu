# go lang
$env.GOROOT = "/usr/local/go"
$env.GOPATH = $"($env.HOME)/go"
$env.GOBIN = $"($env.GOROOT)/bin"
$env.GO111MODULE = "on"

# opencode
$env.OPENCODE_ENABLE_EXA = true

# bun
$env.BUN_INSTALL = $"($env.HOME)/.bun"

# flutter
$env.PUB_HOSTED_URL = "https://pub.flutter-io.cn"
$env.FLUTTER_STORAGE_BASE_URL = "https://storage.flutter-io.cn"

let base_paths = [
  $"($env.HOME)/.cargo/bin",
  $"($env.HOME)/.local/share/bob/nvim-bin",
  $"($env.HOME)/.config/emacs/bin",
  $"($env.HOME)/.local/bin",
  $"($env.GOBIN)",
  $"($env.BUN_INSTALL)/bin",
  $"($env.HOME)/dotfiles",
]

let os_specific_paths = match $nu.os-info.name {
  macos =>
    [
      "/opt/homebrew/bin",
      "/opt/homebrew/sbin",
      "/opt/homebrew/opt/grep/libexec/gnubin",
      "/usr/local/bin",
      $"($env.HOME)/Library/python/3.9/bin",
      $"($env.HOME)/flutter_sdk/bin", # move to bash_paths?
      "/opt/homebrew/opt/llvm/bin",
      "/opt/homebrew/opt/ruby/bin",
    ],
  linux =>
    [
      "/usr/local/bin",
    ],
  _ => []
}

# 本机私有变量优先放在 ~/.config/secrets，兼容旧的 env.local.nuon。
let local_env_candidates = [
  ($env.HOME | path join ".config" "secrets" "nushell.env.nuon")
  ($nu.default-config-dir | path join "env.local.nuon")
]
for candidate in $local_env_candidates {
  if ($candidate | path exists) {
    open --raw $candidate | from nuon | load-env
  }
}

let paths = ($os_specific_paths | append $base_paths | where {|p| $p | path exists})
# add paths to env.PATH
$env.PATH = ($paths | prepend $env.PATH | uniq)

if $nu.os-info.name == macos {
  let posh_dir = (brew --prefix oh-my-posh | str trim)
  let posh_theme = $'($posh_dir)/share/oh-my-posh/themes/'
  # $env.PROMPT_COMMAND = {oh-my-posh prompt print primary --config $'($posh_theme)/atomic.omp.json'}
  $env.PROMPT_COMMAND = {oh-my-posh init nu print primary --config $'($posh_theme)/atomic.omp.json'}
}

#$env.EDITOR = (which neovide | get path.0 | default "vim")
#$env.EDITOR = 'emacsclient'
$env.EDITOR = 'nvim'
$env.VISUAL = $env.EDITOR

# Set plugin path
# if $nu.os-info.name == macos {
#    const NU_PLUGIN_DIRS = [
#          $"($env.HOME)/nu_plugins",
# ]}

# $env.http_proxy = 'http://127.0.0.1:9910'
# $env.https_proxy = 'http://127.0.0.1:9910'
# $env.all_proxy = 'socks5://127.0.0.1:9909'
