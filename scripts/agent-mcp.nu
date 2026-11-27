#!/usr/bin/env nu
# Add the Claude Code user-scope MCP servers in agent-config/mcp.json to this
# host. Each entry is the JSON that `claude mcp add-json` takes. A missing
# server is added; a server with a different entry is removed and added again;
# a server not in the list is left alone. Idempotent. A failure only prints a
# warning; `mise bootstrap` runs this via scripts/plugins.sh.

const manifest = path self ../agent-config/mcp.json
const private_manifest = path self ../private/agent-config/mcp.json

# A host's private overlay can add servers the public repo must not name; they
# merge on top of the public list, and the private entry wins.
def tracked [] {
  let public = open $manifest
  if ($private_manifest | path exists) {
    $public | merge (open $private_manifest)
  } else {
    $public
  }
}

# `claude mcp list` runs health checks and takes ~20 s, so read the file.
def current [] {
  let dir = ($env.CLAUDE_CONFIG_DIR? | default $nu.home-dir)
  let file = ($dir | path join ".claude.json")
  if ($file | path exists) {
    open $file | get -o mcpServers | default {}
  } else {
    {}
  }
}

def --wrapped try-run [...args: string] {
  let result = (^$args.0 ...($args | skip 1) | complete)
  if $result.exit_code != 0 {
    print $"agent-mcp: warning: ($args | str join ' ') failed: ($result.stderr | str trim)"
  }
}

def main [] {
  if (which claude | is-empty) { return }
  let have = (current)
  for server in (tracked | transpose name entry) {
    let existing = ($have | get -o $server.name)
    # Nushell compares records without regard to key order.
    if $existing == $server.entry { continue }
    if $existing != null {
      print $"agent-mcp: replacing claude mcp server ($server.name)"
      try-run claude mcp remove -s user $server.name
    } else {
      print $"agent-mcp: adding claude mcp server ($server.name)"
    }
    try-run claude mcp add-json -s user $server.name ($server.entry | to json -r)
  }
}
