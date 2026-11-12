#!/usr/bin/env nu
# Register the marketplaces in agent-config/plugins.json with each agent on
# this host and install the listed plugins. Idempotent: a marketplace or
# plugin the agent already has is left alone. A failure only prints a
# warning; `mise bootstrap` runs this via scripts/plugins.sh.

const manifest = path self ../agent-config/plugins.json
const private_manifest = path self ../private/agent-config/plugins.json

# A host's private overlay can add marketplaces and plugins the public repo
# must not name; they merge on top of the public list.
def tracked [] {
  let public = open $manifest
  if ($private_manifest | path exists) {
    let extra = open $private_manifest
    { marketplaces: ($public.marketplaces | merge $extra.marketplaces), plugins: ($public.plugins | append $extra.plugins) }
  } else {
    $public
  }
}

def claude-configured [] {
  ^claude plugin marketplace list | lines | str trim | where {|l| $l | str starts-with "❯" } | each {|l| $l | str replace "❯ " "" | str trim }
}

def claude-installed [] {
  ^claude plugin list | lines | str trim | where {|l| $l | str starts-with "❯" } | each {|l| $l | str replace "❯ " "" | str trim }
}

def codex-configured [] {
  ^codex plugin marketplace list | lines | skip 1 | each {|l| $l | split row " " | first }
}

def codex-installed [] {
  try { ^codex plugin list --json | from json | get installed | get pluginId } catch { [] }
}

def try-run [...args: string] {
  let result = (^$args.0 ...($args | skip 1) | complete)
  if $result.exit_code != 0 {
    print $"agent-plugins: warning: ($args | str join ' ') failed: ($result.stderr | str trim)"
  }
}

def main [] {
  let marketplaces = (tracked | get marketplaces | transpose name source)
  let plugins = (tracked | get plugins)

  if (which claude | is-empty) {
    print "agent-plugins: claude not found; skipped"
  } else {
    let configured = (claude-configured)
    for m in $marketplaces {
      if $m.name in $configured { continue }
      print $"agent-plugins: adding claude marketplace ($m.name) from ($m.source)"
      try-run claude plugin marketplace add $m.source
    }
    let installed = (claude-installed)
    for plugin in $plugins {
      if $plugin in $installed { continue }
      print $"agent-plugins: installing claude plugin ($plugin)"
      try-run claude plugin install $plugin
    }
  }

  if (which codex | is-empty) {
    print "agent-plugins: codex not found; skipped"
  } else {
    let configured = (codex-configured)
    for m in $marketplaces {
      if $m.name in $configured { continue }
      print $"agent-plugins: adding codex marketplace ($m.name) from ($m.source)"
      try-run codex plugin marketplace add $m.source
    }
    let installed = (codex-installed)
    for plugin in $plugins {
      if $plugin in $installed { continue }
      print $"agent-plugins: installing codex plugin ($plugin)"
      try-run codex plugin add $plugin
    }
  }
}
