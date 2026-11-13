# Reference

The README covers install and daily use. This page covers how the setup works
and the commands for less common jobs. Upstream docs:
[mise](https://mise.jdx.dev), [bootstrap](https://mise.jdx.dev/bootstrap.html),
[dotfiles](https://mise.jdx.dev/dotfiles.html).

## Config files

| File | Kind | Applies |
| --- | --- | --- |
| `home/.config/mise/config.toml` (linked to `~/.config/mise/config.toml`) | Global | Everywhere: tools, mise settings, the `update` task |
| `mise.toml` | Project | Only when mise runs in `~/.dotfiles`: dotfiles, bootstrap, the `sync` task, health checks |
| `mise.macos.toml`, `mise.linux.toml` | Project, per OS | Homebrew or apt packages, macOS settings, OS-only dotfiles |
| `mise.<env>.local.toml` | Project, per host | Links into the [private overlay](#private-overlay) |

mise asks you to trust a project config before it runs anything from it. Run
`mise trust --all` in `~/.dotfiles` once.

`.miserc.toml` sets `auto_env = true`, so a Mac loads `mise.macos.toml` and a
Linux host loads `mise.linux.toml` with no setting on the host. Delete
`.miserc.toml` at mise 2027.6.0, which turns `auto_env` on by default. A host
adds more environments with `env = ["work"]` in
`~/.config/mise/miserc.local.toml`, or `MISE_ENV=work` in its login
environment. mise finds `mise.<env>.toml` only beside `mise.toml`, so the env
files stay at the repository root. `mise config ls` in `~/.dotfiles` shows
what a host loads.

Run project commands in `~/.dotfiles`, not with `mise -C ~/.dotfiles`. `-C`
loads `mise.toml` but skips the env files, so packages and repos go missing.

## Which machines a file reaches

| You edit | It reaches |
| --- | --- |
| `home/`, `mise.toml`, the global config | Every machine |
| `macos/`, `mise.macos.toml` | Macs only |
| `linux/`, `mise.linux.toml` | Linux machines only |
| `private/mise.<host>.toml`, `private/<host>/` | That host only |

An edit is live at once on the machine where you make it, because the config
files are links into the clone. Other machines get it when they pull `main`,
which `mise run sync` does for them. A change that reaches only the Mac needs
no `sync`; run `mise bootstrap --skip-dirty` on the Mac.

## Dotfiles

`[dotfiles]` in `mise.toml` maps targets under `~` to sources in the repo:

```toml
"~" = { source = "home", mode = "symlink-each", exclude = [".atuin", ".profile", "**/.DS_Store"] }
```

`symlink-each` links every file under `home/` to the same path under `~`. It
creates real folders and links only the files, so programs can still write
their own files into folders such as `~/.config/fish`. The two excluded paths
have their own entries, so a private env file can turn them off. The
`.DS_Store` glob stops a Finder file from blocking the run.
`settings.dotfiles.relative_symlinks = true` keeps the links valid when the
home folder moves.

| Entry | Effect |
| --- | --- |
| `"~/.claude/CLAUDE.md" = "agent-config/AGENTS.md"` | Link one file to one source |
| `{ mode = "absent" }` | Delete the target on every host |
| `{ enabled = false }` | Turn off an entry declared in another file |

`macos/` and `linux/` are dotfile groups: folders that mirror `~` for one OS.
`mise.toml` declares the groups and sets `[bootstrap] dotfile_groups = []`.
Each OS file turns on its own group, for example
`dotfile_groups = ["macos"]`.

| Command | Use |
| --- | --- |
| `mise dot diff` | Show what `apply` would change |
| `mise dot apply` | Create and fix every link |
| `mise dot status` | Show each entry's state |
| `mise bootstrap --only dotfiles --prune-dotfiles` | Also remove links whose source is gone |
| `mise bootstrap --force-dotfiles` | Replace a file that is in the way of a link |

A file already at a target stops the run. mise never overwrites a file it did
not create unless you pass `--force-dotfiles`. Deleting a source does not
delete its link: `sync` passes `--prune-dotfiles` on each host, and on the
Mac run the prune command above.

## Bootstrap

`mise bootstrap` applies each part in a fixed order. Each part changes only
what differs, so a second run does nothing. Hooks run every time, so the
scripts are safe to repeat.

| Part | Config | What it does here |
| --- | --- | --- |
| `files` | `[bootstrap.files]` | Writes `/etc/pam.d/sudo_local` (Touch ID for sudo) on macOS |
| `packages` | `[bootstrap.packages]` | Homebrew formulae and casks on macOS; apt packages on Linux |
| `services` | `[bootstrap.services]` | mise's built-in hourly `tool-update` service on macOS |
| `repos` | `[bootstrap.repos]` | Clones `~/code/agent-toolbox` on macOS when it is missing; never resets a checkout |
| `dotfiles` | `[dotfiles]` | The links above |
| `macos-defaults` | `[bootstrap.macos.*]` | Dock, Finder, keyboard, trackpad, clock, Stage Manager |
| `macos-launchd-agents` | `[bootstrap.macos.launchd.agents]` | Weekly formula upgrade, then `scripts/plugins.sh` |
| `user` | `[bootstrap.user]` | Sets Fish as the login shell |
| `tools` | Global `[tools]` | Installs every tool |
| hooks | `[bootstrap.hooks]` | After tools: `scripts/atuin-agents.sh`, `scripts/plugins.sh` |

| Command | Use |
| --- | --- |
| `mise bootstrap --dry-run` | Show what a run would do |
| `mise bootstrap -y` | Apply with no prompts |
| `mise bootstrap --only <part>` / `--skip <part>` | Run or skip parts, for example `--skip user` where `chsh` is not allowed |
| `mise bootstrap --skip-dirty` | Skip a declared repo that has local changes, instead of stopping |
| `mise bootstrap status` | Show the state of every part |
| `mise bootstrap macos defaults status` | Show preference drift |
| `mise bootstrap files status` | Show drift in managed system files |

Do not declare `~/.dotfiles` under `[bootstrap.repos]`: you edit it through
the links, so it is often dirty. `mise bootstrap remote` does not work here,
because it applies from a temporary copy that it deletes, so the links would
point at nothing. Use `mise run sync`.

## Packages

### Homebrew without brew

`mise.macos.toml` lists formulae as `"brew:<formula>" = "latest"` and apps as
`"brew-cask:<cask>" = "latest"`. mise downloads Homebrew's bottles and casks
itself into `/opt/homebrew`. It never runs `brew`, so a new Mac does not need
Homebrew.

| Command | Use |
| --- | --- |
| `mise bootstrap packages use -e macos brew:<formula>` | Install a formula and add it to `mise.macos.toml` |
| `mise bootstrap packages apply` | Install the listed packages |
| `mise bootstrap packages upgrade --manager brew-cask --dry-run` | Preview app upgrades |
| `mise bootstrap packages prune --dry-run` | List formulae that nothing listed needs |

- List only the formulae you use, not their libraries. `prune` keeps what a
  listed formula or cask depends on.
- `prune` also keeps anything that any trusted config declares, including an
  old worktree under `~/.dotfiles/.claude/worktrees`. Remove stale worktrees
  first, and always run it with `--dry-run` first.
- List only Homebrew core formulae. A third-party tap formula needs a Ruby
  from mise's own installs.
- The brew CLI's `brew services` and version pins are not available. Use
  versioned names such as `brew:postgresql@17`.

### Apps

`[bootstrap.brew] adopt = true` makes mise take over an app already in
`/Applications` instead of installing it again.

- `mise run update` does not upgrade apps. Apps update themselves or prompt
  for an update, as Anki does. A cask upgrade replaces the app bundle, and a
  replaced bundle can lose its Privacy & Security permissions.
- Not listed: App Store apps (install them from the App Store's Purchased
  list; the Dock names Things 3, so install it before the first bootstrap);
  casks whose `.pkg` installer asks for sudo (tailscale-app, zoom, Microsoft
  Office, box-drive, google-drive); deprecated casks (arc, qbittorrent, muse);
  apps with no cask (Ardia, Sailfish, yab, Factorio, Rex Beta, Ivanti Secure
  Access); and apps older than their cask that do not update themselves,
  because adoption would fail (balenaEtcher, PhotoCraft, PrettyClean,
  WordCraft; add each after you update it).

### Linux

`mise.linux.toml` declares the apt packages every Linux host gets (build
tools, curl, fish, zsh, Nushell, the SSH server, Tailscale, htop, btop, tree,
Docker, Rex) and their apt sources. `/etc/apt/preferences.d/rex` pins Rex to
its own repository, because Ubuntu ships an unrelated `rex` at a higher
version. The `bootstrap` task installs Zed into `~/.local` on a host with a
desktop session. A host without root sets
`[settings] system_packages.managers = []` and the Rex pin to
`state = "absent"` in its own env file.

## Tools

The global config lists every CLI tool and runtime under `[tools]`. A
project that needs a toolchain, such as Go or CMake, declares it in its own
`mise.toml`.

- `"latest"` or a partial version (`node = "26"`) updates automatically. An
  exact version never moves.
- `tool_update.global_auto = "24h"` checks at most once a day. On the Mac the
  `tool-update` service checks every hour. A release installs 24 to 48 hours
  after it is published (`minimum_release_age`).
- `auto_update = false` holds a tool for manual upgrades. tmux uses it,
  because a new client may refuse an older running server. bun uses it,
  because LaunchAgents that start a versioned bun path break when mise
  removes the old version; point them at `installs/bun/latest` first.
- `self_update.auto = true` updates mise itself.
- `github.credential_command` gives mise the `gh auth login` token, so update
  checks avoid GitHub's anonymous rate limit.

| Command | Use |
| --- | --- |
| `mise use -g <tool>@<version>` | Add a tool to the global config and install it |
| `mise upgrade` | Upgrade tools within their version requests |
| `mise ls` | List tools and where each request comes from |
| `mise prune` | Remove tool versions that no config uses |
| `mise x <tool>@<version> -- <command>` | Run a tool once |

Shells put tools on PATH with `mise activate`. The POSIX and Zsh login
profiles add the shims folder for programs that start those shells. A slow
host can set `MISE_SKIP_ACTIVATE=1` and use `mise bin-paths` instead.

## Tasks

| Task | Defined in | What it does |
| --- | --- | --- |
| `mise update` | Global config | System packages first (Homebrew formulae on macOS, not apps; every apt package on Linux), then `mise self-update`, `mise upgrade`, and `scripts/plugins.sh` |
| `mise run sync [host]...` | `mise.toml` | Records new agent skills from this host and each host, commits and pushes `agent-config/skills.json`, then on each host over SSH: `git pull --ff-only`, `sh scripts/private.sh`, and `mise bootstrap -y --skip user --skip-dirty --prune-dotfiles` |

`mise <task>` runs a task when no built-in command has that name, so do not
name a task `u`, `up`, or `sync` (`mise use`, `mise upgrade`, and a built-in
`sync`). `sync` works only as `mise run sync`.

Notes on `update`:

- The packages step runs first with `raw = true`, so the sudo prompt comes at
  the start and nothing writes over it. A host with
  `system_packages.managers = []` skips it.
- On Linux it upgrades every apt package on the system, not only the ones in
  `mise.linux.toml`. Without a terminal (a script, SSH without `-t`, an
  agent's shell), sudo cannot ask, so it prints `apt: SKIPPED` and the rest
  continues.
- An upgrade of `docker-ce` restarts the Docker daemon and every running
  container. After a kernel upgrade, the step prints `apt: reboot required`.

Notes on `sync`:

- The commands go to `sh` on the host's standard input, because Fish rejects
  `"$(...)"` as a command.
- `--skip user`: SSH cannot answer the `chsh` password prompt.
- A failed host does not stop the others; the task lists them and exits 1.
- A new apt package on a host whose sudo asks for a password cannot install
  over SSH. Run `mise bootstrap --skip-dirty` in a terminal on that host.
- `git pull --ff-only` stops when the host's clone has its own commits or
  edits. Commit and push them, or discard them, then sync again.

`mise doctor project` runs two checks from `mise.toml`: the Nu plugins are
registered at paths that exist, and `agent-config/skills.json` lists every
installed skill. A private env file can add its own checks.

## Private overlay

Setup that must stay private, such as a cluster account or a server's backup
jobs, lives in a separate private repo.

1. Put its URL in `~/.dotfiles/.env` (ignored by Git):
   `DOTFILES_PRIVATE_REPO=https://github.com/<you>/<private-repo>.git`.
2. Run `sh scripts/private.sh`. It clones the repo into `private/` (or pulls
   it), links each `private/mise.<env>.toml` to `mise.<env>.local.toml`, and
   deletes links whose target is gone.
3. If the env is not an OS env, turn it on:
   `echo 'env = ["work"]' >> ~/.config/mise/miserc.local.toml`.
4. Run `mise bootstrap --dry-run`, then `mise bootstrap`.

`sync` runs `scripts/private.sh` on each host first. A private env file takes
the same tables as a public one, with paths that start with `private/`:

```toml
[dotfile_groups.work]
root = "private/work"

[bootstrap]
dotfile_groups = ["linux", "work"]   # replaces the OS list, so keep the OS group

[dotfiles]
"~/.profile" = { enabled = false }   # works only for entries with their own line in mise.toml
```

## Shells

Fish is the login shell. An interactive Fish session hands off to Nu when Nu
is installed and stdin is a terminal, SSH sessions included. Piped and
noninteractive commands stay in Fish. Typing `fish`, `zsh`, `bash`, or `nu`
in any shell opens that shell, and only Fish hands off. Fish has the same
aliases and environment as Nu. Zsh is a minimal fallback with history,
completion, and the prompt.

- Fish without the handoff: `env FISH_ONLY=1 fish`.
- Broken Fish config: `fish --no-config --interactive`.
- Remote recovery: `ssh -t <host> 'env FISH_ONLY=1 fish'`.

`config.nu` sets the environment, then generates integrations for installed
tools. It rebuilds a generated file only when the tool, Nu's version, or
`config.nu` changes. Nu then loads `autoload/interactive.nu` for shortcuts,
integrations, and completions. `nu -c` skips user config; use
`nu --execute '…; exit'` to test the full setup.

`scripts/plugins.sh` installs Fisher and syncs `home/.config/fish/fish_plugins`,
installs TPM and the tmux plugins, registers the Nu plugins, and installs the
agent skills. tmux saves sessions every 15 minutes and restores them when the
server starts; `prefix Ctrl-S` and `prefix Ctrl-R` save and restore by hand.

### Nu plugins

Every host registers `polars`, `parquet`, and `query`. Each must match the
host's Nu version.

- macOS: `brew:nushell` ships `polars` and `query`. Linux with root: the
  distro package puts them in `/usr/libexec/nushell`. Elsewhere:
  `cargo install --locked nu_plugin_polars nu_plugin_query --version <nu version>`.
- `parquet` is a separate crate that tracks Nu's minor version: Nu 0.116
  needs `cargo install --locked nu_plugin_parquet --version 0.26.0`.

`nu scripts/nu-plugins.nu` registers each plugin from the first binary found
next to `nu`, in `/usr/libexec/nushell`, `~/.cargo/bin`, `~/.local/bin`, or
PATH. Run it again after a Nu upgrade; `--force` registers again.

## Agents

Claude Code, Codex, Copilot, Gemini (Antigravity), OpenCode, and Zed read one
instructions file, `agent-config/AGENTS.md`, through links from `mise.toml`. This
repo does not
manage `~/.claude/settings.json` or `~/.codex/config.toml`. The private
overlay can merge shared keys into a host's Claude settings with a
`merge = true` dotfiles entry, which writes only the keys in its source and
leaves the rest of the file to Claude Code.
`~/.config/opencode/opencode.jsonc` is linked; it defines an `ask` agent that
cannot edit files, used by `~/.local/bin/ask` for quick questions, and the
`scout` and `builder` worker agents for the swe external-agents skill. `scout`
reads and searches only. `builder` implements and commits on its own worktree
branch; it may not push, merge, rebase, reset, stash, or switch branches.

`~/.local/bin/claude-code-mode` starts one Claude Code session with
experimental Code Mode on. Code Mode does not start while a mod hooks tool
calls, so the launcher passes `--settings` to turn off the `activity`,
`session-panel`, and `subagents` plugins and Remote Control for that session
only. Arguments
pass through to `claude`. A Code Mode session resumes only with Code Mode on,
so resume it with `claude-code-mode --continue`. Add any new mod that hooks
`tool.call` to the launcher's list.

`agent-config/skills.json` maps each global skill to its `npx skills add`
source. Bootstrap installs the listed skills a host is missing into
`~/.agents/skills` and links them into `~/.claude/skills`; `mise.toml` also links
`~/.gemini/config/skills` to `~/.agents/skills` for Gemini (Antigravity). The
skills CLI runs through `npx skills`. To add a skill, install it on any host
with `npx skills add <source> -g -a claude-code -a codex`; the `npx` fish
wrapper records new skills in `agent-config/skills.json` and commits it
automatically. On hosts without the
wrappers, run `mise run sync`, which records them. Removing a skill from
the list does not uninstall it; run `npx skills remove -g <name>` on every
host before the next `mise run sync`, because sync records any skill still
in a host's lock. Rex's skill and the agent-toolbox plugin skills are not in the list.
A host with neither `claude` nor `codex` on PATH skips both the agent skills
and agent plugins steps.

`agent-config/plugins.json` maps each agent plugin to its marketplace and is
installed by the bootstrap the same way as `skills.json`: `scripts/agent-plugins.nu`
(run from `scripts/plugins.sh` after the skills step) registers each marketplace
and installs each listed plugin for `claude` and `codex` when they are on PATH,
skipping ones the agent already has. A failure only warns. The public list
covers `swe`, `lab` and `uni` from `agent-toolbox` and `obsidian` from
`obsidianmd/obsidian-skills`, which is where the Obsidian skills ship; they are
not installed via the skills CLI. A host's private overlay can add entries the
public repo must not name: if `private/agent-config/plugins.json` exists, its
marketplaces and plugins merge on top. Gemini (Antigravity)
has no agent plugins and gets none. Update plugins with
`claude plugin update <plugin>@<marketplace>` (restart required) or
`codex plugin marketplace upgrade <marketplace>`; neither is in `skills.json`.

Skills written for these hosts live in `agent-config/skills/`. Each has two
entries in `mise.toml` that link its folder to `~/.agents/skills` and
`~/.claude/skills`. To add one, make its folder and add the two entries.

## Shell history

mise installs atuin on every host. A host whose home folder is on a network
filesystem sets `MISE_DISABLE_TOOLS=atuin`, because the SQLite database must
not live there. A host that runs no agent also lists the agent tools in
`MISE_DISABLE_TOOLS` in its private overlay. Nu, Fish, and zsh give atuin Ctrl-R and Up-arrow. Up-arrow
searches the current directory using prefix match in a compact inline menu.
`~/.atuin/config.toml` is linked; the database and key
stay in `~/.atuin/data`.

- Log in on a new host with `atuin login` in a real terminal. It asks for the
  encryption key, which every host shares; keep it in a password manager.
- Import old history once with `atuin import fish` and `atuin import nu`.
  On macOS, `atuin import nu` reads only
  `~/Library/Application Support/nushell`: run it with a temporary `HOME`
  that holds a copy of `history.txt` there, and `ATUIN_HOME=~/.atuin`.
  Imported history stays local until `atuin history init-store`, so check it
  for secrets first.
- `scripts/atuin-agents.sh` installs atuin's hooks and MCP server for each
  installed agent, so agent commands are recorded under the agent's name:
  `atuin search --author '$all-agent'`.
- `history_filter` drops reflex commands that are faster to type than to
  find: `clear`, `pwd`, `exit`, `ls`, shell switches, bare `tmux`, git
  status, pull, push, fetch, branch, add, stash, diff, and log, lookups such
  as `which` and `echo $VAR`, editors and `open .` with no file, and one-word
  `cd` jumps, because atuin stores the working directory with every command.
  Dropping `echo $VAR` also keeps echoed secrets out of output capture. The
  filter sees the command as typed, so it lists each alias and its full form.
  A filter acts only on new commands; `atuin history prune` removes old
  matches.

## macOS settings

- **Touch ID for sudo:** `/etc/pam.d/sudo_local` survives macOS updates,
  which replace `/etc/pam.d/sudo`. It does not reach tmux or Rex panes.
- **Preferences:** mise has no capture command. After a change by hand, run
  `defaults read <domain> <key>` and copy the value in. Five keys use raw
  `defaults` entries to keep macOS's types. `AppleInterfaceStyle` is left
  out, because automatic dark mode changes it. mise does not restart the Dock
  or Finder; after a real change run `killall Dock Finder SystemUIServer`.

## Local state

| Path | Contents |
| --- | --- |
| `~/.config/secrets.env` | Optional credentials, mode `0600`; source it from the login environment |
| `~/.config/git/config.local` | Per-machine Git settings |
| `~/.config/zsh/local.zsh` | Per-machine Zsh settings |
| `~/.config/nushell/generated/` | Generated integrations |
| `~/.config/nushell/plugin.msgpackz` | Nu plugin registrations |
| `~/.local/state/rex-snapshots/` | Rex pane label state and logs |

## Debugging

| Symptom | Check |
| --- | --- |
| A link is missing | `mise dot status`; `mise config ls` (is the env file loaded?) |
| A host loads the wrong env file | `mise config ls`; `echo $MISE_ENV`; `~/.config/mise/miserc.local.toml` |
| A tool is not on PATH | `mise doctor`; `mise which <tool>` |
| Bootstrap stops at a part | `mise bootstrap --only <part> --dry-run` |
| mise refuses the config | `mise trust --all` in `~/.dotfiles` |
