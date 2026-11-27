# Find processes whose name or command line matches a pattern (case-insensitive)
def psg [pattern: string] {
  let re = $"\(?i\)($pattern)"
  ps -l
  | where { |p| ($p.name =~ $re) or ($p.command =~ $re) }
  | where pid != $nu.pid
  | select pid name cpu mem command
}

# Remove every linked worktree of the repo in the current folder (the main checkout stays)
def wt-clean [--force (-f)] {
  let main = (git rev-parse --path-format=absolute --git-common-dir | str trim | path dirname)
  let paths = (
    git worktree list --porcelain | lines
    | where ($it | str starts-with "worktree ")
    | each { str replace "worktree " "" }
    | where $it != $main
  )
  for path in $paths {
    if $force { git worktree remove --force $path } else { git worktree remove $path }
    print $"removed ($path)"
  }
  git worktree prune
}
