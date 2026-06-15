if type -q brew
    if ! brew bundle check --global -q
        info "Making sure brew packages are installed..."
        brew bundle --global --force-cleanup
    end
else
    warn "Homebrew not installed or not yet configured, not attempting package install..."
end
