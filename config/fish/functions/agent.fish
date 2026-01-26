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
    set -l repo_parent (dirname $repo_root)

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

            set -l worktree_dir "wt-$name"
            set -l worktree_path "$repo_parent/$worktree_dir"

            echo "Creating agent worktree '$name' from '$base_branch'..."

            git worktree add -b $name $worktree_path $base_branch
            or begin
                echo "Error: Failed to create worktree"
                return 1
            end

            # Copy and augment CLAUDE.md if it exists
            if test -f "$repo_root/CLAUDE.md"
                set -l worktree_context "# Worktree Context

You are working in an agent worktree at:
  $worktree_path

This worktree directory should be used for ALL work, including exploratory work,
scratch files, and any other files you need to create. Do not modify files
outside this directory.

---

"
                echo -n $worktree_context >"$worktree_path/CLAUDE.md"
                cat "$repo_root/CLAUDE.md" >>"$worktree_path/CLAUDE.md"
                echo "Copied CLAUDE.md with worktree context"
            end

            # Symlink .claude directory if it exists in repo but not in worktree
            if test -d "$repo_root/.claude" -a ! -e "$worktree_path/.claude"
                ln -s "$repo_root/.claude" "$worktree_path/.claude"
                echo "Symlinked .claude directory"
            end

            echo ""
            echo "Agent worktree created:"
            echo "  Path:   $worktree_path"
            echo "  Branch: $name"
            echo ""
            echo "To start working:"
            echo "  cd $worktree_path && claude"
            echo ""
            echo "Or use: agent start $name"

        case list ls
            echo "Agent worktrees for $repo_name:"
            echo ""

            set -l found 0
            for line in (git worktree list --porcelain)
                if string match -q "worktree *" $line
                    set -l worktree_path (string replace "worktree " "" $line)
                    # Skip the main worktree
                    if test "$worktree_path" = "$repo_root"
                        continue
                    end
                    # Only show worktrees in sister directories with wt- prefix
                    set -l dir_name (basename $worktree_path)
                    if not string match -q "wt-*" $dir_name
                        continue
                    end

                    set found (math $found + 1)
                    set -l branch (git -C $worktree_path branch --show-current 2>/dev/null)
                    set -l name (string replace "wt-" "" $dir_name)
                    set -l status_info ""

                    set -l changes (git -C $worktree_path status --porcelain 2>/dev/null)
                    if test -n "$changes"
                        set status_info " (has changes)"
                    end

                    printf "  %-20s %s%s\n" $name $branch $status_info
                end
            end

            if test $found -eq 0
                echo "  (none)"
            end
            echo ""

        case cd path
            set -l name $args[1]
            set -l worktree_path (_agent_require_worktree $repo_parent $name "cd (agent cd <name>)")
            or return 1

            echo $worktree_path

        case start
            set -l name $args[1]
            set -l worktree_path (_agent_require_worktree $repo_parent $name "agent start <name>")
            or return 1

            echo "Starting Claude in agent worktree '$name'..."
            cd $worktree_path && claude

        case remove rm delete
            argparse --name="agent remove" f/force -- $args
            or return 1

            set -l name $argv[1]
            set -l worktree_path (_agent_require_worktree $repo_parent $name "agent remove <name> [--force]")
            or return 1

            # Check for uncommitted changes
            set -l changes (git -C $worktree_path status --porcelain 2>/dev/null)
            if test -n "$changes"
                if not set -q _flag_force
                    echo "Warning: Worktree has uncommitted changes!"
                    read -P "Continue anyway? [y/N] " confirm
                    if not string match -qi y -- $confirm
                        echo Aborted
                        return 1
                    end
                end
            end

            echo "Removing agent worktree '$name'..."
            if set -q _flag_force
                git worktree remove $worktree_path --force
            else
                git worktree remove $worktree_path
                or begin
                    echo "Hint: Use --force to remove worktrees with uncommitted changes"
                    return 1
                end
            end

            if set -q _flag_force
                echo "Deleting branch '$name'..."
                git branch -D $name 2>/dev/null
            else
                echo "Branch '$name' preserved. Delete with: git branch -D $name"
            end

            echo "Done."

        case status
            set -l name $args[1]
            set -l worktree_path (_agent_require_worktree $repo_parent $name "agent status <name>")
            or return 1

            echo "Status for agent '$name':"
            git -C $worktree_path status

        case diff
            set -l name $args[1]
            set -l worktree_path (_agent_require_worktree $repo_parent $name "agent diff <name>")
            or return 1

            git -C $worktree_path diff

        case log
            set -l name $args[1]
            set -l worktree_path (_agent_require_worktree $repo_parent $name "agent log <name>")
            or return 1

            echo "Commits for agent '$name':"
            set -l default_branch (_agent_default_branch)
            git -C $worktree_path log --oneline $default_branch..HEAD 2>/dev/null
            or git -C $worktree_path log --oneline -10

        case merge
            set -l name $args[1]
            set -l worktree_path (_agent_require_worktree $repo_parent $name "agent merge <name>")
            or return 1

            echo "Merging '$name' into current branch..."
            git merge $name

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
function _agent_require_worktree --argument-names repo_parent name usage
    if test -z "$name"
        echo "Usage: $usage"
        return 1
    end

    set -l worktree_path "$repo_parent/wt-$name"
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
    echo "  new <name> [-c] [base]  Create a new agent worktree"
    echo "                         -c: base off current branch (default: main/master)"
    echo "                         base: explicit base branch"
    echo "  list                   List all agent worktrees"
    echo "  start <name>           Start Claude in an agent worktree"
    echo "  cd <name>              Print path (use: cd (agent cd name))"
    echo "  status <name>          Show git status for agent"
    echo "  diff <name>            Show diff for agent"
    echo "  log <name>             Show commits for agent"
    echo "  merge <name>           Merge agent branch into current branch"
    echo "  remove <name> [-f]     Remove an agent worktree (-f: also delete branch)"
    echo ""
    echo "Example workflow:"
    echo "  agent new feature-x          # Create worktree"
    echo "  agent start feature-x        # Start Claude in worktree"
    echo "  agent status feature-x       # Check progress"
    echo "  agent merge feature-x        # Merge when done"
    echo "  agent remove -f feature-x    # Clean up worktree and branch"
end
