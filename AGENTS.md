# Dotfiles repository

mise links and installs this config on a Mac and on Linux hosts. The README
covers daily use, and `docs/reference.md` explains how the setup works.

## Public repository

This repository is public. Never name a specific host or machine anywhere in
it: not in files, comments, commit messages, pull requests, or issues. Name
the host's role instead, such as "the Linux workstation" or "a cluster host
without root". Put host-specific setup in the private overlay (`private/`, a
separate repository that Git ignores here).

**New setups start in the private overlay.** A new script, tool, config, or
agent setup goes in `private/` first, even when it holds no host name. Move it
here only when the user says so. A move from private to public is easy, but a
move from public to private cannot remove what GitHub already shows: every
pull request stays visible, and the owner cannot delete one. Agent settings,
permissions, hooks, plugin lists, and the agents' instruction file always
stay private. The mistake this rule stops: an agent added a personal script
here because it "held no host name", and the public history then showed it.

## Edits

- Files under `home/`, `macos/`, and `linux/` are linked into `~`. An edit
  to `~/.config/...` is an edit to this repository.
- `private/agent-config/AGENTS.md` is the user's global instruction file for
  every coding agent on every host. It lives in the private overlay. Change it
  only when the user asks.
- A change reaches other hosts only after a push to `main` and
  `mise run sync <host>...`.
- When a change makes `README.md` or `docs/reference.md` wrong, update them
  in the same change.
- When you add a workaround for a tool's bug or limit, and a person can check
  when it ends, add an entry to `docs/workarounds.toml`. When you remove a
  workaround, delete its entry.

## mise

- Run project commands inside `~/.dotfiles`. `mise -C ~/.dotfiles` loads
  `mise.toml` but skips `mise.macos.toml` and the private env files.
- Put `[tools]` in `home/.config/mise/config.toml` or a fragment linked into
  `~/.config/mise/conf.d/*.toml`. Never put `[tools]` in `mise*.toml` or
  `private/mise.*.toml`, because project configs activate only inside
  `~/.dotfiles`.
- Check a change with `mise bootstrap --dry-run --skip-dirty` and
  `mise doctor project`.
- Run `mise bootstrap packages prune` with `--dry-run` first. It keeps every
  package that any trusted config declares, including old worktrees under
  `.claude/worktrees/`.
- Deleting a file from `home/` does not delete its link. Run
  `mise bootstrap --only dotfiles --prune-dotfiles`.
