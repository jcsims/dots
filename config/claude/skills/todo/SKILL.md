---
name: todo
description: Read and maintain the user's personal todo list (~/todo.md) from the CLI. Use when asked to add, edit, annotate, categorize, complete, or pick up tasks — e.g. "add a todo", "what's next", "pick up the next <category> task", "add context to <task>".
---

# todo — personal task list

The list lives at `~/todo.md` (override with `$TODO_FILE`) and has three
sections: `## Doing`, `# Todo` (backlog), `## Archive`. Each task is a line:

```
- [ ] <text> @<tag> (<id>)
  <indented context line>
```

- `(id)` is a stable 3-char id. Address tasks by id for everything below.
- `@tag` is a single free-form category (a repo name, `admin`, `oncall`, …).
- Indented lines beneath a task are its context (notes, URLs).

## Commands

Run `todo --help` for the authoritative usage. In short:

- `todo add <text> [@tag]` — add a backlog task.
- `todo edit <id> <text>` — replace a task's text (a trailing `@tag` updates the tag).
- `todo note <id> <text>` — append a context line to a task.
- `todo tag <id> <tag|->` — set or clear (`-`) a task's tag.
- `todo show <id>` — print a task and its context.
- `doing` / `doing <id>` / `doing <text>` — promote the top backlog task, promote a specific task, or add an interruption.
- `done` / `done <id>` — complete the current/next task, or a specific one.
- `next [n] [@tag]` — show Doing plus the next n backlog tasks; filter by `@tag`.
- `archive` — move completed tasks to Archive.

## Picking up work by category

To act on the next task in a category, run `next 5 @<tag>` to list candidates,
then read one with `todo show <id>`, add findings with `todo note <id> …`, and
start it with `doing <id>`. Always run `todo show <id>` before editing so you
preserve the existing text, tag, and context.
