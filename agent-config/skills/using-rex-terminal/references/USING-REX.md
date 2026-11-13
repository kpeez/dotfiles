# Rex commands and facts

Commands for each item in [the skill](../SKILL.md). Replace each
`<placeholder>`. Rex's own guide
(`rex skill show`) and `rex <command> --help` cover every other option.

## Find where you are

Check that `REX_BLOCK` is your pane: its process must be an ancestor of yours.

```sh
nu -c 'let pane = (rex block call -s $env.REX_SESSION -b $env.REX_BLOCK process | from json | get child.pid); let procs = (ps); mut pid = $nu.pid; mut mine = false; while $pid > 1 { if $pid == $pane { $mine = true; break }; let row = ($procs | where pid == $pid); if ($row | is-empty) { break }; $pid = ($row | get 0.ppid) }; $mine'
```

`false`, or an error that the block is not found, means the IDs are stale.

Count the blocks in your session. `1` means the session is yours.

```sh
nu -c 'rex block ls -s $env.REX_SESSION --json | from json | get blocks | length'
```

See the session's label, tabs, and layout:

```sh
rex session inspect "$REX_SESSION" --json
```

## Name what you own

```sh
rex block rename "$REX_BLOCK" "<agent> · <task>"
rex session rename "$REX_SESSION" "<agent> · <task>"
rex window rename -s "$REX_SESSION" <window> "<name>"
```

## Lay out and run work

A tab per step. `--wait` returns the exit status, and `--keep-open` keeps the
output after the command ends:

```sh
rex run -s "$REX_SESSION" --wait --keep-open --focus=false --label "<agent> · <step>" -- nu -c '<cmd>; <cmd>'
```

A split below your pane: add `--split=below -b "$REX_BLOCK" --ratio 30` to
the same command.

`rex run` prints the new block ID. Read its output, and close it when you no
longer need it:

```sh
rex capture -s "$REX_SESSION" -b <block> --trim
rex block close -s "$REX_SESSION" <block>
```

A persistent shell. Open it once, then type each command into it:

```sh
rex run -s "$REX_SESSION" --focus=false --label "<agent> · shell" -c <dir> -- nu
rex send -s "$REX_SESSION" -b <block> '<cmd>'
rex send-key -s "$REX_SESSION" -b <block> enter
```

`rex block call -s "$REX_SESSION" -b <block> process` shows the foreground
process. When it is the shell again, the command is done. Atuin records each
command's exit status. Use its MCP tool, or:

```sh
atuin search --limit 1 --format '{exit}\t{command}' '<distinctive part of the command>'
```

A long-running process. Leave out `--wait`, then wait with a bound:

```sh
rex run -s "$REX_SESSION" --keep-open --focus=false --label "<agent> · <server>" -- nu -c '<cmd>'
rex wait -s "$REX_SESSION" --for 10m <block>
```

A wait that times out does not tell you whether the command passed. Check
`process` for `last_exit`.

## Watch a pane the user hands you

Capture the pane, then run this in the background. It prints a line for each
command start, each return to the prompt, each program status change, and
the pane's close. Replace `<block>`:

```sh
nu -c 'let b = "<block>"; rex events -s $env.REX_SESSION --json | lines | each {|l| let e = ($l | from json | get payload.event); let p = $e.payload; if ($p.block_id? != $b) { return }; if $e.type == "block_closed" { print "pane closed"; exit 0 }; match $p.name? { "title_changed" => { print $"title: ($p.payload.title)" }, "pwd_changed" => { print "prompt returned" }, "program_status_changed" => { print $"status: ($p.payload.record? | to nuon)" }, "child_exited" => { print $"shell exited ($p.payload.exit_code)"; exit 0 }, _ => {} } } | ignore'
```

A `title:` line shows the command that started. `prompt returned` means it
finished: capture the pane and read the new output. Use the longest timeout
your tool allows, and start the watch again each time it ends, until the user
releases or closes the pane.

## Other hosts

```sh
rex hosts
rex -S <host> new "<agent> · <task>" --json
rex -S <host> run -s <session> --wait --keep-open --focus=false --label "<agent> · <step>" -- nu -c 'cd <dir>; <cmd>'
```

A terminal on another host starts in the home directory, so change directory
inside the command.

## Facts

- Each terminal gets the `REX_SESSION` and `REX_BLOCK` of the session that
  holds it. A process keeps the values it started with.
- A client, such as the Mac app, can watch every session. The Activity
  sidebar (cmd+.) groups program status by session, so the user can see a
  blocked agent in another session without switching to it.
- Rex has no session groups or tags. Labels and order are the only way to
  tell sessions apart.
- A server holds at most 64 sessions and 64 tabs per session.
- After a server restart, Rex restores sessions and layouts, but not the
  programs that ran in them.
- Client actions, such as `session.select`, which shows a session in the
  app, need Remote Control. It is off by default; leave the setting to the
  user.

## `/bg` and the Rex IDs

The `REX_SESSION` and `REX_BLOCK` values that a Claude Code process sees when
the conversation starts in a fresh Rex session (checked 2026-11-08):

| Case | Process | IDs it sees |
| --- | --- | --- |
| Started in the origin session | origin | origin |
| After `/bg`, attached from a new session | new, under the supervisor | an unrelated session |
| Stopped, then `claude attach` from the new session | new, under the supervisor | the same unrelated session |
| `claude --resume <id>` in the new session | new, in that terminal | the new session |

The unrelated session is the one that started the background supervisor.
`/bg` also leaves the origin session open with no blocks.
