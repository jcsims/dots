if type -q brew; and set -q HOMEBREW_BUNDLE_FILE
    set target_jdk_path /Library/Java/JavaVirtualMachines/openjdk.jdk
    if ! brew bundle check -q
	info "Making sure brew packages are installed..."
	brew bundle
    end
    if ! test -e $target_jdk_path; or ! test /opt/homebrew/opt/openjdk/libexec/openjdk.jdk -ef $target_jdk_path
        info "Linking Homebrew JDK..."
        sudo ln -sfn /opt/homebrew/opt/openjdk/libexec/openjdk.jdk /Library/Java/JavaVirtualMachines/openjdk.jdk
    end
else
    warn "Homebrew not installed or not yet configured, not attempting package install..."
end


# TODO: Compile jinx module on macos?
# gcc -I. -O2 -Wall -Wextra -fPIC -shared -o jinx-mod.dylib jinx-mod.c -I/opt/homebrew/opt/enchant/include/enchant-2 -L /opt/homebrew/opt/enchant/lib -lenchant-2

info "Set key repeat rate and delay..."
defaults write -g InitialKeyRepeat -int 15
defaults write -f KeyRepeat -int 2
