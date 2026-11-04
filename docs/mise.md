# mise in this repository

mise does three jobs here. It installs CLI tools and runtimes, it links the
dotfiles, and its `bootstrap` command sets up the rest of the machine:
packages, system files, services, and macOS preferences. This guide explains
the config files, how mise reads them, and the commands you use each day.

Upstream reference: [mise docs](https://mise.jdx.dev),
[bootstrap](https://mise.jdx.dev/bootstrap.html),
[dotfiles](https://mise.jdx.dev/dotfiles.html).

## Two kinds of config

| File | Kind | Applies |
| --- | --- | --- |
| `home/.config/mise/config.toml` (linked to `~/.config/mise/config.toml`) | Global config | Everywhere: tools, settings, the `update` task |
| `mise.toml` and `mise.<env>.toml` in `~/.dotfiles` | Project config | Only when mise runs in `~/.dotfiles`: dotfiles, bootstrap, the `sync` task, health checks |

The global config holds what every shell needs, which is the tool list and
mise's own settings. The project config holds the machine setup. That is why the
`mise dot` and `mise bootstrap` commands run in `~/.dotfiles`, and why
`mise -C ~/.dotfiles <command>` works from anywhere.

mise asks you to trust a project config before it runs anything from it.
`mise trust --all` in `~/.dotfiles` trusts this repository's files once.

## How a host picks its env files

mise reads `mise.toml`, then one `mise.<env>.toml` file for each active
environment. An environment is active when `MISE_ENV` names it, or when
`env` in a `miserc` file names it.

- `.miserc.toml` sets `auto_env = true`. With it, mise also activates the
  environment for the host's OS: `macos` or `linux`. So a Mac loads
  `mise.macos.toml` and a Linux host loads `mise.linux.toml`, with no
  setting on the host. mise 2027.6.0 turns `auto_env` on by default; then
  delete `.miserc.toml`.
- A host can add environments. `~/.config/mise/miserc.local.toml` with
  `env = ["work"]`, or `MISE_ENV=work` in the login environment, loads
  `mise.work.toml` too.
- mise also loads `mise.local.toml` and `mise.<env>.local.toml`. They are
  for files that are not in Git. The [private overlay](private-overlay.md)
  uses them.
- mise finds `mise.<env>.toml` only beside `mise.toml` (or in
  `.config/mise/conf.d/`), not in subfolders. So the env files stay at the
  repository root.

To see which files a host loads: `mise config ls` in `~/.dotfiles`.

### Linux packages

`mise.linux.toml` declares the core apt packages that every Linux host gets:
build tools, curl, fish, zsh, Nushell, the SSH server, Tailscale, htop,
btop, tree, Docker, and Rex. It also declares their apt sources: fish (the
fish-shell PPA, because the Ubuntu archive lags), Tailscale, Nushell,
Docker, and Rex. Ubuntu ships an unrelated Perl tool named `rex` at a higher
version, so `/etc/apt/preferences.d/rex` pins Rex to its own repository.
Packages for one host's hardware or services stay in that host's env file.

Zed has no apt repository. The `bootstrap` task in `mise.linux.toml` runs
Zed's install script into `~/.local` on a host that has a desktop session
(`/usr/share/wayland-sessions` or `/usr/share/xsessions`), and only when Zed
is missing. Zed updates itself after that.

A host without root turns system packages off in its own env file:

```toml
[settings]
system_packages.managers = []
```

`mise bootstrap` then reports each apt package as skipped and does not fail.
The same host also sets the Rex pin to `state = "absent"`, because that
file is under `/etc`. The hive env file does both.

## Dotfiles

The `[dotfiles]` table in `mise.toml` maps targets under `~` to sources in
the repository.

```toml
"~" = { source = "home", mode = "symlink-each", exclude = [".atuin", ".profile", "**/.DS_Store"] }
```

`symlink-each` links every file under `home/` to the same path under `~`.
It creates real directories and links only the files, so other programs can
still write their own files into folders such as `~/.config/fish`. The
`exclude` list leaves out two paths that some hosts must not get. They have
their own entries, so a private env file can turn them off. It also leaves
out the `.DS_Store` files that Finder writes into `home/` at any depth.
Without that glob, such a file stops `apply`, because Finder already put its
own `.DS_Store` at the target.

Other entry types in use:

| Entry | Effect |
| --- | --- |
| `"~/.claude/CLAUDE.md" = "agent-config/AGENTS.md"` | Link one file to one source |
| `{ mode = "absent" }` | Delete the target on every host |
| `{ enabled = false }` | Turn off an entry declared in another file |

`settings.dotfiles.relative_symlinks = true` makes the links relative, so
they survive a move of the home folder.

### Dotfile groups

A group is one more folder that mirrors `~`:

```toml
[dotfile_groups.macos]
root = "macos"

[bootstrap]
dotfile_groups = []
```

`mise.toml` declares the groups and turns them all off. Each env file turns
on its own group. For example, `mise.macos.toml` sets
`dotfile_groups = ["macos"]`. Without the
empty default, every group would apply on every host. A group's `root` is
relative to the repository root, even when the env file that turns it on is
somewhere else.

### Commands

| Command | Use |
| --- | --- |
| `mise dot diff` | Show what `apply` would change |
| `mise dot apply` | Create and fix every entry |
| `mise dot status` | Show each entry's state |
| `mise bootstrap --only dotfiles --prune-dotfiles` | Apply, and remove links whose source is gone |
| `mise bootstrap --force-dotfiles` | Replace a file that is in the way of a link |

A file already at a target stops `apply`. mise never overwrites a file it
did not create unless you pass `--force-dotfiles`.

## Bootstrap

`mise bootstrap` applies every part the config declares, in a fixed order.
The parts in use here:

| Part | Config | What it does here |
| --- | --- | --- |
| `files` | `[bootstrap.files]` | Writes `/etc/pam.d/sudo_local` (Touch ID for sudo) on macOS |
| `packages` | `[bootstrap.packages]` | Installs Homebrew formulae and casks on macOS, from Homebrew's own bottles, without the brew CLI |
| `services` | `[bootstrap.services]` | Runs mise's built-in hourly `tool-update` service |
| `repos` | `[bootstrap.repos]` | Clones `~/code/agent-toolbox` on macOS when it is missing; never resets a checkout |
| `dotfiles` | `[dotfiles]` | As above |
| `macos-defaults` | `[bootstrap.macos.*]` | Dock, Finder, keyboard, trackpad, clock, and Stage Manager settings |
| `macos-launchd-agents` | `[bootstrap.macos.launchd.agents]` | The weekly Homebrew upgrade |
| `user` | `[bootstrap.user]` | Sets Fish as the login shell |
| `tools` | Global `[tools]` | Installs every tool in the global config |
| hooks | `[bootstrap.hooks]` | After tools: `scripts/atuin-agents.sh` and `scripts/plugins.sh` |

Each part checks first and changes only what differs, so a second run does
nothing. Hooks run every time, so the scripts are safe to repeat.

### Commands

| Command | Use |
| --- | --- |
| `mise bootstrap --dry-run` | Show what a run would do, part by part |
| `mise bootstrap` | Apply everything |
| `mise bootstrap -y` | Apply with no prompts (for SSH and scripts) |
| `mise bootstrap --only <part>` / `--skip <part>` | Run or skip parts, for example `--skip user` where `chsh` is not allowed |
| `mise bootstrap --skip-dirty` | Skip a declared repository that has local changes, instead of stopping |
| `mise bootstrap status` | Show the state of every part |
| `mise bootstrap plan` | Show resource-level changes |
| `mise bootstrap packages use -e macos brew:<formula>` | Install a formula and add it to `mise.macos.toml` |
| `mise bootstrap packages apply` | Install the listed packages |
| `mise bootstrap packages upgrade [--manager brew-cask]` | Upgrade formulae, or apps |
| `mise bootstrap packages prune --dry-run` | List formulae that nothing listed needs; run without `--dry-run` to remove them |
| `mise bootstrap macos defaults status` | Show preference drift |
| `mise bootstrap files status` | Show drift in managed system files |

`mise bootstrap remote` is not usable here. It runs against a copy of the
repository in `/tmp` and deletes it after the run, so the links would point
at nothing. Use `mise run sync` instead.

### Homebrew packages without brew

On macOS, `mise.macos.toml` lists every formula and cask as
`"brew:<formula>" = "latest"` or `"brew-cask:<cask>" = "latest"`. mise
downloads Homebrew's bottles and casks itself and installs them into
`/opt/homebrew`. It never runs `brew`, so a new Mac does not need Homebrew.

- `prune` removes every formula that the file does not list and that no
  listed formula or cask depends on. List only the formulae you use, not
  their libraries. Always run it with `--dry-run` first.
- `[bootstrap.brew] adopt = true` makes mise take over an app already in
  `/Applications` instead of installing it again.
- mise reads a tap's formula with a Ruby 3 from its own installs, so
  `mise.macos.toml` declares `ruby` as a tool. Without it, `mise prune`
  removes that Ruby and `packages prune` fails.
- Not available without the brew CLI: `brew services` and version pins (use
  versioned names such as `brew:postgresql@17`).

## Tools

The global config lists every CLI tool and runtime under `[tools]`.

- `"latest"` or a partial version (`node = "24"`) updates automatically.
  An exact version (`go = "1.27.3"`) never moves.
- `tool_update.global_auto = "24h"` checks for updates at most once a day.
  On a host that runs the `tool-update` service, the service checks every
  hour instead, so tools update without an open shell. A release installs 24
  to 48 hours after it is published (`minimum_release_age`).
- `auto_update = false` pins a tool to manual upgrades. tmux uses it, because
  a new tmux client may refuse to attach to a running server of an older
  version.
- `self_update.auto = true` updates mise itself.
- `github.credential_command` gives mise the token from `gh auth login`, so
  update checks do not hit GitHub's anonymous rate limit. It runs the `gh`
  shim with `MISE_OFFLINE=1`, so a missing `gh` cannot start a loop of
  version lookups.
- `idiomatic_version_file_enable_tools = ["node"]` makes mise read
  `.node-version` and `.nvmrc` files.

| Command | Use |
| --- | --- |
| `mise use -g <tool>@<version>` | Add a tool to the global config and install it |
| `mise install` | Install every configured tool that is missing |
| `mise upgrade` | Upgrade tools within their version requests |
| `mise ls` | List installed tools and where each request comes from |
| `mise prune` | Remove tool versions that no config uses |
| `mise x <tool>@<version> -- <command>` | Run a tool once without installing it into a config |

Login shells put tools on PATH with `mise activate` (Nu, Fish, Zsh). The
POSIX and Zsh login profiles add the shims folder for programs that start
those shells. A host where activation is too slow can set
`MISE_SKIP_ACTIVATE=1` and put the tools' bin folders on PATH itself
(`mise bin-paths`).

## Tasks

| Task | Defined in | What it does |
| --- | --- | --- |
| `mise run update` | Global config | `mise self-update`; then `mise upgrade` and, on macOS, `packages upgrade` in parallel; then `scripts/plugins.sh`; then `mise bootstrap --dry-run --skip-dirty` to show remaining drift |
| `mise run sync [host]...` | `mise.toml` | Records new agent skills from this host and each host's lock file, commits and pushes `agent-config/skills.json`, then on each host over SSH: `git pull --ff-only`, `sh scripts/private.sh`, and `mise bootstrap -y --skip user --skip-dirty`. With no host, it records only this host's skills |

Drift in the last step of `update` does not fail the task; a host that
cannot run `chsh` always shows it. A dotfile conflict (a file that mise does
not manage at a target) does fail it, as it would fail a real bootstrap.

Notes on `sync`:

- Each host keeps its own checkout, because the dotfiles are links into it.
- The commands go to `sh` on the host's standard input. SSH would otherwise
  run them in the login shell, and Fish rejects `"$(...)"` as a command.
- `--skip user`: SSH cannot answer the `chsh` password prompt.
- A failed host does not stop the others. The task lists the failed hosts
  and exits 1.

Do not name a global task `u`, `up`, or `sync`. `mise u` is `mise use`,
`mise up` is `mise upgrade`, and `mise sync` is a built-in command. `sync`
works here only because it is a project task, run as `mise run sync`.

## Health checks

`[doctor.checks]` in `mise.toml` adds project checks to
`mise doctor project`:

- `nu-plugins`: the Nu plugins `polars`, `parquet`, and `query` are
  registered at paths that exist.
- `agent-skills`: `agent-config/skills.json` lists every skill in the skills
  CLI lock file.

Each check has a `hint` with the fix. A private env file can add its own
checks, such as a GPU check on a GPU host.

## Debugging

| Symptom | Check |
| --- | --- |
| A link is missing | `mise dot status`; `mise config ls` (is the env file loaded?) |
| A host loads the wrong env file | `mise config ls`; `echo $MISE_ENV`; `cat ~/.config/mise/miserc.local.toml` |
| A tool is not on PATH | `mise doctor`; `mise ls <tool>`; `mise which <tool>` |
| Bootstrap stops at a part | Run that part alone: `mise bootstrap --only <part> --dry-run` |
| mise refuses the config | `mise trust --all` in `~/.dotfiles` |
