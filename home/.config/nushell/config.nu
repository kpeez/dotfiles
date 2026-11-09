# Environment, Nushell settings, and integration generation.
# Interactive commands and integrations load next from autoload/interactive.nu.
# See https://www.nushell.sh/book/configuration.html

$env.config.show_banner = false
$env.config.completions.algorithm = "fuzzy"

# Keep locally installed tools and Homebrew available in every Nushell session.
# Homebrew only lives at /opt/homebrew on macOS; other hosts skip those entries.
let brew_paths = if ("/opt/homebrew/bin" | path exists) {
  [ "/opt/homebrew/bin" "/opt/homebrew/sbin" ]
} else {
  []
}

# mise shims, except where MISE_SKIP_ACTIVATE says shims and activation are too
# slow; the host's login environment puts mise's bin directories on PATH itself.
let mise_shims = if ($env.MISE_SKIP_ACTIVATE? == null) {
  [ ($env.HOME | path join ".local/share/mise/shims") ]
} else {
  []
}

# Prepend only directories not already on PATH, so the order a login profile
# set (such as a cluster profile that puts mise's directories first) survives, as with Fish's
# fish_add_path.
let additions = [
  ...$mise_shims
  ...$brew_paths
  ($env.HOME | path join ".local/bin")
  ($env.HOME | path join ".docker/bin")
  ($env.HOME | path join ".cargo/bin")
]
$env.PATH = (($additions | where {|dir| $dir not-in $env.PATH }) ++ $env.PATH | uniq)

# App CLI shims (zed, code, cursor) live in /usr/local/bin; keep it last so
# Homebrew and mise take precedence.
if ("/usr/local/bin" | path exists) and ("/usr/local/bin" not-in $env.PATH) {
  $env.PATH = ($env.PATH ++ ["/usr/local/bin"])
}

# Atuin's output capture runs the shell inside `atuin pty-proxy`. Its generated
# init starts the proxy only after the whole startup, which then runs again in
# the proxy's Nu. Start the proxy here, once PATH can find atuin. The proxy sets
# SHELL to Nu, so carry the login shell through it and put it back.
if (is-terminal --stdin) and (is-terminal --stdout) and (which atuin | is-not-empty) {
  let answer = (do -i { ^atuin __internal pty-proxy-active } | complete | get stdout | str trim)
  if $answer == "0" and ($env.ATUIN_PTY_PROXY_FAILED? == null) {
    $env.ATUIN_OUTER_SHELL = ($env.SHELL? | default "")
    exec atuin pty-proxy --shell $nu.current-exe ...(if $nu.is-login { [--shell -l] } else { [] })
  }
  # A record is not exported, so each child Nu checks again, as atuin's init does.
  $env.__atuin_pty_proxy = { owns_tty: (if $answer == "1" { true } else if $answer == "0" { false } else { null }) }
}
if ($env.ATUIN_OUTER_SHELL? | default "" | is-not-empty) {
  $env.SHELL = $env.ATUIN_OUTER_SHELL
}

$env.EDITOR = "nvim"
$env.VISUAL = $env.EDITOR
$env.PAGER = "less"
$env.RCLONE_PROGRESS = "true"
$env.RIPGREP_CONFIG_PATH = ($env.HOME | path join ".config/ripgrep/ripgreprc")
$env.MANPAGER = "sh -c 'col -bx | bat -l man -p'"
$env.ICLOUD_DIR = ($env.HOME | path join "Library/Mobile Documents/com~apple~CloudDocs")

# Generate tool integrations before autoload/interactive.nu is parsed. Nu
# resolves `source` and `use` targets at parse time, so each referenced file
# must exist even on a host where the tool is missing.
let generated_dir = ($nu.default-config-dir | path join "generated")
if not ($generated_dir | path exists) {
  mkdir $generated_dir
}

# Rebuild a generated file only when its key changes. Each tool costs a process
# start, about 1 s on a cluster's network filesystem, so most starts reuse the files.
# The key names the resolved tool binary with its modification time (an
# upgrade changes one or the other), the Nu version, and this file's
# modification time (an edit here rebuilds all).
let config_stamp = (ls -D ($nu.config-path | path expand) | get 0.modified | format date "%s")
let nu_version = (version)
let refresh = {|name: string, key: string, generate: closure|
  let file = ($generated_dir | path join $"($name).nu")
  let header = $"# key: ($key) nu ($nu_version.version) config ($config_stamp)"
  let current = ($file | path exists) and ((open --raw $file | lines | get 0? | default "") == $header)
  if not $current {
    # A failed init must not stop startup: later files would never be written,
    # and Nu cannot parse interactive.nu without them. Keep any older copy; a
    # placeholder has no key line, so the next start tries again.
    try {
      [$header (do $generate)] | str join (char newline) | save --force $file
    } catch {|err|
      print --stderr $"($name) integration not generated: ($err.msg)"
      if not ($file | path exists) {
        $"# ($name) integration failed to generate" | save $file
      }
    }
  }
}
# The resolved binary path, or "" when the tool is not installed. A mise shim
# resolves to mise itself, so name the tool's current install directory
# instead; mise repoints `latest` there on every upgrade. Pass `install` when
# mise's tool name differs from the binary name.
let stamp = {|path: string| $"($path)@(ls -D $path | get 0.modified | format date '%s')" }
let mise_installs = ($env.MISE_DATA_DIR? | default ($env.HOME | path join ".local/share/mise") | path join "installs")
let tool = {|name: string, install?: string|
  let found = (which $name | where type == external)
  if ($found | is-empty) { return "" }
  let resolved = ($found.0.path | path expand)
  let latest = ($mise_installs | path join ($install | default $name) "latest")
  if ($resolved | path basename) == "mise" and $name != "mise" and ($latest | path exists) {
    $latest | path expand
  } else {
    $resolved
  }
}

