---
name: jira
description: >
  Fetch Jira issue context. Use when the user says /jira, asks about a ticket,
  or you need to understand requirements for the current work. Accepts an optional
  issue key; if omitted, infers from the current git branch name.
argument-hint: "[ISSUE-KEY]"
allowed-tools: "Bash(jira *),Bash(git symbolic-ref *),Bash(git rev-parse *),Bash(jira-adf-extract*),Bash(jira-parent*),Bash(jira-links*)"
---

# Jira Issue Context

Pull down read-only context for a Jira issue.

## Resolving the issue key

1. If the user provided an argument (e.g. `/jira RATE-8670`), use that as the issue key.
2. Otherwise, detect it from the current git branch:
   ```bash
   git symbolic-ref --short HEAD 2>/dev/null
   ```
   Branch names follow the pattern `PROJ-1234-optional-slug` or just `proj-1234`.
   Extract the ticket key by uppercasing and taking the first two hyphen-delimited
   segments: e.g. `rate-8670-write-down-the-percentage` -> `RATE-8670`.
3. If neither yields a key, ask the user.

## Fetching context

Run all of these in parallel where possible:

### 1. Issue details (plain view with comments)

```bash
jira issue view <KEY> --plain --comments 5
```

### 2. Acceptance criteria

```bash
jira issue view <KEY> --raw | jira-adf-extract
```

Uses `customfield_10080` by default. Pass `--field description` to extract the
description instead.

### 3. Parent epic

```bash
jira issue view <KEY> --raw | jira-parent
```

### 4. Linked issues

```bash
jira issue view <KEY> --raw | jira-links
```

## Presenting results

Format the output as a concise summary:

```
## <KEY>: <Summary>

**Status:** <status> | **Priority:** <priority> | **Assignee:** <assignee>
**Epic:** <parent epic key and summary, or "none">

### Description
<description text from plain view>

### Acceptance Criteria
<converted markdown from step 2>

### Linked Issues
<list from step 4, or "none">

### Recent Comments
<comments from plain view, if any>
```

Keep it scannable. This is context for working on the ticket, not a report.
