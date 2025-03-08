# go lang
$env.GOROOT = "/usr/local/go"
$env.GOPATH = $"($env.HOME)/go"
$env.GOBIN = $"($env.GOROOT)/bin"
$env.GO111MODULE = "on"

let base_paths = [
  $"($env.HOME)/.cargo/bin",
  $"($env.HOME)/.local/share/bob/nvim-bin",
  $"($env.HOME)/.config/emacs/bin",
  $"($env.HOME)/.local/bin",
  $"($env.GOBIN)"
]

let os_specific_paths = match $nu.os-info.name {
  macos => 
    [
      "/opt/homebrew/bin",
      "/opt/homebrew/opt/grep/libexec/gnubin",
      "/usr/local/bin",
      $"($env.HOME)/Library/python/3.9/bin",
    ],
  _ => []
}

let paths = ($base_paths | append $os_specific_paths | where {|p| $p | path exists})
# add paths to env.PATH
$env.PATH = ($paths | prepend $env.PATH | uniq)

if $nu.os-info.name == macos {
  let posh_dir = (brew --prefix oh-my-posh | str trim)
  let posh_theme = $'($posh_dir)/share/oh-my-posh/themes/'
  $env.PROMPT_COMMAND = {oh-my-posh prompt print primary --config $'($posh_theme)/atomic.omp.json'}
}
$env.EDITOR = (which neovide | get path.0 | default "vim")
$env.VISUAL = $env.EDITOR
