#!/bin/sh
# Offline checks for the Nushell startup fixes.
#
# Uses real Nu startup so config.nu runs before user autoload files are parsed.
# Starts without env.nu or generated integrations. Leaves temporary data in
# place and prints the path.

set -eu

root=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)

if ! command -v nu >/dev/null 2>&1; then
    echo "SKIP: nu not installed"
    exit 0
fi
nu_bin=$(command -v nu)

# macOS ends TMPDIR with a slash, and Nu's glob rejects the resulting `//`.
tmpdir=${TMPDIR:-/tmp}
tmp=$(mktemp -d "${tmpdir%/}/nu-startup.XXXXXX")
echo "test data: $tmp"

config_home="$tmp/xdg/nushell"
mkdir -p "$config_home"
cp "$root/home/.config/nushell/config.nu" "$config_home/config.nu"
cp -R "$root/home/.config/nushell/autoload" "$config_home/autoload"

# The fake HOME hides mise's real config and installs, and a mise shim then
# fails with "No version is set". Point mise at the real ones.
mise_config=${MISE_CONFIG_DIR:-${XDG_CONFIG_HOME:-$HOME/.config}/mise}
mise_data=${MISE_DATA_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/mise}

# run_nu CODE [ENV=value ...]
# Start in $tmp: mise reads .config/mise/config.toml in every parent directory,
# and under the fake HOME it treats the real home's config as untrusted.
run_nu() {
    code=$1
    shift
    cd "$tmp"
    env -u MISE_SHELL -u __MISE_ORIG_PATH -u __MISE_DIFF -u __MISE_SESSION \
        MISE_CONFIG_DIR="$mise_config" MISE_DATA_DIR="$mise_data" "$@" \
        XDG_CONFIG_HOME="$tmp/xdg" HOME="$tmp" \
        "$nu_bin" --config-home "$config_home" \
        --config "$config_home/config.nu" \
        --no-history --execute "try { $code } catch {|err| print --stderr \$err; exit 1 }; exit"
}

# Counts every configured hook. Comparing counts with and without
# MISE_SKIP_ACTIVATE isolates mise's contribution from zoxide or prompt hooks.
hook_count='
    let h = ($env.config.hooks)
    let env_change = ($h.env_change? | default {})
    let env_count = (
        if ($env_change | is-empty) { 0 } else {
            ($env_change | values | each {|v| $v | length } | math sum)
        }
    )
    print (
        (($h.pre_prompt? | default []) | length)
        + (($h.pre_execution? | default []) | length)
        + $env_count
    )
'

fail=0

# 1. Startup succeeds with the real, installed tools.
if ! run_nu '
    if ($nu.env-path | path exists) { error make {msg: "startup must not require env.nu"} }
    if $env.EDITOR != "nvim" or $env.VISUAL != "nvim" or $env.PAGER != "less" {
        error make {msg: "environment settings were not loaded"}
    }
    if ($env.HOME | path join ".local/bin") not-in $env.PATH {
        error make {msg: "local tools missing from PATH"}
    }
    if (scope commands | where name == ll | is-empty) {
        error make {msg: "interactive autoload was not loaded"}
    }
    print STARTUP_OK
' > "$tmp/startup.out" 2> "$tmp/startup.err"; then
    echo "FAIL: normal startup failed"
    cat "$tmp/startup.out" "$tmp/startup.err"
    fail=1
elif ! grep -q STARTUP_OK "$tmp/startup.out"; then
    echo "FAIL: startup did not print the expected marker"
    cat "$tmp/startup.out"
    fail=1
fi

# The cached mise activation must keep the PATH of this session, not the PATH
# of the session that generated it.
if command -v mise >/dev/null 2>&1; then
    if ! run_nu '
        if ($env.HOME | path join "path-marker") not-in $env.PATH {
            error make {msg: $"PATH lost the session marker: ($env.PATH | to nuon)"}
        }
    ' "PATH=$tmp/path-marker:$PATH" > "$tmp/path.out" 2> "$tmp/path.err"; then
        echo "FAIL: cached mise activation replaced PATH"
        cat "$tmp/path.out" "$tmp/path.err"
        fail=1
    fi
fi

