# Fish completions for the agent binary (~/code/work/agent).

# Thread names in the current repo: wt-Website-reng-9216 -> reng-9216
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

# Just the question worktrees, which is all `keep` can act on
function __agent_asks
    __agent_names | string match 'ask-*'
end

# Explorations and tickets that have a plan doc but no worktree yet
function __agent_slugs
    set -l vault $AGENT_VAULT_PROJECTS
    test -n "$vault"; or set vault ~/notes/splash/projects
    test -d $vault; or return
    for f in $vault/*.md
        # Finished work is not worth offering as something to open.
        # `status` is reserved in fish; this is the doc's own field.
        set -l doc_status (string match -rg '^status: (.+)$' <$f)
        contains -- "$doc_status" done dropped; and continue
        # Docs created by `agent explore` carry a slug; migrated ones derive
        # theirs from the filename, the same way the binary does.
        set -l slug (string match -rg '^slug: (.+)$' <$f)
        if test -z "$slug"
            set slug (basename $f .md | string lower | string replace -ra '[^a-z0-9]+' - | string trim -c -)
        end
        echo $slug
    end
end

complete -c agent -f

complete -c agent -n __fish_use_subcommand -a ask -d "Throwaway question in a worktree of its own"
complete -c agent -n __fish_use_subcommand -a explore -d "Durable work with no ticket, backed by a plan doc"
complete -c agent -n __fish_use_subcommand -a jira -d "Ticketed work from a Jira key"
complete -c agent -n __fish_use_subcommand -a promote -d "Move an exploration into the tracked lane"
complete -c agent -n __fish_use_subcommand -a resume -d "Pick a thread to continue"
complete -c agent -n __fish_use_subcommand -a list -d "Print threads without the picker"
complete -c agent -n __fish_use_subcommand -a path -d "Print a worktree's path"
complete -c agent -n __fish_use_subcommand -a shell -d "Open a subshell in a worktree"
complete -c agent -n __fish_use_subcommand -a status -d "git status in a worktree"
complete -c agent -n __fish_use_subcommand -a diff -d "git diff in a worktree"
complete -c agent -n __fish_use_subcommand -a log -d "Commits on a thread's branch"
complete -c agent -n __fish_use_subcommand -a merge -d "Merge a thread's branch into the current one"
complete -c agent -n __fish_use_subcommand -a done -d "Finish a thread and remove its worktree"
complete -c agent -n __fish_use_subcommand -a remove -d "Remove a worktree"
complete -c agent -n __fish_use_subcommand -a asks -d "Open questions, and when they expire"
complete -c agent -n __fish_use_subcommand -a keep -d "Claim a question as an exploration"
complete -c agent -n __fish_use_subcommand -a sweep -d "Expire old questions"
complete -c agent -n __fish_use_subcommand -a sync -d "Refresh plan docs against Jira"

# Commands that name an existing thread
set -l takes_name resume list path shell status diff log merge done remove rm promote
complete -c agent -n "__fish_seen_subcommand_from $takes_name" -a "(__agent_names)"

complete -c agent -n "__fish_seen_subcommand_from keep" -a "(__agent_asks)"
complete -c agent -n "__fish_seen_subcommand_from explore" -a "(__agent_slugs)"

complete -c agent -n "__fish_seen_subcommand_from resume" -l fresh -s f -d "Start a new session instead of resuming"
complete -c agent -n "__fish_seen_subcommand_from resume" -l print -s p -d "Print the threads instead of picking"
complete -c agent -n "__fish_seen_subcommand_from explore" -l title -s t -d "Plan doc title" -r
complete -c agent -n "__fish_seen_subcommand_from explore keep" -l no-start -d "Set up the worktree but don't launch Claude"
complete -c agent -n "__fish_seen_subcommand_from keep" -l as -s a -d "Name the exploration" -r
complete -c agent -n "__fish_seen_subcommand_from done" -l force -s f -d "Proceed despite uncommitted changes"
complete -c agent -n "__fish_seen_subcommand_from remove rm" -l force -s f -d "Discard changes and delete the branch"
complete -c agent -n "__fish_seen_subcommand_from sweep" -l days -d "Retention window in days (default 14)" -r
complete -c agent -n "__fish_seen_subcommand_from sweep" -l dry-run -s n -d "Report what would be swept"
complete -c agent -n "__fish_seen_subcommand_from sweep" -l all -d "Sweep every repo"
complete -c agent -n "__fish_seen_subcommand_from sweep" -l force -s f -d "Include questions with uncommitted changes"
complete -c agent -n "__fish_seen_subcommand_from sync" -l quiet -s q -d "Only print the summary"
complete -c agent -n "__fish_seen_subcommand_from jira" -l jql -s j -d "Search instead of your open tickets" -r
