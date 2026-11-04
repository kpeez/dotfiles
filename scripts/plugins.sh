#!/bin/sh
# Install the shell and tmux plugin managers and sync their plugin lists,
# register the Nu plugins, then install the listed agent skills.
# `mise bootstrap` runs this after the tools (a post-tools hook in mise.toml). Every step is safe to repeat. A step whose
# tool is missing is skipped, and a failed step only prints a warning.

root=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
warn() { echo "plugins: $*" >&2; }

# fish_plugins lists Fisher itself, so `fisher update` installs or updates it.
# Fisher reads plugin names from stdin when stdin is not a terminal, so stdin
# is /dev/null to make it use fish_plugins. Fisher reinstalls every plugin on
# each run, so its file list says nothing about what changed and is dropped.
if command -v fish >/dev/null 2>&1; then
    fish -c 'type -q fisher; or curl -fsSL https://raw.githubusercontent.com/jorgebucaran/fisher/main/functions/fisher.fish | source; and fisher update' </dev/null >/dev/null ||
        warn "fisher update failed"
fi

if command -v tmux >/dev/null 2>&1; then
    tpm="$HOME/.tmux/plugins/tpm"
    [ -d "$tpm" ] || git clone --quiet https://github.com/tmux-plugins/tpm "$tpm" ||
        warn "TPM clone failed"
    [ -x "$tpm/bin/install_plugins" ] && { "$tpm/bin/install_plugins" >/dev/null ||
        warn "tmux plugin install failed"; }
fi

# parquet needs a cargo install that matches the Nu version; see docs/reference.md.
if command -v nu >/dev/null 2>&1; then
    nu "$root/scripts/nu-plugins.nu" || warn "Nu plugin registration incomplete"
fi

# A bootstrap that installs npm:skills does not put it on this hook's PATH,
# so the install runs through mise exec.
mise=$(command -v mise || echo "$HOME/.local/bin/mise")
if ! command -v nu >/dev/null 2>&1; then
    warn "nu not found; agent skills not installed"
elif [ -x "$mise" ]; then
    "$mise" exec npm:skills -- nu "$root/scripts/skills.nu" </dev/null ||
        warn "agent skill install incomplete"
elif command -v skills >/dev/null 2>&1; then
    nu "$root/scripts/skills.nu" </dev/null || warn "agent skill install incomplete"
else
    warn "skills CLI not found; agent skills not installed"
fi
exit 0
