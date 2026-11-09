# Interactive commands and integrations, loaded after config.nu has generated
# the integration files. Keep fzf last so it wraps the external completer.
# See https://www.nushell.sh/book/configuration.html

# TUI replacements and frequently used command shortcuts.
alias grep = rg
alias cat = bat
# Keep listings as Nu tables, including when using the familiar shortcuts.
# Nu lists nothing for an empty spread, so default to the current directory.
# Entries that cannot be stat'ed, which is how Synology hides its internal @*
# directories from NFS clients and how stale mounts surface, come back as
# reduced rows without the optional columns. Probe for those columns and label
# the row instead of losing the whole listing to `select`.
def ls_entries [...paths: glob, --all(-a)] {
  let paths = ($paths | default --empty [.])
  if $all { ls -al ...$paths } else { ls -l ...$paths }
  | update type {|row| $row.type | default 'unreadable' }
  | select name type size modified target?
  | ls_mounts
}

# Directories that are their own filesystem, which is how NFS, autofs and any
# other mount shows up in a listing, are annotated with the source they come
# from plus the size and usage of that filesystem. `df` reports the same
# numbers for every path on a filesystem, so only mount points can be told
# apart, and the extra columns stay empty for everything else.
def ls_mounts [] {
  let table = ($in | insert path {|row| $row.name | path expand})
  let dirs = ($table | where type == dir | get path)
  if ($dirs | is-empty) { return ($table | reject path) }

  let fs = (
    ^df -h --output=source,target,size,used,avail,pcent -- ...$dirs | complete | get stdout
    | from ssv --noheaders --minimum-spaces 1
    | skip 1
    | rename source target fssize fsused fsavail fsuse
    | where target in $dirs
    | rename --column {target: path}
  )
  if ($fs | is-empty) { return ($table | reject path) }

  $table | join --left $fs path | reject path
}

def ld [...paths: glob] { ls ...($paths | default --empty [.]) | where type == dir }
def lf [...paths: glob] { ls ...($paths | default --empty [.]) | where type != dir }
def ll [...paths: glob] { ls -al ...($paths | default --empty [.]) | sort-by type name }
def lsa [...paths: glob] { ls_entries ...($paths | default --empty [.]) -a }
def lt [...paths: glob] { ls -a ...($paths | default --empty [.]) | sort-by modified }
# Keep the familiar `ls`, with the symlink target as the final column. A wrapper
# plus alias avoids a `def ls` calling itself; `-a` and `-l` stay accepted for
# muscle memory, and `-l` is already implied by the long listing.
def ls_long [...paths: glob, --all(-a), --long(-l)] {
  ls_entries ...($paths | default --empty [.]) --all=$all
}
alias ls = ls_long

alias gst = git status
alias ga = git add
alias gs = git switch
alias gbr = git branch
alias gpl = git pull
alias gps = git push
alias gf = git fetch
alias gcm = git commit

# Wrapped commands preserve their default flags while accepting the wrapped
# command's normal arguments, including flags unknown to Nushell.
def --wrapped uvipython [...args] { ^uv run --with ipython ipython ...$args }
def --wrapped omp [...args] { ^oh-my-posh ...$args }
# OSC 52 reaches the local clipboard on every host, including over ssh and
# inside tmux (set-clipboard on), with no pbcopy or wl-copy dependency.
use std/clip
alias pbc = clip copy52

# Shared tools and prompt; Fish remains the account login shell.
source ($nu.default-config-dir | path join "generated/atuin.nu")
use ($nu.default-config-dir | path join "generated/mise-activation.nu")
source ($nu.default-config-dir | path join "generated/oh-my-posh.nu")
source ($nu.default-config-dir | path join "generated/zoxide.nu")
source ($nu.default-config-dir | path join "generated/worktrunk.nu")

