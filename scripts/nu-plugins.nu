#!/usr/bin/env nu
# Register the Nu plugins every host should have.
#
# polars and query ship with Nu's brew formula and distro package, and must
# match the Nu version. parquet is a separate crate, installed with cargo.
# Run this after installing or upgrading Nu or a plugin. Registration is
# idempotent: a plugin that already points at the binary found here is kept.

const plugins = [polars parquet query]

# Directories that can hold plugin binaries, best match first: next to the
# running Nu (brew keeps its plugins there), the distro plugin directory, then
# cargo and the user bin directory.
def search-dirs [] {
  [
    ($nu.current-exe | path dirname)
    /usr/libexec/nushell
    ($nu.home-dir | path join .cargo/bin)
    ($nu.home-dir | path join .local/bin)
  ] ++ $env.PATH | where {|dir| $dir | path exists } | uniq
}

def main [
  --force # Register again even when the plugin already points at the binary
] {
  let dirs = (search-dirs)
  let registered = (plugin list | select name filename)

  let rows = $plugins | each {|name|
    let found = ($dirs | each {|dir| $dir | path join $"nu_plugin_($name)" } | where {|path| $path | path exists } | get 0?)
    if $found == null {
      return { plugin: $name, state: missing, path: "" }
    }
    # Nu records the resolved path, so a brew symlink must be resolved to compare.
    let bin = ($found | path expand)
    let current = ($registered | where name == $name | get filename.0?)
    if not $force and $current == $bin {
      return { plugin: $name, state: kept, path: $bin }
    }
    plugin add $bin
    { plugin: $name, state: registered, path: $bin }
  }

  $rows | where state != kept | each {|row| print $"nu plugin: ($row.state) ($row.plugin) ($row.path)" } | ignore
  let missing = ($rows | where state == missing | get plugin)
  if ($missing | is-not-empty) {
    error make --unspanned {
      msg: $"missing plugin binaries: ($missing | str join ', '). Install Nu's plugins with the package manager, or build them with cargo; see docs/setup.md."
    }
  }
}
