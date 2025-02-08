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
$env.GOPATH = "/Users/apollo/go"
$env.GOBIN = $"($env.GOROOT)/bin"
$env.GO111MODULE = "on"

# Set PATH
let paths = [
  "/opt/homebrew/bin", 
  "/Users/apollo/.local/share/bob/nvim-bin", 
  "/Users/apollo/.cargo/bin",
  "/opt/homebrew/opt/grep/libexec/gnubin",
  "/Users/apollo/.config/emacs/bin",
  $"($env.GOBIN)"
]
$env.PATH = ($env.PATH | each {|path| $path} | append $paths)

$env.EDITOR = 'nvim'

# oh-my-posh and theme
let posh_dir = (brew --prefix oh-my-posh | str trim)
let posh_theme = $'($posh_dir)/share/oh-my-posh/themes/'
$env.THEME = 'atomicBit'
oh-my-posh init nu --config $'($posh_dir)/share/oh-my-posh/themes/($env.THEME).omp.json'

