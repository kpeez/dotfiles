# Workarounds

A workaround is code that exists only because an upstream tool has a bug or
a limit. A comment in the code, or `docs/reference.md`, gives the short "why".
This file holds only the condition that ends each workaround and the anchors
that find it.
`mise doctor project` checks that every anchor still exists in its file. Add
only a workaround with an end condition that a person can check.

Each entry is a `## <slug>` section. It has one or more `- Anchor:` lines,
written as a repo-relative path and a literal string from that file, each in
backticks and separated by ` · `. It has exactly one `- Remove when:` line.
It can have one `- Upstream:` line with a link. Neither part of an anchor can
contain a backtick or `·`.

## rex-ubuntu-name-clash

- Anchor: `mise.linux.toml` · `[bootstrap.files."/etc/apt/preferences.d/rex"]`
- Remove when: superlogical renames the Rex package, or no Linux host's Ubuntu release offers the Perl `rex` (`apt-cache policy rex` lists only pkgs.superlogical.com).

## miserc-auto-env

- Anchor: `.miserc.toml` · `auto_env = true`
- Remove when: every host runs mise 2027.6.0 or later, which turns `auto_env` on by default. Delete the file then.

## atuin-postinstall-hooks

- Anchor: `home/.config/mise/config.toml` · `postinstall = "sh ~/.dotfiles/scripts/atuin-agents.sh"`
- Anchor: `scripts/atuin-agents.sh` · `PATH="$PATH:$HOME/.local/bin:$HOME/.local/share/mise/shims"`
- Remove when: atuin's agent hooks call atuin through a path that survives an upgrade, not its version folder.

## opencode-atuin-mcp

- Anchor: `scripts/atuin-agents.sh` · `[ "$agent" = opencode ] && continue`
- Remove when: OpenCode loads the MCP server that `atuin mcp install opencode` writes (OpenCode 2.2 does not).

## atuin-nu-index-warmup

- Anchor: `home/.config/nushell/config.nu` · `atuin __internal prepare-search-index > /dev/null 2>&1 &`
- Remove when: `atuin init nu` stops warming the search index in a Nu job, or Nu lets `exit` run while a job runs.

## git-diff3-conflict-style

- Anchor: `home/.config/git/config` · `conflictStyle = diff3`
- Remove when: every host's git is 2.35 or later. Then set `conflictStyle = zdiff3`.
