# .dotfiles

My config for macOS and Linux: Nushell, Fish, Neovim, Ghostty, tmux, and the
settings for Claude Code, Codex, and OpenCode. [mise](https://mise.jdx.dev)
installs all of it and links it into place. There is no Brewfile, symlink
manager, or install script: if something is on the machine, a `mise*.toml`
file declares it.

## Install

```sh
curl https://mise.run | sh
git clone https://github.com/kpeez/dotfiles.git ~/.dotfiles
cd ~/.dotfiles
~/.local/bin/mise trust --all
~/.local/bin/mise bootstrap --dry-run
~/.local/bin/mise bootstrap
```

- Run it in a real terminal. It asks for your password to change the login
  shell and, on macOS, to create `/opt/homebrew`. A new Mac needs nothing
  else first; on Linux, install Git, curl, Fish, and Nu from the package
  manager.
- On a server whose umask is not `022`, run `umask 022` first, or new folders
  such as `~/.local` become group-writable.
- Then sign in by hand: `gh auth login` and `atuin login`. Run
  `git lfs pull` in `~/code/agent-toolbox`, which bootstrap cloned before Git
  LFS was installed.

## How it works

Every file under `home/` is a link at the same path under `~`. Editing
`~/.config/nvim/init.lua` edits this repo, and `git diff` shows the change.
To track a new file, move it into `home/` and run `mise dot apply`.
`macos/` and `linux/` work the same way for one OS, and mise loads
`mise.macos.toml` or `mise.linux.toml` to match the host. Per-host setup that
must stay private lives in a separate repo, the
[private overlay](docs/reference.md#private-overlay).

Fish is the login shell and hands off to Nushell in a terminal. Scripts and
SSH commands stay in Fish. All coding agents read one instructions file,
`agent-config/AGENTS.md`, and `agent-config/skills.json` lists the skills
every host installs.

## Daily use

1. **You changed a config.** Commit and push it to `main`. Then, on the Mac
   in `~/.dotfiles`, run `mise run sync <host>...`. Each host pulls `main`
   and applies what it needs.
2. **You want newer versions.** Run `mise update` in a terminal on that
   machine. It upgrades Homebrew formulae on macOS or every apt package on
   Linux, then mise, the CLI tools, and plugins. Apps update themselves.

| Task | Command (in `~/.dotfiles`) |
| --- | --- |
| Apply config on this machine | `mise bootstrap --skip-dirty` |
| Preview and apply only the links | `mise dot diff`, then `mise dot apply` |
| Check this machine | `mise doctor project` |
| Add a CLI tool | `mise use -g <tool>@<version>` |
| Add a Homebrew formula | `mise bootstrap packages use -e macos brew:<formula>` |
| Stop tracking a file | Delete it from `home/`, then `mise bootstrap --only dotfiles --prune-dotfiles` |

[Reference](docs/reference.md) covers the config files, bootstrap, packages,
shells, agents, history, and debugging.
