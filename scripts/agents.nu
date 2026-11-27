#!/usr/bin/env nu
# Keep each coding agent's instruction links in step with the agents that are
# installed. agent-config/agents.json lists every agent with its command and
# its links (target -> source). A source that starts with `~` lies outside the
# repository; any other source is relative to the repository root.
# `main` makes the links of each agent whose command is on PATH and removes the
# links of each agent whose command is not. A link whose source does not exist
# on this host, such as a checkout that is not cloned here, counts as absent. `main check` reports the drift.

const root = path self ..
const table = path self ../agent-config/agents.json

def home [] { $env.HOME }

def expand-home [p: string] {
  if ($p | str starts-with "~") { (home) | path join ($p | str substring 2..) } else { $p }
}

def installed [command: string] {
  which $command | where type == external | is-not-empty
}

# One row per link: the agent, whether it is installed, the link path, and its source path.
def link-rows [] {
  open $table | transpose agent spec | each {|a|
    let present = (installed $a.spec.command)
    $a.spec.links | transpose target source | each {|l|
      let source = if ($l.source | str starts-with "~") { expand-home $l.source } else { $root | path join $l.source }
      { agent: $a.agent, present: ($present and ($source | path exists)), link: (expand-home $l.target), source: $source }
    }
  } | flatten
}

# The target text of a symlink, or null when the path is not a symlink.
def link-target [p: string] {
  let r = (^readlink $p | complete)
  if $r.exit_code == 0 { $r.stdout | str trim } else { null }
}

def relative-path [from_dir: string, to: string] {
  let a = ($from_dir | path expand --no-symlink | path split)
  let b = ($to | path expand --no-symlink | path split)
  let n = ($a | zip $b | take while {|p| $p.0 == $p.1 } | length)
  let ups = (0..<(($a | length) - $n) | each { ".." })
  $ups ++ ($b | skip $n) | path join
}

# ok: the link points at the source; none: nothing at the path; other: something else is there.
def state [row: record] {
  if not ($row.link | path exists --no-symlink) { return "none" }
  let target = (link-target $row.link)
  if $target == null { return "other" }
  let resolved = ($row.link | path dirname | path join $target | path expand --no-symlink)
  if $resolved == ($row.source | path expand --no-symlink) { "ok" } else { "other" }
}

# Make the links of installed agents and remove the links of absent agents.
def main [] {
  for row in (link-rows) {
    let s = (state $row)
    if $row.present {
      match $s {
        "none" => {
          mkdir ($row.link | path dirname)
          ^ln -s (relative-path ($row.link | path dirname) $row.source) $row.link
          print $"agents: linked ($row.link) for ($row.agent)"
        }
        "other" => { print -e $"agents: ($row.link) exists and is not this agent's link; left alone" }
        _ => {}
      }
    } else {
      match $s {
        "ok" => {
          rm $row.link
          print $"agents: removed ($row.link) for absent ($row.agent)"
          let dir = ($row.link | path dirname)
          if $dir != (home) and (ls -a $dir | is-empty) {
            rmdir $dir
            print $"agents: removed empty folder ($dir)"
          }
        }
        "other" => { print -e $"agents: ($row.link) is not this agent's link; left alone" }
        _ => {}
      }
    }
  }
}

# Fail when an installed agent lacks a link or an absent agent keeps one.
def "main check" [] {
  let problems = (link-rows | each {|row|
    let s = (state $row)
    if $row.present and $s != "ok" {
      $"($row.agent) is installed but ($row.link) is not its link"
    } else if (not $row.present) and $s == "ok" {
      $"($row.agent) is absent but ($row.link) is still linked"
    }
  } | compact)
  if ($problems | is-not-empty) {
    error make --unspanned { msg: ($problems | str join "\n") }
  }
}
