if type -q brew
    if ! brew bundle check -q
        info "Making sure brew packages are installed..."
        brew bundle
    end
else
    warn "Homebrew not installed or not yet configured, not attempting package install..."
end
