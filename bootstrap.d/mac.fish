set target_jdk_path /Library/Java/JavaVirtualMachines/openjdk.jdk
if ! test -e $target_jdk_path; or ! test /opt/homebrew/opt/openjdk/libexec/openjdk.jdk -ef $target_jdk_path
    info "Linking Homebrew JDK..."
    sudo ln -sfn /opt/homebrew/opt/openjdk/libexec/openjdk.jdk $target_jdk_path
end

info "Configuring keyboard"
defaults write NSGlobalDomain ApplePressAndHoldEnabled -bool false
defaults write -g InitialKeyRepeat -int 15
defaults write -f KeyRepeat -int 2

info "Setting the proper scroll direction"
defaults write -g com.apple.swipescrolldirection -boolean NO

info "Turning off strange bold fonts in Alacritty"
defaults write org.alacritty AppleFontSmoothing -int 0

info "Configuring the Dock"
defaults write com.apple.dock orientation -string left
defaults write com.apple.dock tilesize -int 40
# Don't show recent apps in the Dock
defaults write com.apple.dock show-recents -bool false
# This only shows open applications, which is awesome
defaults write com.apple.dock static-only -bool true
killall Dock

info "Configuring Finder"
defaults write com.apple.finder ShowPathbar -bool true

if ! test -e $HOME/bin/mkalias
    info "Grabbing mkalias..."
    curl 'https://f000.backblazeb2.com/file/mkalias/mkalias' -o $HOME/bin/mkalias; and chmod +x $HOME/bin/mkalias
end

info "Creating/updating alias for emacs-plus..."
mkalias "$(brew --prefix emacs-plus)/Emacs.app" /Applications/Emacs.app
