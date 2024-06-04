if type -q brew; and set -q HOMEBREW_BUNDLE_FILE
    if ! brew bundle check -q
        info "Making sure brew packages are installed..."
        brew bundle
    end
else
    warn "Homebrew not installed or not yet configured, not attempting package install..."
end
