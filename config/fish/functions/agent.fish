function agent --description "Manage Claude Code agent worktrees"
    set -l cmd $argv[1]
    set -l args $argv[2..-1]

    # Detect repo root and name
    set -l repo_root (git rev-parse --show-toplevel 2>/dev/null)
    or begin
        echo "Error: Not in a git repository"
        return 1
    end
    set -l repo_name (basename $repo_root)
    set -l agents_dir "$repo_root/.agents"

    switch $cmd
        case new create
            argparse --name="agent new" c/current -- $args
            or return 1

            set -l name $argv[1]
            set -l explicit_base $argv[2]

            if test -z "$name"
                echo "Usage: agent new <name> [--current|-c] [base-branch]"
                echo "  Creates a new worktree for an agent to work in"
                echo ""
                echo "Options:"
                echo "  --current, -c    Base off current branch instead of main/master"
                echo "  base-branch      Explicitly specify base branch"
                return 1
            end

            # Determine base branch
            set -l base_branch
            if test -n "$explicit_base"
                set base_branch $explicit_base
            else if set -q _flag_current
                set base_branch (git symbolic-ref --short HEAD 2>/dev/null)
                or begin
                    echo "Error: Could not determine current branch"
                    return 1
                end
            else
                set base_branch (_agent_default_branch)
                or return 1
            end

            set -l worktree_path "$agents_dir/$name"
            set -l branch_name "jcs/$name"

            mkdir -p $agents_dir
            echo "Creating agent worktree '$name' from '$base_branch'..."

            git worktree add -b $branch_name $worktree_path $base_branch
            or begin
                echo "Error: Failed to create worktree"
                return 1
            end

            # Copy and augment CLAUDE.md if it exists
            if test -f "$repo_root/CLAUDE.md"
                set -l subtree_context "# Subtree Context

You are working in an agent subtree at:
  $worktree_path

This subtree directory should be used for ALL work, including exploratory work,
scratch files, and any other files you need to create. Do not modify files
outside this directory.

---

"
                echo -n $subtree_context >"$worktree_path/CLAUDE.md"
                cat "$repo_root/CLAUDE.md" >>"$worktree_path/CLAUDE.md"
                echo "Copied CLAUDE.md with subtree context"
            end

            echo ""
            echo "Agent worktree created:"
            echo "  Path:   $worktree_path"
            echo "  Branch: $branch_name"
            echo ""
            echo "To start working:"
            echo "  cd $worktree_path && claude"
            echo ""
            echo "Or use: agent start $name"

        case list ls
            if not test -d $agents_dir
                echo "No agent worktrees found in $repo_name"
                return 0
            end

            set -l dirs $agents_dir/*/
            if test (count $dirs) -eq 0 -o "$dirs[1]" = "$agents_dir/*/"
                echo "No agent worktrees found in $repo_name"
                return 0
            end

            echo "Agent worktrees for $repo_name:"
            echo ""

            for dir in $dirs
                test -d "$dir"; or continue

                set -l name (basename $dir)
                set -l branch (git -C $dir branch --show-current 2>/dev/null)
                set -l status_info ""

                set -l changes (git -C $dir status --porcelain 2>/dev/null)
                if test -n "$changes"
                    set status_info " (has changes)"
                end

                printf "  %-20s %s%s\n" $name $branch $status_info
            end
            echo ""

        case cd path
            set -l name $args[1]
            set -l worktree_path (_agent_require_worktree $agents_dir $name "cd (agent cd <name>)")
            or return 1

            echo $worktree_path

        case start
            set -l name $args[1]
            set -l worktree_path (_agent_require_worktree $agents_dir $name "agent start <name>")
            or return 1

            echo "Starting Claude in agent worktree '$name'..."
            cd $worktree_path && claude

        case remove rm delete
            argparse --name="agent remove" f/force -- $args
            or return 1

            set -l name $argv[1]
            set -l worktree_path (_agent_require_worktree $agents_dir $name "agent remove <name> [--force]")
            or return 1

            set -l branch_name "agent/$name"

            # Check for uncommitted changes
            set -l changes (git -C $worktree_path status --porcelain 2>/dev/null)
            if test -n "$changes"
                echo "Warning: Worktree has uncommitted changes!"
                read -P "Continue anyway? [y/N] " confirm
                if not string match -qi y -- $confirm
                    echo Aborted
                    return 1
                end
            end

            echo "Removing agent worktree '$name'..."
            git worktree remove $worktree_path --force

            if set -q _flag_force
                echo "Deleting branch '$branch_name'..."
                git branch -D $branch_name 2>/dev/null
            else
                echo "Branch '$branch_name' preserved. Delete with: git branch -D $branch_name"
            end

            echo "Done."

        case status
            set -l name $args[1]
            set -l worktree_path (_agent_require_worktree $agents_dir $name "agent status <name>")
            or return 1

            echo "Status for agent '$name':"
            git -C $worktree_path status

        case diff
            set -l name $args[1]
            set -l worktree_path (_agent_require_worktree $agents_dir $name "agent diff <name>")
            or return 1

            git -C $worktree_path diff

        case log
            set -l name $args[1]
            set -l worktree_path (_agent_require_worktree $agents_dir $name "agent log <name>")
            or return 1

            echo "Commits for agent '$name':"
            set -l default_branch (_agent_default_branch)
            git -C $worktree_path log --oneline $default_branch..HEAD 2>/dev/null
            or git -C $worktree_path log --oneline -10

        case merge
            set -l name $args[1]
            if test -z "$name"
                echo "Usage: agent merge <name>"
                echo "  Merges the agent's branch into your current branch"
                return 1
            end
            set -l branch_name "agent/$name"

            echo "Merging '$branch_name' into current branch..."
            git merge $branch_name

        case ''
            _agent_help

        case '*'
            echo "Unknown command: $cmd"
            echo "Run 'agent' for usage"
            return 1
    end
end

# Helper: Get default branch (main or master)
function _agent_default_branch
    if git show-ref --verify --quiet refs/heads/main
        echo main
    else if git show-ref --verify --quiet refs/heads/master
        echo master
    else
        echo "Error: Could not find main or master branch" >&2
        return 1
    end
end

# Helper: Validate worktree exists and return path
function _agent_require_worktree --argument-names agents_dir name usage
    if test -z "$name"
        echo "Usage: $usage"
        return 1
    end

    set -l worktree_path "$agents_dir/$name"
    if not test -d $worktree_path
        echo "Error: Agent worktree '$name' not found"
        return 1
    end

    echo $worktree_path
end

# Helper: Print help text
function _agent_help
    echo "agent - Manage Claude Code agent worktrees"
    echo ""
    echo "Usage: agent <command> [args]"
    echo ""
    echo "Commands:"
    echo "  new <name> [-c]      Create a new agent worktree (default: from main/master)"
    echo "  list                 List all agent worktrees"
    echo "  start <name>         Start Claude in an agent worktree"
    echo "  cd <name>            Print path (use: cd (agent cd name))"
    echo "  status <name>        Show git status for agent"
    echo "  diff <name>          Show diff for agent"
    echo "  log <name>           Show commits for agent"
    echo "  merge <name>         Merge agent branch into current branch"
    echo "  remove <name>        Remove an agent worktree"
    echo ""
    echo "Example workflow:"
    echo "  agent new feature-x          # Create worktree"
    echo "  agent start feature-x        # Start Claude in new terminal"
    echo "  agent status feature-x       # Check progress"
    echo "  agent merge feature-x        # Merge when done"
    echo "  agent remove feature-x       # Clean up"
end
