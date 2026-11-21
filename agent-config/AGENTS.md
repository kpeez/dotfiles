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

- Run an external command as itself (`git status`, `gh pr view 12`,
  `uv run pytest`). Never wrap it in another shell.
- Do not chain `awk`, `sed`, `cut`, or `grep` stages to reshape output. When
  output needs more than one filter, use one `nu -c` pipeline of at most
  three stages, or a Python script.
- Write scripts with real logic in Python. A script in a data folder lives
  there and uses only the standard library.
- Make a one-off Python script a PEP 723 script: `uv init --script x.py`,
  add packages with `uv add --script x.py <pkg>`, and run it with
  `uv run x.py`. Never run bare `python` or `pip install`.
- Write Bash only to maintain a shell script, run a script that a skill
  provides, reproduce shell-specific behavior, or meet a concrete portability
  need, and say why.
- To learn how a command ran before, or why it failed, search atuin history
  (its MCP tools, or `atuin search --search-mode fulltext`) before you guess
  or run it again. Atuin records each command with its exit code, and its
  output where capture is on.
- Atuin keeps no terminal output for a command that an agent ran. Read that
  output in the agent's thread: `atuin_threads_search`, then
  `atuin_threads_read`. Do this before you grep `~/.claude/projects` or
  `~/.codex/sessions`.
- Manage Git worktrees with worktrunk: `wt switch --create <branch>`,
  `wt list`, and `wt remove`. Do not run `git worktree` directly.

## Rex terminals

When `REX_SESSION` is set, read the `using-rex` skill before you start a
command that may run for minutes, or before you open, watch, or arrange a
pane. In a headless run, such as `claude -p` or `codex exec`, open no panes.

## Artifacts

- `artifacts/` holds output a human would also produce and keep: training
  runs, checkpoints, predictions, eval results, and their metrics, plots, and
  launch configs. Write there only if a human would re-open, compare, or cite
  it after this task, and you can record the command, config, and git SHA
  that produced it. Give each run its own folder, such as
  `artifacts/2026-11-07-kl-sweep/`.
- In a repository, everything else goes in `.agents/scratch/<branch-slug>/`
  (the branch name with `/` replaced by `-`): probes, test and verification
  logs, screenshots, PR-body drafts, caches, and upstream clones. Never put
  it in `artifacts/`, `/tmp`, or `mktemp -d`. Keep it until the branch merges.
  Outside a repository, use the scratch folder that the agent harness gives you.
- `artifacts` links to `~/artifacts/<repo>` and `.agents/scratch` links to
  `~/agent-scratch/<repo>`, where `<repo>` is the main checkout's folder
  name. The llmos session-start hook makes both. When one is missing, make
  the target folder and the link, and keep the link out of Git.
- Never write run output into the llmOS vault (the `llmos-vault` checkout,
  `~/code/llmOS`), and never run experiments from it.
  The vault gets the closeout note (result, decision, or review), the HTML
  plans of a project in its `plans/` folder (`.agents/docs/plans/`), and only
  the images a note embeds as a reference, example, or figure.
