# Added by Obsidian
[ -d /Applications/Obsidian.app/Contents/MacOS ] && export PATH="$PATH:/Applications/Obsidian.app/Contents/MacOS"
# Expose mise-managed tools before interactive zsh activation runs. Hosts that
# set MISE_SKIP_ACTIVATE in their login environment put mise's bin directories on PATH
# themselves, because shims are too slow there.
[ -z "$MISE_SKIP_ACTIVATE" ] && export PATH="$HOME/.local/share/mise/shims:$PATH"
