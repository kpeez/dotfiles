# Personal defaults

Exercise abstract thinking. You are your own operator.

## Implementation ethos

Think from first principles about the intended outcome. Challenge unnecessary
code, complexity, abstractions, and weak assumptions.

Prefer deleting over simplifying, simplifying over optimizing, and optimizing
over automating.

Leave clear, proportionate implementations alone. Do not invent changes to
satisfy this ethos.

**Boy Scout rule.** Be a good steward of code and documentation. When you
meet something tangential that is wrong, such as a bug, a conflict, or stale
documentation, fix it and tell me what you fixed. A change you make includes
updating the documentation it makes obsolete. If a fix could severely break
something, stop and bring it to me instead.

## Writing

- Refer to every item by a descriptive name taken from what it is: "the
  preference-pairs dataset", not "dataset A"; "the KL-penalty sweep", not
  "experiment 2". This applies to datasets, tasks, options, phases, steps,
  experiments, and runs, in chat and in written artifacts. Translate letter
  or number labels found in sources into names rather than repeating them.
- Never coin bare letters, numbers, or Roman numerals as identifiers. When
  order or a short handle helps, pair the number with a slug, such as
  `3-kl-penalty-sweep`, and keep that exact name everywhere: chat, plans,
  notes, issues, and commits.
- On first mention in a message, give an existing stable ID (issue key, file
  path, symbol) a short description: "ABC-123 (reward-model eval harness)".
- Use ASD-STE100 Simplified Technical English as a guiding principle, not a
  strict spec: short sentences, one idea per sentence, active voice, simple
  tenses, and one word for one meaning. Keep precise technical terms when
  plainer words would lose meaning.

## CLI and scripting

- Run one-off commands and short glue in Nushell: start each with `nu -c` (or
  nu-mcp when it can reach the path), even inside a shell tool call. This
  includes external tools such as `git`, `gh`, and `rg`.
- Prefer structured data and native Nushell operations over parsing text with
  `jq`, `awk`, `sed`, `grep`, or inline Python. Check `plugin list` before
  relying on a Nushell plugin.
- Write scripts with real logic in Python. A script in a data folder lives
  there and uses only the standard library.
- Use Bash only to maintain a shell script, reproduce shell-specific behavior,
  or meet a concrete portability need, and say why.

## Rex terminals

When `REX_SESSION` is set, run work I would watch in a Rex pane: builds,
tests, installs, scripts, servers, and commands that change state. Use the
shell tool to inspect: read and search files, run git, fetch a page, and ask
a tool for its help, version, status, or config check. In a headless run,
such as `claude -p`, `codex exec`, `opencode run`, or Claude Code with
`CLAUDE_CODE_ENTRYPOINT=sdk-cli`, use the shell tool and open no panes.

- At the start of a session, label your own pane with your agent and task, so
  I can tell which session owns which pane:
  `rex block rename "$REX_BLOCK" "<agent> · <task>"`, such as
  `claude · kalin_vids mp4 conversion`.
- Open one pane for each step, not for each command. Put the commands of one
  step in one pane, beside your own pane, with
  `rex run --wait --keep-open --focus=false --split=below -b "$REX_BLOCK" --ratio 30 --label "<agent> · <step>" -- nu -c '<cmd>; <cmd>'`.
  Every pane label starts with your agent name, such as `claude · kalin full run`:
  that is how I tell a pane an agent owns from one of mine.
  Without `--split`, each step opens a new window that I cannot attribute.
  Nushell stops at the first failed command, and the pane returns its exit
  status. Do not open parallel panes for checks that can run in sequence.
- `rex run` prints the block ID. Read the output with
  `rex capture -b <block>`. Close the pane with `rex block close <block>`
  when you no longer need its output.
- For a server, a watcher, or another process that must keep running, leave
  out `--wait`. Wait on such a pane with `rex wait --for <duration> <block>`,
  not by re-capturing it on a timer.
- On another Rex host, add `-S <label>` to each `rex` command; `rex hosts`
  lists the labels. Use SSH only for a host that has no Rex server.
- Open a persistent shell pane only when state must last between commands: a
  REPL or debugger session, a shell I logged in to, or a block ID I hand you.
- A block ID I hand you is a pane I work in while you watch. Read it with
  `rex capture` first. Then, in the same turn, start a background watch on its
  events (in Claude Code, the Monitor tool), so that you see each command I
  run without being asked. Replace `<block>`:
  `nu -c 'let b = "<block>"; rex events -s $env.REX_SESSION --json | lines | each {|l| let e = ($l | from json | get payload.event); let p = $e.payload; if ($p.block_id? != $b) { return }; if $e.type == "block_closed" { print "pane closed"; exit 0 }; match $p.name? { "title_changed" => { print $"title: ($p.payload.title)" }, "pwd_changed" => { print "prompt returned" }, "program_status_changed" => { print $"status: ($p.payload.record? | to nuon)" }, "child_exited" => { print $"shell exited ($p.payload.exit_code)"; exit 0 }, _ => {} } } | ignore'`
  A `title:` line shows the command that started. `prompt returned` means it
  finished: capture the pane and act on the new output. Use the longest
  timeout. Start the watch again each time it expires, until I release the
  pane or close it. Type into the pane only when I ask, and only after you
  see a shell prompt.

## Artifacts

- `artifacts/` holds output a human would also produce and keep: training
  runs, checkpoints, predictions, eval results, and their metrics, plots, and
  launch configs. Write there only if a human would re-open, compare, or cite
  it after this task, and you can record the command, config, and git SHA
  that produced it. Give each run its own folder, such as
  `artifacts/2026-11-07-kl-sweep/`.
- Everything else goes in `.agents/scratch/<branch-slug>/` (the branch name
  with `/` replaced by `-`): probes, test and verification logs, screenshots,
  PR-body drafts, caches, and upstream clones. Never put it in `artifacts/`,
  `/tmp`, or `mktemp -d`. Keep it until the branch merges.
- `artifacts` links to `~/artifacts/<repo>` and `.agents/scratch` links to
  `~/agent-scratch/<repo>`, where `<repo>` is the main checkout's folder
  name. The llmos session-start hook makes both. When one is missing, make
  the target folder and the link, and keep the link out of Git.
- Never write run output into the llmOS vault (the `llmOS/` folder of the
  llmos checkout: `~/code/llmOS/llmOS` on the Mac, `~/Documents/llmos/llmOS`
  on the Linux workstation), and never run experiments from it. The vault
  gets the closeout note (result, decision, or review) and only the images a
  note embeds as a reference, example, or figure.
