# Fish completions for the agent binary (~/code/work/agent).

# Thread names in the current repo, read off the branches. Mirrors
# thread.NameForBranch: RENG-9216/dedup and RENG-9216-dedup both -> reng-9216.
function __agent_names
    git rev-parse --show-toplevel >/dev/null 2>&1; or return
    for branch in (git for-each-ref --format='%(refname:short)' refs/heads 2>/dev/null)
        # Questions have no branch; one under ask/ is left from when they did.
        string match -q 'ask/*' $branch; and continue
        set -l key (string match -rg '^([A-Z][A-Z0-9]*-[0-9]+)[-/]' -- $branch)
        if test -n "$key"
            string lower $key
        else
            echo $branch
        end
    end | sort -u
end

# Open questions, which is all `keep` can act on. They live in the transcripts
# rather than on disk, so the binary is the only thing that can list them.
function __agent_asks
    agent asks 2>/dev/null | string match -rg '^(ask-[0-9-]+)\s'
end

# Explorations and tickets that have a plan doc
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

complete -c agent -n __fish_use_subcommand -a ask -d "Throwaway question, in the repo you are in"
complete -c agent -n __fish_use_subcommand -a explore -d "Durable work with no ticket, backed by a plan doc"
complete -c agent -n __fish_use_subcommand -a jira -d "Ticketed work from a Jira key"
complete -c agent -n __fish_use_subcommand -a promote -d "Move an exploration into the tracked lane"
complete -c agent -n __fish_use_subcommand -a resume -d "Pick a thread to continue"
complete -c agent -n __fish_use_subcommand -a list -d "Print threads without the picker"
complete -c agent -n __fish_use_subcommand -a status -d "Working-tree status"
complete -c agent -n __fish_use_subcommand -a diff -d "A thread's branch against the default branch"
complete -c agent -n __fish_use_subcommand -a log -d "Commits on a thread's branch"
complete -c agent -n __fish_use_subcommand -a merge -d "Merge a thread's branch into the current one"
complete -c agent -n __fish_use_subcommand -a done -d "Finish a thread: doc done, sessions archived"
complete -c agent -n __fish_use_subcommand -a remove -d "Erase a thread: sessions archived, branch deleted"
complete -c agent -n __fish_use_subcommand -a asks -d "Open questions, and when they expire"
complete -c agent -n __fish_use_subcommand -a keep -d "Claim a question as an exploration"
complete -c agent -n __fish_use_subcommand -a sweep -d "Archive old questions"
complete -c agent -n __fish_use_subcommand -a sync -d "Refresh plan docs against Jira"

# Commands that name an existing thread
set -l takes_name resume list diff log merge done remove rm promote
complete -c agent -n "__fish_seen_subcommand_from $takes_name" -a "(__agent_names)"

complete -c agent -n "__fish_seen_subcommand_from keep" -a "(__agent_asks)"
complete -c agent -n "__fish_seen_subcommand_from explore" -a "(__agent_slugs)"

complete -c agent -n "__fish_seen_subcommand_from resume" -l fresh -s f -d "Start a new session instead of resuming"
complete -c agent -n "__fish_seen_subcommand_from resume" -l print -s p -d "Print the threads instead of picking"
complete -c agent -n "__fish_seen_subcommand_from resume list" -l all -s a -d "Include branches with no recent activity"
complete -c agent -n "__fish_seen_subcommand_from explore" -l title -s t -d "Plan doc title" -r
complete -c agent -n "__fish_seen_subcommand_from explore keep" -l no-start -d "Set the thread up but don't launch Claude"
complete -c agent -n "__fish_seen_subcommand_from keep" -l as -s a -d "Name the exploration" -r
complete -c agent -n "__fish_seen_subcommand_from remove rm" -l force -s f -d "Delete even the branch you are on"
complete -c agent -n "__fish_seen_subcommand_from sweep" -l days -d "Retention window in days (default 14)" -r
complete -c agent -n "__fish_seen_subcommand_from sweep" -l dry-run -s n -d "Report what would be swept"
complete -c agent -n "__fish_seen_subcommand_from sweep" -l all -d "Sweep every repo"
complete -c agent -n "__fish_seen_subcommand_from sync" -l quiet -s q -d "Only print the summary"
complete -c agent -n "__fish_seen_subcommand_from jira" -l jql -s j -d "Search instead of your open tickets" -r
