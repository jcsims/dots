#!/usr/bin/env fish

function __deploy_show_help
    echo "Usage: deploy.fish [OPTIONS] SERVICE [SERVICE...]"
    echo ""
    echo "Deploy services via GitHub Actions CICD workflow"
    echo ""
    echo "Arguments:"
    echo "  SERVICE                One or more services to deploy"
    echo "                         Examples: forge, los_api"
    echo ""
    echo "Options:"
    echo "  -b, --branch BRANCH    Git branch/ref to deploy (default: current branch)"
    echo "  -e, --env ENVIRONMENTS Environments to deploy to (default: stage)"
    echo "                         Space-separated: 'stage' or 'stage prod'"
    echo "  -d, --dry-run          Print the gh command without executing it"
    echo "  -h, --help             Show this help message"
    echo ""
    echo "Examples:"
    echo "  ./deploy.fish forge"
    echo "  ./deploy.fish -b master forge los_api"
    echo "  ./deploy.fish -e 'stage prod' forge"
    echo "  ./deploy.fish -d forge  # dry-run mode"
end

function deploy
    # Parse arguments
    set -l branch ""
    set -l environments stage
    set -l services
    set -l dry_run false

    set -l i 1
    while test $i -le (count $argv)
        set -l arg $argv[$i]

        switch $arg
            case -h --help
                __deploy_show_help
                exit 0
            case -d --dry-run
                set dry_run true
            case -b --branch
                set i (math $i + 1)
                if test $i -le (count $argv)
                    set branch $argv[$i]
                else
                    echo "Error: --branch requires an argument" >&2
                    exit 1
                end
            case -e --env --environments
                set i (math $i + 1)
                if test $i -le (count $argv)
                    set environments $argv[$i]
                else
                    echo "Error: --env requires an argument" >&2
                    exit 1
                end
            case '-*'
                echo "Error: Unknown option: $arg" >&2
                __deploy_show_help
                exit 1
            case '*'
                set -a services $arg
        end

        set i (math $i + 1)
    end

    # Validate that at least one service is provided
    if test (count $services) -eq 0
        echo "Error: At least one service must be specified" >&2
        echo ""
        __deploy_show_help
        exit 1
    end

    # Get current branch if not specified
    if test -z "$branch"
        set branch (git rev-parse --abbrev-ref HEAD)
        if test $status -ne 0
            echo "Error: Failed to get current branch" >&2
            exit 1
        end
    end

    # Add splash/services/ prefix to service names
    set -l prefixed_services
    for service in $services
        set -a prefixed_services "splash/services/$service"
    end

    # Join services into a space-separated string
    set -l services_str (string join " " $prefixed_services)

    # Display what we're about to do
    echo "Deploying services via GitHub Actions:"
    echo "  Branch: $branch"
    echo "  Environments: $environments"
    echo "  Services: $services_str"
    echo ""

    # Construct the command
    set -l gh_command gh workflow run cicd.yml \
        -f deployment_git_rev="$branch" \
        -f environments="$environments" \
        -f services="$services_str"

    # Run the workflow (or dry-run)
    if test "$dry_run" = true
        echo "Dry-run mode: Would execute:"
        echo "$gh_command"
    else
        eval $gh_command

        if test $status -eq 0
            echo ""
            echo "✓ Workflow triggered successfully"
            echo "View workflow runs: gh run list --workflow=cicd.yml"
            echo "Watch latest run: gh run watch"
        else
            echo ""
            echo "✗ Failed to trigger workflow" >&2
            exit 1
        end
    end

end
