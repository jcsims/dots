# Fish completion for deploy.fish script

# Helper function to get available services
function __deploy_services
    # Get service directories from splash/services/
    if test -d splash/services
        for dir in splash/services/*/
            basename $dir
        end
    end
end

# Helper function to get git branches
function __deploy_branches
    git branch --all --format='%(refname:short)' 2>/dev/null
end

# Complete -b/--branch with git branches
complete -c deploy -s b -l branch -x -a "(__deploy_branches)" -d "Git branch or ref to deploy"

# Complete -e/--env with stage and prod
complete -c deploy -s e -l env -l environments -x -a "stage prod" -d "Environment to deploy to"

# Complete -d/--dry-run
complete -c deploy -s d -l dry-run -d "Print command without executing it"

# Complete -h/--help
complete -c deploy -s h -l help -d "Show help message"

# Complete service names (non-option arguments)
complete -c deploy -f -n "not __fish_seen_subcommand_from -h --help" -a "(__deploy_services)" -d "Service to deploy"