# mise. The generated module is named after its file, so it must export `main`
# rather than a command of the same name. Three cases:
#   - available and enabled: the real activation module (installs hooks);
#   - available but MISE_SKIP_ACTIVATE is set: dispatch to `mise` with no hooks;
#   - absent: a clear error when `mise` is used explicitly.
let mise_bin = (do $tool mise)
if ($mise_bin | is-empty) {
  do $refresh mise-activation absent { 'export def main [...args] { error make {msg: "mise is not installed"} }' }
} else if ($env.MISE_SKIP_ACTIVATE? != null) {
  do $refresh mise-activation "skip" { 'export def main [...args] { ^mise ...$args }' }
} else {
  # activate embeds the PATH, original PATH and environment diff of the
  # session that ran it. Drop them so a cached copy cannot restore them; mise's
  # pre_prompt hook computes them from the live environment.
  do $refresh mise-activation (do $stamp $mise_bin) {
    ^mise activate nu
    | str replace --regex `(?m)^\s*\$env\.__MISE_ORIG_PATH = r#'[^\n]*\n` ''
    | str replace --regex `(?m)^\s*\$env\.PATH = \(r#'[^\n]*\n` ''
    | str replace --regex `(?m)^\s*'[^']*' \| parse vars \| update-env\n` ''
  }
}

# Prompt and tool integrations. An absent tool leaves a comment-only module;
# Nu then falls back to its default prompt and keeps core commands working.
let theme = ($env.HOME | path join ".config/oh-my-posh/current_theme.omp.json")
let omp_bin = (do $tool oh-my-posh)
if ($omp_bin | is-empty) {
  do $refresh oh-my-posh absent { "# oh-my-posh not installed; default prompt in use" }
} else {
  # init's output depends on the theme (transient prompt and similar), so the
  # theme files' times join the key. It also embeds a session ID; replace it
  # with an expression so each Nu session still gets its own.
  let theme_files = (glob ($env.HOME | path join ".config/oh-my-posh/**/*.json"))
  let theme_stamp = if ($theme_files | is-empty) { "none" } else {
    # Resolve the dotfile symlinks: ls reports a symlink's own time.
    ls -D ...($theme_files | path expand) | get modified | math max | format date "%s"
  }
  do $refresh oh-my-posh $"(do $stamp $omp_bin) theme ($theme_stamp)" {
    ^oh-my-posh init nu --print --config $theme
    | str replace --regex '\$env\.POSH_SESSION_ID = "[^"]*"' '$$env.POSH_SESSION_ID = (random uuid)'
  }
}
let zoxide_bin = (do $tool zoxide)
if ($zoxide_bin | is-empty) {
  do $refresh zoxide absent { "# zoxide not installed; no directory integration" }
} else {
  do $refresh zoxide (do $stamp $zoxide_bin) { ^zoxide init nushell --cmd cd }
}
# A program cannot change its parent shell's directory, so `wt switch` needs
# this wrapper to cd into the worktree.
let wt_bin = (do $tool wt worktrunk)
if ($wt_bin | is-empty) {
  do $refresh worktrunk absent { "# worktrunk not installed; no wt wrapper" }
} else {
  do $refresh worktrunk (do $stamp $wt_bin) { ^wt config shell init nu }
}
let atuin_bin = (do $tool atuin)
if ($atuin_bin | is-empty) {
  do $refresh atuin absent { "# atuin not installed; fzf keeps Ctrl-R history search" }
} else {
  # init's output depends on config.toml (pty_proxy adds a preamble), so its
  # time joins the key. Resolve the dotfile symlink: ls reports a symlink's own time.
  let atuin_config = ($env.ATUIN_CONFIG_DIR? | default ($env.HOME | path join ".atuin") | path join "config.toml")
  let atuin_config_stamp = if ($atuin_config | path exists) {
    ls -D ($atuin_config | path expand) | get 0.modified | format date "%s"
  } else { "none" }
  # init warms atuin's search index in a Nu job, and Nu refuses `exit` while a
  # job runs. Run the warmup as a detached process instead.
  do $refresh atuin $"(do $stamp $atuin_bin) config ($atuin_config_stamp)" {
    ^atuin init nu
    | str replace --regex `(?s)job spawn \{\s*atuin __internal prepare-search-index \| complete\s*\} \| ignore` r#'^sh -c 'atuin __internal prepare-search-index > /dev/null 2>&1 &''#
  }
}
let fzf_bin = (do $tool fzf)
if ($fzf_bin | is-empty) {
  do $refresh fzf absent { "# fzf not installed; no fuzzy completion" }
} else {
  do $refresh fzf (do $stamp $fzf_bin) {
    let integration = (^fzf --nushell)
    # fzf 0.74.4 still registers a positional completer. Nu 0.116+ binds
    # completion parameters by name; keep fzf's internal list-based calls intact.
    # Match only the legacy wrapper so an upstream migration passes through.
    if $nu_version.major > 0 or $nu_version.minor >= 116 {
      $integration | str replace 'let fzf_wrapper_completer = {|spans|' 'let fzf_wrapper_completer = {|place| let spans = $place.command;'
    } else {
      $integration
    }
  }
}
