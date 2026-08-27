# Fish completions for the agent binary (~/code/work/agent).

# Names of this repo's agent worktrees, e.g. wt-Website-reng-9216 -> reng-9216
function __agent_names
    set -l repo (basename (git rev-parse --show-toplevel 2>/dev/null))
    test -n "$repo"; or return
    for line in (git worktree list --porcelain 2>/dev/null)
        if string match -q "worktree *" $line
            set -l dir (basename (string replace "worktree " "" $line))
            string replace -r "^wt-$repo-" "" -- $dir | string match -v $dir
        end
    end
end

# Explorations and tickets that have a plan doc but no worktree yet
function __agent_slugs
    set -l vault $AGENT_VAULT_PROJECTS
    test -n "$vault"; or set vault ~/notes/splash/projects
    test -d $vault; or return
    for f in $vault/*.md
        set -l slug (string match -rg '^slug: (.+)$' <$f | head -1)
        test -n "$slug"; and echo $slug
    end
end

complete -c agent -f

set -l lanes ask explore jira promote
set -l threads list resume start path shell status diff log merge done remove rm
set -l maint sweep sync help

complete -c agent -n __fish_use_subcommand -a ask -d "Throwaway question in the shared scratch worktree"
complete -c agent -n __fish_use_subcommand -a explore -d "Durable work with no ticket, backed by a plan doc"
complete -c agent -n __fish_use_subcommand -a jira -d "Ticketed work from a Jira key"
complete -c agent -n __fish_use_subcommand -a promote -d "Move an exploration into the tracked lane"
complete -c agent -n __fish_use_subcommand -a list -d "Worktrees with plan status and last session"
complete -c agent -n __fish_use_subcommand -a resume -d "Continue a thread's most recent session"
complete -c agent -n __fish_use_subcommand -a path -d "Print a worktree's path"
complete -c agent -n __fish_use_subcommand -a shell -d "Open a subshell in a worktree"
complete -c agent -n __fish_use_subcommand -a status -d "git status in a worktree"
complete -c agent -n __fish_use_subcommand -a diff -d "git diff in a worktree"
complete -c agent -n __fish_use_subcommand -a log -d "Commits on a thread's branch"
complete -c agent -n __fish_use_subcommand -a merge -d "Merge a thread's branch into the current one"
complete -c agent -n __fish_use_subcommand -a done -d "Finish a thread and remove its worktree"
complete -c agent -n __fish_use_subcommand -a remove -d "Remove a worktree"
complete -c agent -n __fish_use_subcommand -a sweep -d "Archive old scratch sessions"
complete -c agent -n __fish_use_subcommand -a sync -d "Refresh plan docs against Jira"

# Commands that take an existing worktree name
complete -c agent -n "__fish_seen_subcommand_from $threads" -a "(__agent_names)"

# promote takes an exploration slug, then a ticket key
complete -c agent -n "__fish_seen_subcommand_from promote" -a "(__agent_names)"

# explore offers slugs that already have a plan doc
complete -c agent -n "__fish_seen_subcommand_from explore" -a "(__agent_slugs)"

complete -c agent -n "__fish_seen_subcommand_from resume" -l fresh -d "Start a new session instead of resuming"
complete -c agent -n "__fish_seen_subcommand_from explore" -l title -d "Plan doc title" -r
complete -c agent -n "__fish_seen_subcommand_from explore" -l no-start -d "Create the worktree but don't launch Claude"
complete -c agent -n "__fish_seen_subcommand_from done remove rm" -l force -d "Discard uncommitted changes"
complete -c agent -n "__fish_seen_subcommand_from remove rm" -l force -d "Also delete the branch"
complete -c agent -n "__fish_seen_subcommand_from sweep" -l days -d "Retention window in days (default 30)" -r
complete -c agent -n "__fish_seen_subcommand_from sweep" -l dry-run -d "Report what would be archived"
complete -c agent -n "__fish_seen_subcommand_from sync" -l quiet -d "Only print the summary"
