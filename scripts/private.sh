#!/bin/sh
# Clone or update the private overlay in ./private, then link each of its
# mise.<env>.toml files to the repo root as mise.<env>.local.toml.
# The repo URL comes from DOTFILES_PRIVATE_REPO, set in the environment or in
# ./.env (untracked). Without a URL and without ./private, this does nothing.
# See docs/private-overlay.md.
set -eu

root=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
cd "$root"

if [ -z "${DOTFILES_PRIVATE_REPO:-}" ] && [ -r .env ]; then
    DOTFILES_PRIVATE_REPO=$(sed -n 's/^DOTFILES_PRIVATE_REPO=//p' .env | tail -n 1)
fi
url=${DOTFILES_PRIVATE_REPO:-}

if [ -d private/.git ]; then
    git -C private pull --ff-only --quiet
elif [ -n "$url" ]; then
    git clone --quiet "$url" private
else
    exit 0
fi

for link in mise.*.local.toml; do
    [ -L "$link" ] && [ ! -e "$link" ] && rm -f "$link" && echo "private: removed dead link $link"
done

for src in private/mise.*.toml; do
    [ -e "$src" ] || continue
    env=${src#private/mise.}
    env=${env%.toml}
    link=mise.$env.local.toml
    if [ -L "$link" ] && [ "$(readlink "$link")" = "$src" ]; then
        continue
    fi
    if [ -e "$link" ] && [ ! -L "$link" ]; then
        echo "private: $link is a regular file; move it aside to link $src" >&2
        continue
    fi
    ln -sfn "$src" "$link"
    echo "private: linked $link -> $src"
done
