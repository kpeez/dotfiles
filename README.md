# .dotfiles

My config for macOS and Linux: Nushell, Fish, Neovim, Ghostty, tmux, and the
settings for Claude Code, Codex, and OpenCode. [mise](https://mise.jdx.dev)
installs all of it and links it into place.

## Install

```sh
curl https://mise.run | sh
git clone https://github.com/kpeez/dotfiles.git ~/.dotfiles
cd ~/.dotfiles
~/.local/bin/mise trust --all
~/.local/bin/mise bootstrap --dry-run
~/.local/bin/mise bootstrap
```

Run it in a terminal. `mise bootstrap` asks for your password to change the
login shell, and on macOS to create `/opt/homebrew`. The
[setup guide](docs/setup.md) covers each OS.

## Why it is set up this way

I want one command that takes a new machine to a working setup, and that I
can run again on an old machine without breaking anything. mise already
managed my CLI tools, and its `bootstrap` command also handles symlinks,
Homebrew packages, macOS defaults, and launchd and systemd services. So there
is no Brewfile, no symlink manager, and no install script. If something is on
the machine, a `mise*.toml` file declares it.

Every file under `home/` is a symlink at the same path under `~`. When I edit
`~/.config/nvim/init.lua`, I edit this repo, and `git diff` shows what
changed. To track a new file, I move it into `home/` and run `mise dot apply`.
There is no list of files to keep up to date. `macos/` and `linux/` work the
same way for files that only one OS needs, and mise loads `mise.macos.toml`
or `mise.linux.toml` to match the host.

Setup for one machine that I keep private, such as a cluster account or a
home server, lives in a separate private repo. On a machine that needs it,
`~/.dotfiles/.env` holds the repo's URL, and `scripts/private.sh` clones it
into `~/.dotfiles/private`. [Private overlay](docs/private-overlay.md) has the
steps. This repo works without it.

Nushell is my interactive shell. Fish is the login shell. It starts Nu in a
terminal, and scripts and SSH commands stay in Fish. Typing `fish`, `zsh`,
`bash`, or `nu` in any shell opens that shell. Fish has the same
aliases and environment as Nu, so I can drop Nu at any time.

Claude Code, Codex, Copilot, and OpenCode all read one instructions file,
`agent-config/AGENTS.md`. `agent-config/skills.json` lists the third-party
skills that every host installs.

## Daily use

Run these in `~/.dotfiles`.

| Task | Command |
| --- | --- |
| Preview and apply config changes | `mise dot diff`, then `mise dot apply` |
| Update tools, packages, and plugins | `mise run update` |
| Update other machines over SSH | `mise run sync <host>...` |
| Check this machine | `mise doctor project` |
| Add a CLI tool | `mise use -g <tool>@<version>` |
| Add a Homebrew formula or app | `mise bootstrap packages use -e macos brew:<formula>` |
| Stop tracking a file | Delete it from `home/`, then `mise bootstrap --only dotfiles --prune-dotfiles` |

## Docs

- [Setup](docs/setup.md): install, per-OS notes, shells, agents, history.
- [mise](docs/mise.md): the config files and every mise command used here.
- [Private overlay](docs/private-overlay.md): add private, per-machine setup.
