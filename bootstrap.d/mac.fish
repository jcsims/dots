set target_jdk_path /Library/Java/JavaVirtualMachines/openjdk.jdk
if ! test -e $target_jdk_path; or ! test /opt/homebrew/opt/openjdk/libexec/openjdk.jdk -ef $target_jdk_path
    info "Linking Homebrew JDK..."
    sudo ln -sfn /opt/homebrew/opt/openjdk/libexec/openjdk.jdk $target_jdk_path
end

info "Set key repeat rate and delay..."
defaults write -g InitialKeyRepeat -int 15
defaults write -f KeyRepeat -int 2

if ! test -e $HOME/bin/mkalias
    info "Grabbing mkalias..."
    curl 'https://f000.backblazeb2.com/file/mkalias/mkalias' -o $HOME/bin/mkalias; and chmod +x $HOME/bin/mkalias
end

if ! test -e /Applications/Emacs.app
    info "Creating alias for emacs-plus..."
    mkalias "$(brew --prefix emacs-plus)/Emacs.app" /Applications/Emacs.app
end
