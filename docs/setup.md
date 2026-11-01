# Setup and maintenance

## Prerequisites

Use an existing shell for setup. Install Git and curl, then install Fish and Nu
using the host's package manager or the projects' installation instructions.
Nu loads integrations for installed tools. Without Oh My Posh, it uses its
built-in prompt.

- **macOS:** install nothing first. `mise bootstrap` installs Fish, Nu, and
  the other Homebrew packages into `/opt/homebrew` without the brew CLI. The
  Ghostty configuration expects Nu at `/opt/homebrew/bin/nu`.
- **Linux with root access:** use distribution packages where available. The
  Ghostty configuration currently expects Nu at `/usr/bin/nu`; adjust it if
  your installation uses another path.
- **Linux without root access:** use site-provided tools or install suitable
  binaries under `~/.local/bin`. If the account's login shell is fixed, leave
  it in place and configure your terminal or remote session to launch Nu.

Shell installation references: [Fish](https://fishshell.com/),
[Nushell](https://www.nushell.sh/book/installation.html).

## Install and apply

Install mise:

```sh
curl https://mise.run | sh
```

Clone the repository, trust its mise config, preview, and apply. On macOS,
`mise bootstrap` also installs the Homebrew packages in `mise.macos.toml`. Run it in
a real terminal: it asks for your password to create `/opt/homebrew` and to
run the Karabiner-Elements installer, and without a terminal the run stops
there:

```sh
git clone https://github.com/kpeez/dotfiles.git ~/.dotfiles
cd ~/.dotfiles
~/.local/bin/mise trust --all
~/.local/bin/mise bootstrap --dry-run
~/.local/bin/mise bootstrap
```

On a host whose umask is not `022` (some servers use `0002`), run `umask 022`
first. Otherwise new directories such as `~/.local` become group-writable.

`mise bootstrap` links the dotfiles, installs the Homebrew packages on macOS,
sets fish as the login shell, installs the tools, then runs
`scripts/atuin-agents.sh` and `scripts/plugins.sh`. The second installs Fisher
and TPM, syncs their plugin lists, registers the Nu plugins, and installs the
[agent skills](#agent-skills). Then sign in by
hand: `gh auth login` and `atuin login`.
On macOS, bootstrap also clones `~/code/agent-toolbox`
(`[bootstrap.repos]` in `mise.macos.toml`) when it is missing; it never
deletes or resets a checkout. It clones before it links the git config and
installs git-lfs, so a repository that uses LFS gets pointer files; run
`git lfs pull` in it after the first bootstrap. A checkout with local changes stops a
plain `mise bootstrap` at the repos step, before dotfiles and tools; pass
`--skip-dirty` to skip it. Do not declare `~/.dotfiles` itself: it is often
dirty, because you edit it through the links. A file already at a target stops the
run; move it aside, or pass `--force-dotfiles` to replace it.

The login shell step finds fish after the macOS Homebrew packages install it,
adds it to `/etc/shells` with sudo, and runs `chsh`. Both can ask for your
password. Both post-tools scripts are safe to repeat.

#### Updating other hosts

`mise run sync <host>...` pulls and bootstraps other hosts over SSH. See
[Tasks](mise.md#tasks) in the mise guide.

### Agent configuration

All agents share one instruction file, `agent-config/AGENTS.md`. `mise.toml` links
`~/.claude/CLAUDE.md`, `~/.codex/AGENTS.md`,
`~/.copilot/copilot-instructions.md` and `~/.config/opencode/AGENTS.md` to it.

OpenCode's global configuration is linked from this repo at
`~/.config/opencode/opencode.jsonc`. Its paths use `$HOME` substitution so the
same file works on macOS and Linux. The configured skill directories are
optional; OpenCode can start if `agent-toolbox` is not installed yet. The file
also defines an `ask` agent: a free model that cannot edit files or run shell
commands. The `ask` script (`~/.local/bin/ask`) uses it for quick questions in
any shell, for example `ask what is a monad`.

This repo does not manage the Claude Code or Codex settings files. Each app
keeps its own `~/.claude/settings.json` and `~/.codex/config.toml`.

`mise bootstrap` sets Fish as the login shell (`[bootstrap.user]` in
`mise.toml`). Where the account does not permit `chsh`, skip that step with
`--skip user`. Configure terminal
windows to use the account shell. Interactive Fish sessions hand off to Nu when
it is installed and stdin is a terminal, including SSH terminal sessions and
terminals that start non-login shells. Piped command sessions stay in Fish even
when a remote tool passes `fish -i`. Fish
sets the XDG paths before launching Nu. Noninteractive commands stay in Fish.
Ghostty's existing OS-specific fragments also support launching Nu directly.

To open Fish without the handoff, run `env FISH_ONLY=1 fish`. If Fish's own
configuration is broken, use `fish --no-config --interactive`. For remote
recovery, run `ssh -t <host> 'env FISH_ONLY=1 fish'`. If Nu is unavailable, Fish
remains interactive.

Fish defines the same shortcuts and environment variables as Nu, so it can
replace Nu without rework. `python3 tests/test-fish-nu-parity.py` fails when the
two differ. Record deliberate differences, with the reason, in that test.

### Agent skills

Third-party agent skills come from the [skills CLI](https://github.com/vercel-labs/skills)
(`npx skills`, or `skills` from `home/.config/mise/config.toml`).
`agent-config/skills.json` maps the name of each global skill to its
`skills add` source. `mise bootstrap` installs the listed skills that a host does
not have yet (`scripts/skills.nu`, run by `scripts/plugins.sh`). It installs
each skill once into `~/.agents/skills`, which Codex reads, and links it into
`~/.claude/skills` for Claude Code.

To add a skill, install it on any host:

```sh
npx skills add <source> -g -a claude-code -a codex
```

Then run `mise run sync <host>...` on any host. It reads the lock file of
that host and of each SSH host, and adds the skills that the list does not have
(`nu scripts/skills.nu record <lock files>`). When the list changes, it
commits and pushes only `agent-config/skills.json`, and installs the list on
that host. Then each host pulls and bootstraps, which installs the list there.

`mise doctor project` fails while the lock holds a skill that the list does
not have. On one host, `nu scripts/skills.nu record` records its own lock,
and `nu scripts/skills.nu` installs the list.

The lock file is `~/.agents/.skill-lock.json`, or
`$XDG_STATE_HOME/skills/.skill-lock.json` when `XDG_STATE_HOME` is set. It is not
tracked: the CLI rewrites its timestamps and hashes on every install and
update, and skills 1.7.4 has no command that restores global skills from it.
`skills update -g` updates the installed skills. Removing a skill from
the list does not uninstall it; run `npx skills remove -g <name>` on each host.

Skills that other tools install are not in the list: Rex's `rex` skill
(`rex skill setup`) and the agent-toolbox plugin skills.

### Nushell startup configuration

Following the [Nushell configuration guide](https://www.nushell.sh/book/configuration.html#quickstart),
`~/.config/nushell/config.nu` sets environment variables and shell settings,
then generates integrations for the installed tools. It rebuilds a generated
file only when the tool's install, Nu's version or `config.nu` changes, so most
starts launch no tool processes. Nu subsequently loads
`~/.config/nushell/autoload/interactive.nu`, which defines shortcuts, loads
those integrations, and configures completions. This order also works on first
startup, when the generated files do not exist yet.

Use an interactive Nu
session (`nu`, or `nu --execute '…; exit'` for checks) to load the full setup.
`nu -c` skips user configuration, and even `nu -i -c` skips autoload files in
Nu 0.115.1.

## macOS settings

### sudo and Touch ID

`mise.macos.toml` declares `/etc/pam.d/sudo_local` with the `pam_tid.so` line,
owned by `root:wheel` with mode `0444`. `sudo` then accepts Touch ID, and the
file survives macOS updates, which replace `/etc/pam.d/sudo`. Do not edit
`/etc/pam.d/sudo` itself. `mise bootstrap files status` reports drift when a
tool changes the file or its owner.

Touch ID does not reach a terminal multiplexer such as tmux or Rex without the
`pam_reattach` module above the `pam_tid.so` line. This is not set up.

### Apps

`mise.macos.toml` lists every installed app that has a Homebrew cask.
`[bootstrap.brew] adopt = true` makes mise take over an app that is already
in `/Applications` instead of installing it again. For an app that updates
itself, mise keeps the bundle on disk as it is. An app that does not match
the cask and does not update itself makes its install fail, and the app
stays as it is.

- App Store apps are not managed. mise could install them with `mas:<id>`
  entries, but each new app would need its ID added by hand, and every
  bootstrap would need an App Store sign-in. Install them from the App
  Store's Purchased list. The Dock list names Things 3, so install it before
  the first bootstrap writes the Dock, as for yab and Rex Beta, which have no
  cask.
- Not listed: the casks whose installer is a `.pkg` that asks for sudo
  (tailscale-app, zoom, Microsoft Word, Excel and PowerPoint, box-drive,
  google-drive); deprecated or disabled casks (arc, qbittorrent, muse); apps
  with no cask (Ardia, Sailfish, yab, Factorio, Rex Beta, Ivanti Secure
  Access); apps that do not update themselves and are older than their cask,
  so adoption would fail and stop `mise bootstrap` (balenaEtcher,
  PhotoCraft, PrettyClean, WordCraft; add each after you update it); and
  Delta (zed-delta), which is not checked.
- Add an app with `mise bootstrap packages use -e macos brew-cask:<cask>`, or
  apply one entry with `mise bootstrap packages apply brew-cask:<cask>`.
- mise records the cask's version at adoption, not the app's. At the next
  cask release, `mise run update` or `packages upgrade --manager brew-cask`
  replaces every adopted app that is not running, also apps that are older
  than their cask today, such as Fantastical 3 (cask: 4) and Telegram 12
  (cask: 13). A replaced bundle can lose its Privacy & Security permissions.
  Run `mise bootstrap packages upgrade --manager brew-cask --dry-run` first.

### Preferences

The `[bootstrap.macos.*]` tables in `mise.macos.toml` record this Mac's
preferences: Dock (with the pinned apps), Finder, keyboard, trackpad, the
menu-bar clock, Stage Manager and tiling, no `.DS_Store` files on network and
USB drives, and the disabled Spotlight shortcut. `mise bootstrap` writes them;
`mise bootstrap macos defaults status` shows drift.

- mise has no capture command. After you change a setting by hand, run
  `defaults read <domain> <key>` and copy the value into the file.
- Five keys use raw `defaults` entries (`46.0`, `"false"`) because macOS
  stores them as real numbers or strings, and the named keys would change the
  type.
- `AppleInterfaceStyle` is left out: automatic dark mode changes it during
  the day.
- mise does not restart the Dock or Finder. After a real change, run
  `killall Dock Finder SystemUIServer` once. A bootstrap hook would run it on
  every bootstrap.
- The Dock list fails when an app is missing. Bootstrap installs packages
  before it writes preferences.

## Shell history

mise installs atuin on every host. A host whose home folder is on a network
filesystem can set `MISE_DISABLE_TOOLS=atuin`, because atuin's SQLite
database must not live there. Nu, Fish and zsh give atuin Ctrl-R when it is installed; elsewhere
fzf keeps Ctrl-R. Up-arrow stays with each shell's own history. `mise.toml`
links `~/.atuin/config.toml`; the database and key stay in `~/.atuin/data`.

Import existing history once per host:

```sh
atuin import fish
atuin import nu
```

On macOS, `atuin import nu` reads `~/Library/Application Support/nushell`, not
`~/.config/nushell`, and has no path option. Run it with a temporary `HOME`
that holds a copy of `~/.config/nushell/history.txt` under
`Library/Application Support/nushell/`, and set `ATUIN_HOME=~/.atuin` so it
writes to the real database.

`mise bootstrap` runs `scripts/atuin-agents.sh` after it installs the tools. For each
installed agent (Claude Code, Codex, OpenCode), it installs the atuin hooks
that record the agent's shell commands under its name, and the atuin MCP
server that lets the agent search history. OpenCode gets only the hooks,
because OpenCode 2.2 does not load the server that atuin writes for it. Codex
asks you to trust new hooks at its next start. Filter by who ran a command
with `atuin search --author '$all-agent'`, `'$all-user'`, or an agent name.

The config also turns on thread capture, so `atuin threads` can search and
resume agent sessions from any synced host. Tool output is kept with secrets
redacted.

`~/.atuin/config.toml` sets only what this setup relies on;
`atuin default-config` prints every option with its documentation.

- `history_filter` stops atuin from recording bare `clear`, `pwd`, `exit`,
  `ls`, `lsa`, `cd` and `cd ..`, even with stray spaces. The anchors keep
  `clear && make`, `ls dir` and `cd dir`. The pattern uses single quotes so
  TOML keeps `\s` literal.
- `search.shells = "all"`: Fish and Nu share one history. The default shows
  only the current shell's.
- `ui.columns` adds host and duration, because history syncs from several
  hosts.
- `security.sensitive_files` adds files to atuin's built-in list (gh, aws,
  kube, `.env`). atuin never stores the output of a command that names one.
  The secrets filter cannot recognise random passphrases. A glob without `/`
  matches that file name in any folder, so `cd dir && cat password` is
  covered too.

A filter acts only on new commands. To remove old matches, run
`atuin history prune --dry-run`, then `atuin history prune` on one host. The
deletes sync to the other hosts.

### Sync

History syncs through an account on `api.atuin.sh`. With a Google sign-in
account, log in on a new host with plain `atuin login`. It asks for
the encryption key, then prints a hub.atuin.sh URL to open in any browser.
`atuin login -u` starts the password login instead, which a Google account
cannot use. Every host must use the same key; keep it in a password
manager. Run the login in a real terminal, because it prompts for input.

Sync uploads only atuin's record store. Imported history stays local until you
run `atuin history init-store`. So import, check the history for secrets, then
run `init-store` and `atuin sync`. `atuin store verify` confirms that the local
records decrypt with the current key.

## Rex pane labels

`init.lua` starts `labels.lua`, which names each pane after its folder and
program: `~/code/learning`, `claude · ~/.dotfiles`, or `server:~` for an SSH
pane whose remote shell reports its folder. It relabels when the foreground
program or folder changes, and shortens a long folder to its last three parts.
It only replaces the default `shell` label or a label it set itself, so a
label you set stays. It tracks its labels in `labels.json`. Each config reload
starts a new labeler and the previous one exits. Errors go to `labels.log`.

The labeler reads process details on the machine that runs it, so it works only
against the local Rex server.

## Nu plugins

Every host runs three Nu plugins: `polars` (DataFrames), `parquet` (open and
save Parquet files as tables) and `query` (HTML, XML and JSON queries). Nu
checks a plugin's version against its own, so install them to match the Nu on
the host.

- **macOS:** the `brew:nushell` package ships `polars` and `query`.
- **Linux with root access:** the distro package puts them in
  `/usr/libexec/nushell`.
- **Hosts without a package:** build them with cargo, using the
  Nu version from `nu --version`: `cargo install --locked nu_plugin_polars
  nu_plugin_query --version <nu version>`.
- **`parquet` everywhere:** it is a separate crate whose release tracks Nu's
  minor version. Nu 0.116 needs `cargo install --locked nu_plugin_parquet
  --version 0.26.0`, and Nu 0.115 needs 0.25.0. Add `--force` to replace an
  older build.

`mise bootstrap` then registers them through `scripts/plugins.sh`. To register
by hand, run this from the repository root:

```sh
nu scripts/nu-plugins.nu
```

The script registers each plugin from the first matching binary: next to
`nu`, `/usr/libexec/nushell`, `~/.cargo/bin`, `~/.local/bin`, then PATH. It
keeps a registration that already points there, and exits with an error that
names any missing binary. Registration lives in `~/.config/nushell/plugin.msgpackz`
and is not tracked. Run the script again after you upgrade Nu or a
plugin. A Homebrew package upgrade moves the binaries to a new `Cellar` path, so the old
registration stops working until you do. Pass `--force` to register again.

## Optional plugins

### Fish

The plugin list is in `home/.config/fish/fish_plugins`. Fisher manages the
downloaded plugin files, which are not tracked.

`mise bootstrap` installs [Fisher](https://github.com/jorgebucaran/fisher#installation)
and synchronizes the plugin list through `scripts/plugins.sh`. By hand:

```fish
curl -fsSL https://raw.githubusercontent.com/jorgebucaran/fisher/main/functions/fisher.fish | source && fisher update
```

### Tmux

`mise bootstrap` clones TPM and installs the plugins through
`scripts/plugins.sh`. By hand:

```sh
git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
~/.tmux/plugins/tpm/bin/install_plugins
```

Tmux works without TPM. With the configured resurrect and continuum plugins,
sessions are saved every 15 minutes and restored when the server starts.
Manual save and restore use `prefix Ctrl-S` and `prefix Ctrl-R`.

### Zsh

Zsh is a minimal fallback with history, completion and the prompt. It has no
plugins or shortcuts.

## Local state and maintenance

| Path | Contents |
| --- | --- |
| `~/.config/secrets.env` | Optional credentials; restrict permissions to `0600` |
| `~/.config/fish/fish_variables` | Fish runtime state |
| `~/.config/git/config.local` | Per-machine Git settings |
| `~/.config/zsh/local.zsh` | Per-machine Zsh configuration |
| `~/.config/nushell/generated/` | Generated integrations |
| `~/.config/nushell/history.txt` | Nu command history |
| `~/.local/share/nushell/` | Nu data and autoload scripts |
| `~/.tmux/plugins/` | Downloaded plugins |
| `~/.tmux/resurrect/` | Saved sessions |
| `~/.local/state/rex-snapshots/` | Rex pane label state and logs; see [Rex pane labels](#rex-pane-labels) |

Check which startup file loads credentials on each host. Nu does not load
`secrets.env` itself; source it from the login environment.

Files under `home/` keep their real names and link into `~` on every host.
Platform-specific files go under `macos/` or `linux/` at the same relative
path. They need no entry; see [Dotfile groups](mise.md#dotfile-groups). Use
shell conditionals for small runtime differences, and mise's `os` filters for
platform-specific tools. Private files go in the
[private overlay](private-overlay.md).

Removing a source file does not remove its deployed link. Run
`mise bootstrap --only dotfiles --prune-dotfiles`, or add a
`{ mode = "absent" }` entry when other hosts must delete the target too.
The `~/.gitconfig` entry exists because that file would shadow
`~/.config/git/config`.

### Global mise config

`home/.config/mise/config.toml` is the one global mise config: every tool,
mise's own settings, and the `update` task. See [Tools](mise.md#tools) and
[Tasks](mise.md#tasks) in the mise guide.

- bun sets `auto_update = false`. LaunchAgents that start a versioned bun
  path (`~/.local/share/mise/installs/bun/<version>/bin/bun`) break when
  mise removes a replaced version 24 hours after an upgrade
  (`upgrade.prune_after`). Point them at `installs/bun/latest` before you turn
  updates on for bun.
- Per-host values that must exist before any shell starts belong in the
  host's login environment, not in the global config.

The POSIX and Zsh login profiles add mise shims to PATH for programs that launch
those shells. This does not change the environment of every app launched by
macOS; check an affected app's actual startup path when diagnosing missing tools.
