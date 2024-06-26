# -*- mode: ruby-ts;-*-
tap "babashka/brew"
tap "borkdude/brew"
tap "clojure-lsp/brew"
tap "clojure/tools"
tap "d12frosted/emacs-plus" if OS.mac?
tap "homebrew/bundle"

brew "borkdude/brew/babashka"
brew "babashka/brew/neil"
brew "clojure-lsp/brew/clojure-lsp-native"
brew "clojure/tools/clojure"

brew "age"
brew "aspell"
brew "bash-language-server"
brew "bat"
brew "d12frosted/emacs-plus/emacs-plus", args: ["with-native-comp"] if OS.mac?
brew "enchant" # For jinx module build
brew "exercism"
brew "eza"
brew "fd"
brew "fish" if OS.mac?
brew "fisher"
brew "fzf"
# For the emacs-plus build, native-comp, and the jinx module
brew "gcc" if OS.mac?
brew "git"
brew "go"
brew "golangci-lint"
brew "gopls"
brew "htop"
brew "jq"
brew "ollama"
brew "openjdk" if OS.mac?
brew "leiningen"
brew "mas" if OS.mac?
brew "pkg-config" if OS.mac? # For jinx module build
brew "ripgrep"
brew "rustup-init"
brew "shellcheck"
brew "terminal-notifier" if OS.mac?
brew "tmux"
brew "tokei"
brew "watch"

cask "1password"
cask "1password-cli"
cask "alacritty", args: {"no-quarantine": true}
cask "alfred"
cask "arc"
cask "arq"
cask "balenaetcher"
cask "calibre"
cask "daisydisk"
cask "dash"
cask "discord"
cask "font-hack-nerd-font"
cask "hammerspoon"
cask "istat-menus"
cask "launchcontrol"
cask "monitorcontrol"
cask "obsidian"
cask "openaudible"
cask "plexamp"
cask "rectangle"
cask "slack"
cask "spotify"
cask "steam"
cask "syncthing"
cask "transmission"
cask "transmit"

mas "Ivory", id: 6444602274
mas "Parcel", id: 639968404
mas "Tailscale", id: 1475387142
mas "Things", id: 904280696
