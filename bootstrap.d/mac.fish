set target_jdk_path /Library/Java/JavaVirtualMachines/openjdk.jdk
if ! test -e $target_jdk_path; or ! test /opt/homebrew/opt/openjdk/libexec/openjdk.jdk -ef $target_jdk_path
    info "Linking Homebrew JDK..."
    sudo ln -sfn /opt/homebrew/opt/openjdk/libexec/openjdk.jdk $target_jdk_path
end

info "Configuring keyboard"
# `-g` is short for the global namespace, aka the "Apple Global Domain"
defaults write NSGlobalDomain ApplePressAndHoldEnabled -bool false
defaults write -g InitialKeyRepeat -int 15
defaults write -g KeyRepeat -int 2

info "Setting the proper scroll direction"
defaults write -g com.apple.swipescrolldirection -boolean NO

info "Configuring the Dock"
defaults write com.apple.dock orientation -string left
defaults write com.apple.dock tilesize -int 40
# Don't show recent apps in the Dock
defaults write com.apple.dock show-recents -bool false
# This only shows open applications, which is awesome
defaults write com.apple.dock static-only -bool true
# Don't show the active indicator dot by each application
defaults write com.apple.dock show-process-indicators -bool false
killall Dock

info "Configuring Finder"
defaults write com.apple.finder ShowPathbar -bool true
