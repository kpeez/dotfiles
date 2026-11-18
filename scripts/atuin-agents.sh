#!/bin/sh
# Connect each installed coding agent to atuin. The hooks record the agent's
# shell commands with its name, and the MCP server lets the agent search
# history. Both installs are safe to repeat. This runs on every
# `mise bootstrap` (a post-tools hook in mise.toml), which picks up an agent
# installed later, and as atuin's postinstall in the global mise config.
# On Linux, `atuin hook install` writes its resolved version folder into
# Claude Code's hooks, and an upgrade deletes that folder; during postinstall,
# `atuin` is the new version, so the reinstall writes the new path.
# `sh scripts/atuin-agents.sh check` (the atuin-agent-paths doctor check) fails
# when any agent config names an atuin that no longer exists.
#
# The background tool-update service runs postinstall with only the system
# PATH, so look for agents where they are installed too: Claude Code's own
# installer and the mise shims. Append them, so `atuin` stays the new version.
# Test the commands, not the agents' config folders: a folder can outlive its
# agent.

PATH="$PATH:$HOME/.local/bin:$HOME/.local/share/mise/shims"

# check: every atuin path in an agent config must be an executable file.
if [ "${1:-}" = check ]; then
  missing=$(
    for f in "$HOME/.claude/settings.json" "$HOME/.codex/config.toml" "$HOME/.config/opencode/opencode.json"; do
      [ -f "$f" ] || continue
      grep -oE '/[^" ]*/installs/atuin/[^" ]*/atuin' "$f" | sort -u | while read -r p; do
        [ -x "$p" ] || echo "$f names $p, which does not exist"
      done
    done
  )
  [ -z "$missing" ] && exit 0
  echo "$missing" >&2
  exit 1
fi

command -v atuin >/dev/null 2>&1 || exit 0

for pair in claude-code:claude codex:codex opencode:opencode; do
  agent=${pair%%:*}
  command -v "${pair#*:}" >/dev/null 2>&1 || continue
  atuin hook install "$agent" >/dev/null 2>&1 ||
    echo "atuin: hook install $agent failed" >&2
  atuin mcp install "$agent" >/dev/null 2>&1 ||
    echo "atuin: mcp install $agent failed" >&2
done
exit 0
