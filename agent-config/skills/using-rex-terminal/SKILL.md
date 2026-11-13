---
name: using-rex-terminal
description: "How agents work in the Rex terminal: check where you are, name what you own, lay out and run work in sessions, tabs, and panes, watch a pane the user hands you, work on other hosts, and avoid known traps. Use when REX_SESSION is set and you run, watch, or arrange terminal work, or when the user mentions Rex sessions, tabs, or panes."
---

# Using the Rex terminal

Rex's own `rex` skill teaches the CLI; run `rex skill show` for its guide.
This skill covers how we work in Rex. It lists options, not one procedure:
choose what fits the task. The [reference](references/USING-REX.md) has the
commands for each item.

## When it applies

Rex is in play when `REX_SESSION` is set. In a headless run, such as
`claude -p`, `codex exec`, `opencode run`, or Claude Code with
`CLAUDE_CODE_ENTRYPOINT=sdk-cli`, use your shell tool and open no panes.

Run work the user would watch in a Rex pane: builds, tests, installs, long
scripts, servers, and commands that change state. Inspect with your shell
tool: read and search files, run git, and ask a tool for its help, version,
or status.

## Find where you are

- `REX_SESSION` and `REX_BLOCK` come from the terminal that started your
  process, and they can be stale. Before you open a pane, check that
  `REX_BLOCK` exists and that its process is an ancestor of yours. When it is
  not, tell the user instead of guessing a target.
- The session is yours when your pane is its only block, for example when
  the user opened a fresh session and started you there. Otherwise you share
  it, as in the user's command-center session.

## Name what you own

- A label that starts with your agent name marks an item an agent owns, such
  as `claude · kalin full run`. Give each pane, tab, or session you create
  such a label, and label your own pane with your agent and task.
- In a session that is yours, you can rename the session to
  `<agent> · <task>` once you know the task, and rename tabs after their
  work. In a shared session, rename only your own pane and items you created.

## Lay out and run work

Each layout has a cost. Mix them as the task needs.

- **A tab per step.** `rex run --wait --keep-open` without `--split` returns
  the exit status, and the output stays readable. Tabs accumulate, which suits
  a session that is yours.
- **A split beside your pane.** `--split=below -b "$REX_BLOCK"` keeps the work
  next to you. It suits a shared session and live output the user watches
  beside you.
- **A persistent shell.** It keeps state between commands: the directory,
  environment, a REPL or debugger, or a shell the user logged in to. Rex
  reports no exit status for each command in a shell. Read it from atuin
  history or from the output.
- **A long-running process**, such as a server, watcher, or training run.
  Leave out `--wait`, and check it with `rex wait --for`, not by capturing on
  a timer.

Run a single command in a pane as itself. Put several commands of one step in
one `nu -c` call, so the step stops at the first failure. Close what you no
longer need. When the session is yours, you can
leave finished tabs for the user, who closes the session when the work ends.
Close or kill a session only when the user asks.

## Watch a pane the user hands you

A block ID the user hands you is a pane they work in while you watch.
Capture it first, then watch its events in the background, so you see each
command they run. Type into it only when they ask, and only at a shell
prompt.

## Other hosts

Add `-S <host>` to each `rex` command; `rex hosts` lists the labels. Your
`REX_*` IDs do not apply there, so pick or create a labelled session on that
host. Use SSH only for a host with no Rex server.

## Agent-specific tools

- A background watch tool, such as Claude Code's Monitor or
  `run_in_background`, fits `rex events` and long `rex wait` calls.
- To start or drive another Claude Code session in a pane, use the
  `rex-claude` skill.

## Traps

- Claude Code's `/bg` moves the conversation to a new process that inherits
  the environment of the background supervisor. Its `REX_*` IDs then point at
  an unrelated session, and its panes land there. To move a conversation to
  another Rex session, run `claude --resume <id>` in that session.
- A block ID copied from earlier in the conversation can name a pane that is
  gone. Read the current state before you target it.
