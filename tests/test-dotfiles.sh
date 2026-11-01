#!/bin/sh
# Offline test of the [dotfiles] entries in mise.toml and its mise.<env>.toml
# files. Copies the tracked files to a temp HOME, runs `mise dot apply` for a
# host on this OS (auto_env in .miserc.toml), for each OS by MISE_ENV, and
# for a Linux host with a private overlay (see docs/private-overlay.md), and
# checks which targets exist. Needs mise on PATH. Removes its temp data.

set -eu

root=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
tmpdir=${TMPDIR:-/tmp}
tmp=$(mktemp -d "${tmpdir%/}/dotfiles.XXXXXX")
trap 'rm -rf "$tmp"' EXIT

fail=0
case $(uname -s) in
    Darwin) os=macos ;;
    *) os=linux ;;
esac

apply_for() {
    home="$tmp/$1"
    mkdir -p "$home/.dotfiles"
    (cd "$root" && git ls-files -z --cached --others --exclude-standard |
        tar --null -T - -cf -) | tar -C "$home/.dotfiles" -xf -
    [ "${3:-}" != overlay ] || make_overlay "$home/.dotfiles"
    (
        cd "$home/.dotfiles"
        export HOME="$home"
        unset MISE_ENV MISE_AUTO_ENV MISE_CONFIG_DIR MISE_GLOBAL_CONFIG_FILE
        [ -z "$2" ] || export MISE_ENV="$2"
        # Simulate an OS by name: turn off the host's own platform file.
        case $2 in macos | linux*) export MISE_AUTO_ENV=false ;; esac
        mise trust -q --all >/dev/null
        mise -q dot apply -y >/dev/null
    )
}

# A stand-in for the private repository: one group, one disabled public entry,
# linked in as mise.<env>.local.toml the way a real overlay is.
make_overlay() {
    mkdir -p "$1/private/work/.config/work"
    echo 'work=1' > "$1/private/work/.config/work/env"
    cat > "$1/private/mise.work.toml" <<'TOML'
[dotfile_groups.work]
root = "private/work"

[bootstrap]
dotfile_groups = ["linux", "work"]

[dotfiles]
"~/.profile" = { enabled = false }
TOML
    ln -s private/mise.work.toml "$1/mise.work.local.toml"
}

expect_link() {
    if [ ! -L "$tmp/$1/$2" ] || [ ! -e "$tmp/$1/$2" ]; then
        echo "FAIL: $1: ~/$2 is not a working link" >&2
        fail=1
    fi
}

expect_absent() {
    if [ -e "$tmp/$1/$2" ] || [ -L "$tmp/$1/$2" ]; then
        echo "FAIL: $1: ~/$2 exists" >&2
        fail=1
    fi
}

apply_for host ""
apply_for macos macos
apply_for linux linux
apply_for overlay linux,work overlay

for h in host macos linux overlay; do
    expect_link $h .zshrc
    expect_link $h .config/git/config
    expect_link $h .config/mise/config.toml
    expect_link $h .claude/CLAUDE.md
    expect_link $h .config/opencode/AGENTS.md
    expect_absent $h .gitconfig
    [ -x "$tmp/$h/.local/bin/ask" ] || { echo "FAIL: $h: ~/.local/bin/ask is not executable" >&2; fail=1; }
done

# auto_env loads the platform file for this OS.
expect_link host .config/zsh/$([ "$os" = macos ] && echo darwin || echo linux).zsh

for h in macos; do
    expect_link $h .config/karabiner/karabiner.json
    expect_link $h .config/zsh/darwin.zsh
    expect_link $h .config/ghostty/macos.conf
    expect_absent $h .config/zsh/linux.zsh
    expect_absent $h .config/ghostty/linux.conf
done
for h in linux overlay; do
    expect_link $h .config/zsh/linux.zsh
    expect_link $h .config/ghostty/linux.conf
    expect_absent $h .config/karabiner
    expect_absent $h .config/zsh/darwin.zsh
    expect_absent $h .config/ghostty/macos.conf
done

for h in host macos linux; do
    expect_link $h .profile
    expect_link $h .atuin/config.toml
    expect_absent $h .zshenv
    expect_absent $h .config/shell
    expect_absent $h .config/work
done

expect_absent overlay .profile
expect_link overlay .atuin/config.toml
expect_link overlay .config/work/env

[ "$fail" -eq 0 ] && echo "dotfiles: ok"
exit "$fail"
