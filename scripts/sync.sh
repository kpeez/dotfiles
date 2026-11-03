#!/bin/sh
# Record agent skills from this host and the SSH hosts given as arguments,
# then pull ~/.dotfiles (and ~/.dotfiles/private) and run mise bootstrap on
# those hosts. Run by `mise run sync [host]...`; see docs/setup.md.

cd "$(dirname "$0")/.." || exit 1

locks=$(mktemp -d)
for host in "$@"; do
  echo 'f=${XDG_STATE_HOME:+$XDG_STATE_HOME/skills/.skill-lock.json}; cat "${f:-$HOME/.agents/.skill-lock.json}" 2>/dev/null' | ssh "$host" sh >"$locks/$host.json" || true
  [ -s "$locks/$host.json" ] || rm -f "$locks/$host.json"
done
nu scripts/skills.nu record $(ls "$locks"/*.json 2>/dev/null)
rm -rf "$locks"
if ! git diff --quiet -- agent-config/skills.json; then
  git commit -q -m "chore(agent-config): record agent skills" -- agent-config/skills.json && git push -q ||
    echo "sync: commit or push of agent-config/skills.json failed" >&2
fi
command -v skills >/dev/null && nu scripts/skills.nu

failed=
for host in "$@"; do
  echo "== $host"
  echo 'umask 022; cd ~/.dotfiles && git pull --ff-only && sh scripts/private.sh && "$(command -v mise || echo ~/.local/bin/mise)" bootstrap -y --skip user --skip-dirty' | ssh "$host" sh || failed="$failed $host"
done
[ -z "$failed" ] || { echo "sync failed on:$failed" >&2; exit 1; }
