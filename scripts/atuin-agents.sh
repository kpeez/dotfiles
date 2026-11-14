#!/bin/sh
# Connect each installed coding agent to atuin. The hooks record the agent's
# shell commands with its name, and the MCP server lets the agent search
# history. Both installs are safe to repeat. This runs on every
# `mise bootstrap` (a post-tools hook in mise.toml), which picks up an agent
# installed later, and as atuin's postinstall in the global mise config.
# A hook names atuin by its version folder, and an upgrade deletes the old
# folder; during postinstall, `atuin` is the new version, so the reinstall
# writes the new path.
#
# The background tool-update service runs postinstall with only the system
# PATH, so look for agents where they are installed too: Claude Code's own
# installer and the mise shims. Append them, so `atuin` stays the new version.
# Do not test the agents' config folders: bootstrap links files into them on
# every host.

PATH="$PATH:$HOME/.local/bin:$HOME/.local/share/mise/shims"

command -v atuin >/dev/null 2>&1 || exit 0

for pair in claude-code:claude codex:codex opencode:opencode; do
  agent=${pair%%:*}
  command -v "${pair#*:}" >/dev/null 2>&1 || continue
  atuin hook install "$agent" >/dev/null 2>&1 ||
    echo "atuin: hook install $agent failed" >&2
  # OpenCode 2.2 does not load the server that atuin writes for it.
  [ "$agent" = opencode ] && continue
  atuin mcp install "$agent" >/dev/null 2>&1 ||
    echo "atuin: mcp install $agent failed" >&2
done
exit 0
