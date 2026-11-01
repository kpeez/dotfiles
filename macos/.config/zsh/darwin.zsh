# macOS only.

# mise installs Homebrew packages into /opt/homebrew without the brew CLI.
export HOMEBREW_PREFIX=/opt/homebrew
path=("$HOMEBREW_PREFIX/bin" "$HOMEBREW_PREFIX/sbin" $path)

# Homebrew-provided command completions.
fpath=("$HOMEBREW_PREFIX/share/zsh/site-functions" $fpath)