# External completers: carapace by default, fish where carapace is wrong or missing.
# See https://www.nushell.sh/cookbook/external_completers.html
let fish_completer = {|spans|
  if (which fish | is-empty) { return null }
  fish --command $"complete '--do-complete=($spans | str replace --all "'" "\\'" | str join ' ')'"
  | from tsv --flexible --noheaders --no-infer
  | rename value description
  | update value {|row|
    let value = $row.value
    let need_quote = ['\' ',' '[' ']' '(' ')' ' ' '\t' "'" '"' "`"] | any {$in in $value}
    if ($need_quote and ($value | path exists)) {
      let expanded_path = if ($value starts-with ~) {$value | path expand --no-symlink} else {$value}
      $'"($expanded_path | str replace --all "\"" "\\\"")"'
    } else {$value}
  }
}

let carapace_completer = {|spans: list<string>|
  if (which carapace | is-empty) { return null }
  CARAPACE_LENIENT=1 carapace $spans.0 nushell ...$spans | from json
}

# Fish's Git completions only emit semantic matches such as branches and
# modified files. Fall back to Nu's path completer when Fish has no match.
let git_completer = {|spans|
  let completions = do $fish_completer $spans
  if ($completions | is-empty) { null } else { $completions }
}

# mise is internal (mise's own Nu activation wrapper), so the external completer
# never sees it. Bridge its args to fish's bundled mise completions instead.
def "nu-complete mise" [buffer: string, place: record] {
  if (which fish | is-empty) { return [] }
  let line = ($buffer | str substring ..<$place.cursor | str replace --regex '\n+$' '')
  fish --command $"complete '--do-complete=($line | str replace --all "'" "\\'" )'"
  | from tsv --flexible --noheaders --no-infer
  | rename value description
}

def --env --wrapped mise [...args: string@"nu-complete mise"] {
  if ($args | is-empty) {
    mise-activation
  } else {
    mise-activation $args.0 ...($args | skip 1)
  }
}

# Nu 0.116 binds completer input by parameter name and deprecates a positional
# `spans`; Nu 0.115 passes the token list positionally. Accept both while a
# host still runs 0.115.
let external_completer = {|place|
  let spans = if ($place | describe) =~ '^list' { $place } else { $place.command }
  let expanded_alias = scope aliases | where name == $spans.0 | get -o 0.expansion

  let spans = if $expanded_alias != null {
    ($expanded_alias | split row ' ') ++ ($spans | skip 1)
  } else {
    $spans
  }

  match $spans.0 {
    # Carapace completions are incorrect for nu; fish handles git branches/commits better.
    nu => $fish_completer
    git => $git_completer
    _ => $carapace_completer
  } | do $in $spans
}

$env.config.completions.external = {
  enable: true
  max_results: 100
  completer: $external_completer
}

# fzf's Nu integration: Ctrl-R history, Ctrl-T files, Alt-C directories.
# Source it after the external completer above so fzf's `**` wrapper composes
# with carapace/fish instead of replacing it.
$env.FZF_DEFAULT_COMMAND = "fd --type f --strip-cwd-prefix --hidden --exclude .git"
# The Nu bindings ignore FZF_DEFAULT_COMMAND and use fzf's walker unless these are set.
$env.FZF_CTRL_T_COMMAND = $env.FZF_DEFAULT_COMMAND
$env.FZF_ALT_C_COMMAND = "fd --type d --strip-cwd-prefix --hidden --exclude .git"
$env.FZF_CTRL_T_OPTS = "--preview 'bat --color=always --style=numbers --line-range=:300 {}'"
$env.FZF_ALT_C_OPTS = "--preview 'eza --tree --level=2 --color=always {}'"
# An empty FZF_CTRL_R_COMMAND leaves Ctrl-R to atuin wherever atuin's init bound it.
if ($env.config.keybindings | any {|k| $k.name == "atuin" }) {
  $env.FZF_CTRL_R_COMMAND = ""
}
source ($nu.default-config-dir | path join "generated/fzf.nu")
