#!/bin/sh
# Connect each installed coding agent to atuin. The hooks record the agent's
# shell commands with its name, and the MCP server lets the agent search
# history. Both installs are safe to repeat. This runs on every
# `mise bootstrap` (a post-tools hook in mise.toml), which picks up an agent
# installed later. Test the commands, not the agents' config folders: a folder
# can outlive its agent.

command -v atuin >/dev/null 2>&1 || exit 0

for pair in claude-code:claude codex:codex opencode:opencode; do
  agent=${pair%%:*}
  command -v "${pair#*:}" >/dev/null 2>&1 || continue
  atuin setup --only --agent-history --mcp --agents "$agent" >/dev/null 2>&1 ||
    echo "atuin: setup $agent failed" >&2
done
exit 0
