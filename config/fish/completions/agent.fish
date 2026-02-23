# Fish completion for agent function

# Helper function to get existing agent worktree names
function __agent_names
    for line in (git worktree list --porcelain 2>/dev/null)
        if string match -q "worktree *" $line
            set -l dir_name (basename (string replace "worktree " "" $line))
            if string match -q "wt-*" $dir_name
                string replace "wt-" "" $dir_name
            end
        end
    end
end

# Subcommands
set -l commands new create list ls start cd path status diff log merge remove rm delete

# Don't complete files
complete -c agent -f

# Complete subcommands when no subcommand given yet
complete -c agent -n "not __fish_seen_subcommand_from $commands" -a "new" -d "Create a new agent worktree"
complete -c agent -n "not __fish_seen_subcommand_from $commands" -a "list" -d "List all agent worktrees"
complete -c agent -n "not __fish_seen_subcommand_from $commands" -a "start" -d "Start Claude in an agent worktree"
complete -c agent -n "not __fish_seen_subcommand_from $commands" -a "cd" -d "Print path to agent worktree"
complete -c agent -n "not __fish_seen_subcommand_from $commands" -a "status" -d "Show git status for agent"
complete -c agent -n "not __fish_seen_subcommand_from $commands" -a "diff" -d "Show diff for agent"
complete -c agent -n "not __fish_seen_subcommand_from $commands" -a "log" -d "Show commits for agent"
complete -c agent -n "not __fish_seen_subcommand_from $commands" -a "merge" -d "Merge agent branch into current branch"
complete -c agent -n "not __fish_seen_subcommand_from $commands" -a "remove" -d "Remove an agent worktree"

# Complete agent names for subcommands that need them
complete -c agent -n "__fish_seen_subcommand_from start cd path status diff log merge remove rm delete" -a "(__agent_names)" -d "Agent worktree"

# Options for 'new' subcommand
complete -c agent -n "__fish_seen_subcommand_from new create" -s c -l current -d "Base off current branch"

# Options for 'remove' subcommand
complete -c agent -n "__fish_seen_subcommand_from remove rm delete" -s f -l force -d "Also delete the branch"
