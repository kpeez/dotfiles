#!/usr/bin/env nu
# Keep the global agent skills that the skills CLI (`npx skills add -g`)
# installs in step with agent-config/skills.json. The CLI's own lock file
# records each install, but it holds timestamps and hashes that change on
# every install, so the repository keeps only names and sources.

const root = path self ..
const manifest = path self ../agent-config/skills.json

def lock-path [] {
  if ($env.XDG_STATE_HOME? | is-not-empty) {
    $env.XDG_STATE_HOME | path join skills .skill-lock.json
  } else {
    $nu.home-dir | path join .agents .skill-lock.json
  }
}

def locked [extra: list<path> = []] {
  [(lock-path)] ++ $extra
  | where {|lock| $lock | path exists }
  | each {|lock| open --raw $lock | from json | get skills | transpose name entry }
  | flatten | uniq-by name
}

def listed [] { open $manifest | get skills | transpose name source }

# A tree URL keeps the branch that a lock entry was installed from.
def source-of [entry: record] {
  if $entry.sourceType == github and ($entry.ref? | is-not-empty) {
    [https://github.com $entry.source tree $entry.ref ($entry.skillPath | path dirname)]
    | where {|part| $part != "" } | str join /
  } else {
    $entry.source
  }
}

def unrecorded [extra: list<path> = []] {
  let names = (listed | get name)
  locked $extra | where name not-in $names
}

# Install each listed skill that the lock does not hold yet.
def main [] {
  let have = (locked | get name)
  let agents = (open $manifest | get agents | each {|agent| [--agent $agent] } | flatten)
  let missing = (listed | where name not-in $have)
  for skill in $missing {
    print $"skills: installing ($skill.name) from ($skill.source)"
    ^npx --yes skills add $skill.source --skill $skill.name --global ...$agents --yes
  }
}

# Merge the lock into the manifest. Returns the recorded skills; rewrites the
# manifest only when something changed.
def record-merge [locks: list<path>] {
  let new = (unrecorded $locks | each {|row| { name: $row.name, source: (source-of $row.entry) } })
  let doc = (open $manifest)
  let skills = ((listed) ++ $new | sort-by name | reduce --fold {} {|row, acc| $acc | insert $row.name $row.source })
  let updated = ($doc | update skills $skills)
  if ($updated != $doc) {
    $updated | to json --indent 2 | $"($in)\n" | save --force $manifest
  }
  $new
}

# Add each skill in this host's lock, or in the given lock files, that the
# manifest does not list.
def "main record" [...locks: path] {
  let new = (record-merge $locks)
  if ($new | is-empty) { return }
  print $"skills: recorded ($new | length): ($new | get name | str join ', ')"
}

# Record, then commit the manifest locally when a new skill was recorded. The
# push happens on the next `mise run sync`.
def "main record-commit" [...locks: path] {
  let new = (record-merge $locks)
  if ($new | is-empty) { return }
  ^git -C $root add ($root | path join agent-config/skills.json)
  ^git -C $root commit -q -m "chore(agent-config): record agent skills" -- agent-config/skills.json
  print $"skills: committed agent-config/skills.json \(($new | get name | str join ', ')\)"
}

# Fail when the lock holds a skill that the manifest does not list.
def "main check" [] {
  let new = (unrecorded | get name)
  if ($new | is-not-empty) {
    error make --unspanned { msg: $"not in agent-config/skills.json: ($new | str join ', ')" }
  }
}
