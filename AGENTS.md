# Dotfiles repository

mise links and installs this config on a Mac and on Linux hosts. The README
covers daily use, and `docs/reference.md` explains how the setup works.

## Public repository

This repository is public. Never name a specific host or machine anywhere in
it: not in files, comments, commit messages, pull requests, or issues. Name
the host's role instead, such as "the Linux workstation" or "a cluster host
without root". Put host-specific setup in the private overlay (`private/`, a
separate repository that Git ignores here).

## Edits

- Files under `home/`, `macos/`, and `linux/` are linked into `~`. An edit
  to `~/.config/...` is an edit to this repository.
- `agent-config/AGENTS.md` is the user's global instruction file for every
  coding agent on every host. Change it only when the user asks.
- A change reaches other hosts only after a push to `main` and
  `mise run sync <host>...`.
- When a change makes `README.md` or `docs/reference.md` wrong, update them
  in the same change.

## mise

- Run project commands inside `~/.dotfiles`. `mise -C ~/.dotfiles` loads
  `mise.toml` but skips `mise.macos.toml` and the private env files.
- Check a change with `mise bootstrap --dry-run --skip-dirty` and
  `mise doctor project`.
- Run `mise bootstrap packages prune` with `--dry-run` first. It keeps every
  package that any trusted config declares, including old worktrees under
  `.claude/worktrees/`.
- Deleting a file from `home/` does not delete its link. Run
  `mise bootstrap --only dotfiles --prune-dotfiles`.