# atuin must load where only mise's shim reaches it, with mise active.
if command -v mise >/dev/null 2>&1 && [ -x "$mise_data/shims/atuin" ]; then
    mise_dir=$(dirname "$(command -v mise)")
    if ! run_nu '
        let shim = ($env.MISE_DATA_DIR | path join "shims" "atuin")
        if (which atuin | get 0?.path) != $shim {
            error make {msg: $"atuin did not resolve to the mise shim: (which -a atuin | to nuon)"}
        }
        if not ($env.config.keybindings | any {|k| $k.name == "atuin" }) {
            error make {msg: "atuin keybinding missing"}
        }
    ' "PATH=$mise_data/shims:$mise_dir:/usr/bin:/bin" > "$tmp/atuin.out" 2> "$tmp/atuin.err"; then
        echo "FAIL: atuin through the mise shim"
        cat "$tmp/atuin.out" "$tmp/atuin.err"
        fail=1
    fi
fi

# A tool whose init fails must not stop the rest of startup.
mkdir -p "$tmp/broken-bin"
printf '#!/bin/sh\nexit 1\n' > "$tmp/broken-bin/zoxide"
chmod +x "$tmp/broken-bin/zoxide"
rm -rf "$config_home/generated"
if ! run_nu '
    if (scope commands | where name == ll | is-empty) {
        error make {msg: "interactive autoload was not loaded"}
    }
    print BROKEN_TOOL_OK
' MISE_SKIP_ACTIVATE=1 "PATH=$tmp/broken-bin:$PATH" > "$tmp/broken.out" 2> "$tmp/broken.err"; then
    echo "FAIL: a failing integration stopped startup"
    cat "$tmp/broken.out" "$tmp/broken.err"
    fail=1
fi

# 2. MISE_SKIP_ACTIVATE must suppress mise's activation hooks.
skip_hooks=$(run_nu "$hook_count" MISE_SKIP_ACTIVATE=1 | tail -n 1)
case $skip_hooks in
    ''|*[!0-9]*) echo "FAIL: could not read hook count while skipped"; fail=1 ;;
esac
if command -v mise >/dev/null 2>&1; then
    active_hooks=$(run_nu "$hook_count" | tail -n 1)
    case $active_hooks in
        ''|*[!0-9]*) echo "FAIL: could not read hook count while active"; fail=1 ;;
    esac
    if [ "$active_hooks" -le "$skip_hooks" ]; then
        echo "FAIL: MISE_SKIP_ACTIVATE did not suppress activation hooks"
        fail=1
    fi
fi

# 3. The `mise` wrapper must reflect availability: pass through when present,
#    fail clearly when absent. Startup must still succeed either way.
if command -v mise >/dev/null 2>&1; then
    if ! run_nu '
        let out = (mise --version | str trim)
        if ($out | is-empty) { error make {msg: "mise dispatch produced no output"} }
        print DISPATCH_OK
    ' MISE_SKIP_ACTIVATE=1 > "$tmp/mise.out" 2> "$tmp/mise.err"; then
        echo "FAIL: skipped mise did not dispatch to the binary"
        cat "$tmp/mise.out" "$tmp/mise.err"
        fail=1
    fi
else
    if ! run_nu '
        let ok = (try { mise --version; true } catch { false })
        if $ok { error make {msg: "expected mise --version to fail when absent"} }
        print MISSING_OK
    ' MISE_SKIP_ACTIVATE=1 > "$tmp/mise.out" 2> "$tmp/mise.err"; then
        echo "FAIL: absent mise did not fail clearly on use"
        cat "$tmp/mise.out" "$tmp/mise.err"
        fail=1
    fi
fi

