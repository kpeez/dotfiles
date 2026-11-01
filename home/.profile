# POSIX login profile. bash reads this when .bash_profile and .bash_login are
# absent, and sh always reads it. Keep it POSIX — fish never reads this file.
#
# This is what makes mise tools reachable from GUI apps (Codex.app, Claude.app)
# that spawn `bash -lc`, and from VS Code's environment probe. launchd gives GUI
# apps a bare PATH, so without this they see only /usr/bin:/bin:/usr/sbin:/sbin.
# The shims path is stable across tool versions, and mise regenerates shims
# automatically when tools are added.

[ -d "$HOME/.local/bin" ] && PATH="$HOME/.local/bin:$PATH"
[ -d "$HOME/.local/share/mise/shims" ] && PATH="$HOME/.local/share/mise/shims:$PATH"
export PATH

[ -r "$HOME/.cargo/env" ] && . "$HOME/.cargo/env"
