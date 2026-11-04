# Change your config and roll it out

This page is for the day after setup: you changed something, and you want
every machine to have it.

## The two rules

```text
You changed a config, on any machine:
    git commit, git push               (to main)
    mise run sync <host>...            (on the Mac, in ~/.dotfiles)

You want newer versions:
    mise run update                    (on each machine you want upgraded)
```

`sync` makes each host pull `main` and run `mise bootstrap`. Each host then
applies only the files and packages meant for it, so you never choose what
goes where.

## Why a push is needed

Each machine has its own clone at `~/.dotfiles`, and your config files are
links into it. An edit is live at once on the machine where you make it. Other
machines get it only when they pull `main`, which `sync` does for them.

When you pushed from another machine, run `git pull` on the Mac too, before
you run `sync`.

## Which machines a file reaches

| You edit | It reaches |
| --- | --- |
| `home/` (git, Nu, Fish, tmux, and other configs) | Every machine |
| `home/.config/mise/config.toml` (the `[tools]` list) | Every machine |
| `mise.toml` | Every machine |
| `macos/`, `mise.macos.toml` (Homebrew, macOS settings) | Macs only |
| `linux/`, `mise.linux.toml` (apt packages) | Linux machines only |
| `private/mise.<host>.toml`, `private/<host>/` | That host only |

A change that reaches only the Mac needs no `sync`. If it added a package or a
setting, apply it on the Mac:

```sh
mise bootstrap --skip-dirty
```

Plain `mise bootstrap` stops at a repo it manages that has local changes,
such as a clone listed under `[bootstrap.repos]`. `--skip-dirty` skips that
repo and applies the rest, as `sync` does on each host.

## The two exceptions

- **A new apt package on a host whose sudo asks for a password.** SSH cannot
  answer the prompt, so `sync` cannot install it. Run
  `mise bootstrap --skip-dirty` in a terminal on that host, or over
  `ssh -t <host>`.
- **A host refuses the pull.** `sync` uses `git pull --ff-only`, which stops
  when that host's clone has its own commits or edits. On that host, commit
  and push them, or discard them, then run `sync` again.

The full description of `sync` and `update` is in [mise](mise.md#tasks).
