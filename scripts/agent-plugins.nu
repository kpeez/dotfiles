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
    {
      marketplaces: ($public.marketplaces | merge ($extra.marketplaces? | default {}))
      plugins: ($public.plugins | append ($extra.plugins? | default []) | uniq)
    }
  } else {
    $public
  }
}

def claude-configured [] {
  try {
    ^claude plugin marketplace list
    | lines | str trim
    | where {|l| $l | str starts-with "❯" }
    | each {|l| $l | str replace "❯ " "" | str trim }
    | where {|l| $l =~ '^[A-Za-z0-9._-]+$' }
  } catch { [] }
}

def claude-installed [] {
  try { ^claude plugin list | lines | str trim | where {|l| $l | str starts-with "❯" } | each {|l| $l | str replace "❯ " "" | str trim } } catch { [] }
}

def codex-configured [] {
  try { ^codex plugin marketplace list | lines | skip 1 | each {|l| $l | split row " " | first } } catch { [] }
}

def codex-installed [] {
  # stderr holds remote-catalog warnings, such as an expired login; the local
  # installed list on stdout is still complete.
  try { ^codex plugin list --json err> /dev/null | from json | get installed | get pluginId } catch { [] }
}

def agy-installed [] {
  try { ^agy plugin list --json | from json | default [] | get name } catch { [] }
}

# Resolve `<plugin>@<marketplace>` to the plugin directory's GitHub tree URL
# via the local Claude marketplace checkout when present, or the GitHub API.
def agy-url [plugin: string, marketplaces: record] {
  let parts = ($plugin | split row "@")
  let name = ($parts | first)
  let mp = ($parts | last)
  let repo = ($marketplaces | get -o $mp)
  if ($repo | is-empty) {
    error make { msg: $"unknown marketplace ($mp) for ($plugin)" }
  }
  let local_mp = ($nu.home-dir | path join ".claude" "plugins" "marketplaces" $mp ".claude-plugin" "marketplace.json")
  let manifest = if ($local_mp | path exists) {
    open $local_mp
  } else {
    ^gh api -H "Accept: application/vnd.github.raw+json" $"repos/($repo)/contents/.claude-plugin/marketplace.json"
    | from json
  }
  let entry = ($manifest.plugins | where name == $name | first)
  let subpath = ($entry.source | str replace -r '^\./?' '')
  if ($subpath | is-empty) or ($subpath == ".") {
    $"https://github.com/($repo)/tree/main"
  } else {
    $"https://github.com/($repo)/tree/main/($subpath)"
  }
}

def try-run [...args: string] {
  let result = (^$args.0 ...($args | skip 1) | complete)
  if $result.exit_code != 0 {
    print $"agent-plugins: warning: ($args | str join ' ') failed: ($result.stderr | str trim)"
  }
}

def main [] {
  # Skip Git LFS smudge filters when `agy plugin install` clones repositories
  # whose plugin subdirectory sits beside LFS-tracked files elsewhere in the repo.
  $env.GIT_LFS_SKIP_SMUDGE = "1"
  let marketplace_map = (tracked | get marketplaces)
  let marketplaces = ($marketplace_map | transpose name source)
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

  if (which agy | is-empty) {
    print "agent-plugins: agy not found; skipped"
  } else {
    let installed = (agy-installed)
    for plugin in $plugins {
      let name = ($plugin | split row "@" | first)
      if $name in $installed { continue }
      print $"agent-plugins: installing agy plugin ($plugin)"
      let url = try {
        agy-url $plugin $marketplace_map
      } catch {|e|
        print $"agent-plugins: warning: resolving ($plugin) failed: ($e.msg)"
        ""
      }
      if ($url | is-not-empty) {
        try-run agy plugin install $url
      }
    }
  }
}
