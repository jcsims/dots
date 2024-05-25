# -*- mode: ruby-ts;-*-
# An example of OS-specific packages:
# install only on specified OS
#brew "gnupg" if OS.mac?
#brew "glibc" if OS.linux?
tap "babashka/brew"
tap "borkdude/brew"
tap "clojure-lsp/brew"
tap "clojure/tools"
tap "d12frosted/emacs-plus"
tap "homebrew/bundle"

brew "borkdude/brew/babashka"
brew "babashka/brew/neil"
brew "clojure-lsp/brew/clojure-lsp-native"
brew "clojure/tools/clojure"

brew "aspell"
brew "bash-language-server"
brew "bat"
brew "d12frosted/emacs-plus/emacs-plus", args: ["with-native-comp"] if OS.mac?
brew "enchant" if OS.mac? # For jinx module build
brew "exercism"
brew "eza"
brew "fd"
brew "fish"
brew "fisher"
brew "fzf"
# For the emacs-plus build
brew "gcc" if OS.mac?
brew "git"
brew "go"
brew "golangci-lint"
brew "gopls"
brew "htop"
brew "jq"
# For the system Java wrappers to find this JDK, symlink it with
#   sudo ln -sfn /opt/homebrew/opt/openjdk/libexec/openjdk.jdk /Library/Java/JavaVirtualMachines/openjdk.jdk
brew "openjdk" if OS.mac?
brew "leiningen"
brew "mas" if OS.mac?
brew "pass"
brew "pkg-config" if OS.mac? # For jinx module build
brew "ripgrep"
brew "rustup-init"
brew "shellcheck"
brew "terminal-notifier" if OS.mac?
brew "tmux"
brew "tokei"
brew "watch"

cask "1password"
cask "alacritty", args: {"no-quarantine": true}
cask "alfred"
cask "arq"
cask "balenaetcher"
cask "calibre"
cask "daisydisk"
cask "dash"
cask "discord"
cask "font-hack-nerd-font"
cask "gpg-suite"
cask "hammerspoon"
cask "istat-menus"
cask "launchcontrol"
cask "maestral"
cask "monitorcontrol"
cask "obsidian"
cask "plexamp"
cask "rectangle"
cask "slack"
cask "spotify"
cask "syncthing"
cask "transmission"
cask "transmit"

mas "Tailscale", id: 1475387142
mas "Things", id: 904280696
