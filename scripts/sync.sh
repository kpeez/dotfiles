#!/bin/sh
# Record agent skills from this host and the SSH hosts given as arguments,
# then pull ~/.dotfiles (and ~/.dotfiles/private) and run mise bootstrap on
# those hosts. Run by `mise run sync [host]...`; see docs/reference.md.

cd "$(dirname "$0")/.." || exit 1

locks=$(mktemp -d)
for host in "$@"; do
  echo 'f=${XDG_STATE_HOME:+$XDG_STATE_HOME/skills/.skill-lock.json}; cat "${f:-$HOME/.agents/.skill-lock.json}" 2>/dev/null' | ssh "$host" sh >"$locks/$host.json" || true
  [ -s "$locks/$host.json" ] || rm -f "$locks/$host.json"
done
nu scripts/skills.nu record $(ls "$locks"/*.json 2>/dev/null)
rm -rf "$locks"
if ! git diff --quiet -- agent-config/skills.json; then
  git commit -q -m "chore(agent-config): record agent skills" -- agent-config/skills.json ||
    echo "sync: commit of agent-config/skills.json failed" >&2
fi
if [ "$(git rev-list --count '@{u}..HEAD' 2>/dev/null || echo 0)" -gt 0 ]; then
  git push -q || echo "sync: push failed" >&2
fi
command -v npx >/dev/null && nu scripts/skills.nu

# mise writes its progress to stderr and has no setting that hides parts left
# unchanged, so drop those lines here: phase headers, echoed hook and task
# commands, and "already ..." reports. Changes, warnings, and errors stay.
quiet() {
  sed -E \
    -e '/^mise bootstrap: /d' \
    -e '/^mise by @jdx /d' \
    -e '/^mise \$ /d' \
    -e '/^\[bootstrap\] \$ /d' \
    -e '/ · installed 0 tools · /d' \
    -e '/(already installed|already converged|already applied|already current|all files are applied|all edits are applied|all tools are installed)$/d'
}

# The ssh runs in a pipeline subshell, so it records a failed host in a file.
failed=$(mktemp)
for host in "$@"; do
  echo "== $host"
  {
    echo 'umask 022; cd ~/.dotfiles && git pull -q --ff-only && sh scripts/private.sh && "$(command -v mise || echo ~/.local/bin/mise)" bootstrap -y --skip user --skip-dirty --prune-dotfiles' | ssh "$host" sh 2>&1 ||
      printf ' %s' "$host" >>"$failed"
  } | quiet
done
hosts=$(cat "$failed")
rm -f "$failed"
[ -z "$hosts" ] || { echo "sync failed on:$hosts" >&2; exit 1; }
