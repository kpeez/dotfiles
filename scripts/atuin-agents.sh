#!/bin/sh
# Connect each installed coding agent to atuin. The hooks record the agent's
# shell commands with its name, and the MCP server lets the agent search
# history. Both installs skip what is already there, so this runs on every
# `mise bootstrap` (a post-tools hook in mise.toml) and picks up an agent
# installed later.

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