# External path completion must work without warnings when fish and carapace
# are unreachable. Use the engine so callback API deprecations are exercised.
# Start once with the installed tools, where fzf wraps the external completer,
# and once with a bare PATH, where Nu calls it directly.
for startup_path in "$PATH" /usr/bin:/bin; do
    if ! run_nu '
        let fixture = ($env.HOME | path join "completion-fixture")
        mkdir ($fixture | path join "agents")
        $env.PATH = ["/usr/bin" "/bin"]
        for command in [git somecmd] {
            let line = $"^($command) ($fixture)/ag"
            let matches = ($line | commandline complete)
            if ($matches | where {|value| $value =~ "agents[/\\\\]?$" } | is-empty) {
                error make {msg: $"path completion missing for ($line)"}
            }
        }
        print COMPLETE_OK
    ' MISE_SKIP_ACTIVATE=1 "PATH=$startup_path" > "$tmp/complete.out" 2> "$tmp/complete.err"; then
        echo "FAIL: completion threw with fish/carapace unavailable (startup PATH $startup_path)"
        cat "$tmp/complete.out" "$tmp/complete.err"
        fail=1
    elif ! grep -q COMPLETE_OK "$tmp/complete.out"; then
        echo "FAIL: completion check did not print the expected marker (startup PATH $startup_path)"
        fail=1
    elif [ -s "$tmp/complete.err" ]; then
        echo "FAIL: completion emitted diagnostics (startup PATH $startup_path)"
        cat "$tmp/complete.err"
        fail=1
    fi
done

# 5. `cd` changes the shell directory and resolves a recorded zoxide shortcut.
if command -v zoxide >/dev/null 2>&1; then
    if ! run_nu '
        cd $env.HOME
        if ($env.PWD | path expand) != ($env.HOME | path expand) {
            error make {msg: "cd did not change the shell directory"}
        }
        let target = ($env.HOME | path join "projects" "nu-zoxide-destination")
        mkdir $target
        ^zoxide add $target
        cd nu-zoxide-destination
        if ($env.PWD | path expand) != ($target | path expand) {
            error make {msg: "cd did not resolve the zoxide shortcut"}
        }
    ' MISE_SKIP_ACTIVATE=1 "_ZO_DATA_DIR=$tmp/zoxide" > "$tmp/cd.out" 2> "$tmp/cd.err"; then
        echo "FAIL: zoxide cd integration"
        cat "$tmp/cd.out" "$tmp/cd.err"
        fail=1
    fi
fi

# 6. Listing shortcuts default to the current directory and preserve glob args.
if ! run_nu '
    let fixture = ($env.HOME | path join "listing-fixture")
    mkdir ($fixture | path join "folder")
    touch ($fixture | path join "visible.txt") ($fixture | path join ".hidden")
    cd $fixture
    def check_names [rows: table, expected: list<string>] {
        let actual = ($rows | get name | path basename | sort)
        if $actual != ($expected | sort) {
            error make {msg: $"unexpected listing: ($actual | to nuon)"}
        }
    }
    check_names (ll) [.hidden folder visible.txt]
    check_names (lsa) [.hidden folder visible.txt]
    check_names (lt) [.hidden folder visible.txt]
    check_names (ld) [folder]
    check_names (lf) [visible.txt]
    check_names (ll *.txt) [visible.txt]
    check_names (lsa $fixture) [.hidden folder visible.txt]
    ^ln -s visible.txt shortcut-link
    let compact = (lsa)
    let target = ($compact | where type == symlink | get target | first)
    if $target != "visible.txt" or $target != (ll | where type == symlink | get target | first) {
        error make {msg: "lsa and ll must expose the symlink destination"}
    }
    if ($compact | columns) != [name type size modified target] {
        error make {msg: "lsa must keep its compact columns"}
    }
    if ($compact | get name) != (ls -a | get name) {
        error make {msg: "lsa must preserve ls ordering"}
    }
    let compact_ls = (ls)
    if ($compact_ls | columns) != [name type size modified target] {
        error make {msg: "ls must expose the symlink target as its final column"}
    }
    if $target != ($compact_ls | where type == symlink | get target | first) {
        error make {msg: "ls must expose the symlink destination"}
    }
    if ($compact_ls | get name | path basename | sort) != ([folder visible.txt shortcut-link] | sort) {
        error make {msg: "ls must omit hidden files unless -a is given"}
    }
    if (ls -a | get name) != ($compact | get name) {
        error make {msg: "ls -a must preserve lsa ordering"}
    }
' MISE_SKIP_ACTIVATE=1 "_ZO_DATA_DIR=$tmp/zoxide" > "$tmp/listings.out" 2> "$tmp/listings.err"; then
    echo "FAIL: listing shortcuts"
    cat "$tmp/listings.out" "$tmp/listings.err"
    fail=1
fi

if [ "$fail" -ne 0 ]; then
    exit 1
fi
echo "PASS: nushell startup, skip hooks, mise dispatch, completion guards, cd, and listings"
