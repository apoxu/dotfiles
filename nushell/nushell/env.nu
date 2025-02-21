# env.nu
#
# Installed by:
# version = "0.101.1"
#
# Previously, environment variables were typically configured in `env.nu`.
# In general, most configuration can and should be performed in `config.nu`
# or one of the autoload directories.
#
# This file is generated for backwards compatibility for now.
# It is loaded before config.nu and login.nu
#
# See https://www.nushell.sh/book/configuration.html
#
# Also see `help config env` for more options.
#
# You can remove these comments if you want or leave
# them for future reference.

# go lang
$env.GOROOT = "/usr/local/go"
$env.GOPATH = $"($env.HOME)/go"
$env.GOBIN = $"($env.GOROOT)/bin"
$env.GO111MODULE = "on"

let base_paths = [
  $"($env.HOME)/.cargo/bin",
  $"($env.HOME)/.local/share/bob/nvim-bin",
  $"($env.HOME)/.config/emacs/bin",
  $"($env.GOBIN)"
]

let os_specific_paths = match $nu.os-info.name {
  macos => 
    [
     "/opt/homebrew/bin",
     "/opt/homebrew/opt/grep/libexec/gnubin"
    ],
  _ => []
}

let paths = ($base_paths | append $os_specific_paths | where {|p| $p | path exists})

# add paths to env.PATH
$env.PATH = ($paths | prepend $env.PATH | uniq)
$env.EDITOR = (which neovide | get path.0 | default "vim")
$env.VISUAL = $env.EDITOR
