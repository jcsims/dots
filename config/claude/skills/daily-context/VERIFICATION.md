# Manual verification checklist for /daily-context

Run these after changing the skill (there is no automated test for MCP flows):

1. In a fresh Claude Code session, run `/daily-context`.
2. Confirm four subagents dispatch in parallel (Slack on sonnet, rest on haiku).
3. Open today's `~/org-roam/daily/YYYY-MM-DD.org`:
   - Entries appear under `* Slack` / `* Jira` / `* Confluence` / `* Docs`.
   - Headings are valid org links; summaries are 1–2 factual lines.
   - Nothing edited outside those sections; Tasks section untouched.
4. Run `/daily-context` again immediately: the summary should report
   duplicates skipped, and the file should gain no repeated entries.
5. Check the run summary reports any degraded vertical (e.g. saved-for-later)
   instead of failing.
