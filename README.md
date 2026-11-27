# .dotfiles

My config for macOS and Linux: Nushell, Fish, Neovim, Rex, Ghostty, tmux, and the
settings for Claude Code, OpenCode, and the other coding agents a host has. [mise](https://mise.jdx.dev)
installs all of it and links it into place. There is no Brewfile, symlink
manager, or install script. Global CLI tools live under `~/.config/mise/`
(`config.toml` or `conf.d/*.toml`). Provisioning lives in `mise*.toml`, and
agent manifests live in `agent-config/`.

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
  else first; on Linux, install Git and curl from the package manager. The
  bootstrap installs Fish and Nu.
- On a server whose umask is not `022`, run `umask 022` first, or new folders
  such as `~/.local` become group-writable.
- Then set your Git identity in `~/.config/git/config.local`, and sign in by
  hand: `gh auth login` and `atuin login`.

  ```sh
  git config --file ~/.config/git/config.local user.name "Your Name"
  git config --file ~/.config/git/config.local user.email "you@example.com"
  ```

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
kept in the private overlay and linked only for the agents a host has
(`agent-config/agents.json`). `agent-config/skills.json` and
`agent-config/plugins.json` list the skills and plugins each installed agent
gets, including our own agent-toolbox plugins. `agent-config/mcp.json` lists
the Claude Code MCP servers each host gets. `agent-config/claude-statusline.py`
is the Claude Code status line; its header says how to install it.

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
| Add a global CLI tool (writes to `~/.config/mise/config.toml`) | `mise use -g <tool>@<version>` |
| Add a Homebrew formula | `mise bootstrap packages use -e macos brew:<formula>` |
| Stop tracking a file | Delete it from `home/`, then `mise bootstrap --only dotfiles --prune-dotfiles` |

[Reference](docs/reference.md) covers the config files, bootstrap, packages,
shells, agents, history, and debugging.
