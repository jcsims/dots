fish_add_path -m ~/.cargo/bin
fish_add_path -m /opt/homebrew/bin
fish_add_path -m /opt/homebrew/sbin
if type -q go
    fish_add_path -m $(go env GOPATH)/bin
end
fish_add_path -m ~/bin

set -gx CLICOLOR 1
set -gx EDITOR $HOME/bin/e
set -gx VISUAL $HOME/bin/ec
set -gx GNUPGHOME $HOME/.gnupg
set -gx BAT_THEME 'Monokai Extended'
set -gx PROJECT_PATHS $HOME/code $HOME/code/work

if test $(whoami) = csims
    set -gx HOMEBREW_BUNDLE_FILE $HOME/.Brewfile-work
else
    set -gx HOMEBREW_BUNDLE_FILE $HOME/.Brewfile
end

# Remove the default greeting message on a new shell
set -g fish_greeting

# Some prompt color
set -g hydro_color_prompt green
set -g hydro_color_pwd blue
set -g hydro_color_duration yellow

# Increase the count of open files allowed (default is 256 on macOS)
ulimit -Sn 4096

# For done notifications, don't notify when it's running emacs from the shell
set -U --append __done_exclude '^emacsclient'

if status is-interactive
    abbr --add ga 'git add'
    abbr --add gc 'git commit'
    abbr --add gco 'git checkout'
    abbr --add gd 'git diff'
    abbr --add gdc 'git diff --cached'
    abbr --add gl 'git log --graph --abbrev-commit --date=relative --pretty=format:'\''%C(bold blue)%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset'\'''
    abbr --add gp 'git push origin HEAD'
    abbr --add gpl 'git pull --rebase --prune'
    abbr --add gs 'git status -sb'

    abbr --add cat bat

    alias eza 'eza '\''--icons'\'' '\''--git'\'''
    alias la 'eza -a'
    alias ll 'eza -l'
    alias lla 'eza -la'
    alias ls eza
    alias lt 'eza --tree'

    abbr --add c pj
    abbr --add co 'pj open'
end
