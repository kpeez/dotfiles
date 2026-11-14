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
# An agent counts as installed when its command is on PATH or its config
# folder exists. The background tool-update service runs postinstall with
# only the system PATH, where no agent command is found, but the folder that
# holds the hooks is still there.

command -v atuin >/dev/null 2>&1 || exit 0

for entry in claude-code:claude:.claude codex:codex:.codex \
  opencode:opencode:.config/opencode; do
  agent=${entry%%:*}
  rest=${entry#*:}
  command -v "${rest%%:*}" >/dev/null 2>&1 || [ -d "$HOME/${rest#*:}" ] ||
    continue
  atuin hook install "$agent" >/dev/null 2>&1 ||
    echo "atuin: hook install $agent failed" >&2
  # OpenCode 2.2 does not load the server that atuin writes for it.
  [ "$agent" = opencode ] && continue
  atuin mcp install "$agent" >/dev/null 2>&1 ||
    echo "atuin: mcp install $agent failed" >&2
done
exit 0
