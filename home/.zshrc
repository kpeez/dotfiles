# Interactive zsh, shared by all hosts. zsh is a fallback shell: Nu is the
# interactive shell and fish mirrors it, so zsh keeps only history, completion
# and the prompt. Env vars go in config.nu and config.fish. Per-host additions live in
# ~/.config/zsh/.

############################################################
# Tool activation
############################################################
# Hosts where activation is too slow set MISE_SKIP_ACTIVATE (in their login environment).
[[ -x "$HOME/.local/bin/mise" && -z "$MISE_SKIP_ACTIVATE" ]] && eval "$("$HOME/.local/bin/mise" activate zsh)"

typeset -U path fpath
export PATH

export GPG_TTY=$TTY

############################################################
# History  (zsh persists nothing unless these are set)
############################################################
HISTFILE="$HOME/.zsh_history"
HISTSIZE=100000
SAVEHIST=100000
setopt EXTENDED_HISTORY        # record timestamps
setopt SHARE_HISTORY           # live-share history across tmux panes
setopt HIST_IGNORE_ALL_DUPS
setopt HIST_IGNORE_SPACE       # a leading space keeps a command out of history
setopt HIST_REDUCE_BLANKS
setopt HIST_VERIFY             # !! expands into the buffer instead of running

############################################################
# Shell options
############################################################
setopt AUTO_CD                 # bare directory name cds into it
setopt AUTO_PUSHD PUSHD_IGNORE_DUPS PUSHD_SILENT
setopt INTERACTIVE_COMMENTS    # tolerate # comments in pasted commands
setopt COMPLETE_IN_WORD        # complete from the cursor, not just line end
setopt ALWAYS_TO_END           # move to word end after completing
setopt NO_NOMATCH              # leave unmatched globs alone, as bash does
setopt NO_BEEP

# EDITOR=nvim contains "vi", which would make zsh pick vi keybindings.
bindkey -e

############################################################
# Completion
############################################################
[[ -d "$HOME/.cache/zsh" ]] || mkdir -p "$HOME/.cache/zsh"
autoload -Uz compinit
_zdump="$HOME/.cache/zsh/zcompdump-$ZSH_VERSION"
# -C reuses a dump under a day old. -i drops insecure fpath entries instead of
# prompting, which would otherwise stall login on a cluster's group-writable cvmfs.
_zdump_fresh=( $HOME/.cache/zsh/zcompdump-$ZSH_VERSION(N.mh-24) )
if (( $#_zdump_fresh )); then
    compinit -C -d "$_zdump"
else
    compinit -i -d "$_zdump"
fi
unset _zdump _zdump_fresh
zmodload zsh/complist

zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}' 'r:|=*' 'l:|=* r:|=*'
zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS}
zstyle ':completion:*' group-name ''
zstyle ':completion:*' special-dirs true
zstyle ':completion:*' use-cache on
zstyle ':completion:*' cache-path "$HOME/.cache/zsh/zcompcache"
zstyle ':completion:*:descriptions' format '%F{blue}-- %d --%f'
zstyle ':completion:*:warnings'     format '%F{red}-- no matches --%f'

bindkey '^[[H'    beginning-of-line
bindkey '^[[F'    end-of-line
bindkey '^[[3~'   delete-char
bindkey '^[[1;5C' forward-word
bindkey '^[[1;5D' backward-word

############################################################
# Tool initialization  (must come after compinit)
############################################################
# Prompt engine. Starship stays installed for rollback; oh-my-posh owns the
# prompt with the vendored theme in ~/.config/oh-my-posh/.
command -v oh-my-posh >/dev/null && eval "$(oh-my-posh init zsh --config "$HOME/.config/oh-my-posh/current_theme.omp.json")"
command -v atuin >/dev/null && eval "$(atuin init zsh --disable-up-arrow)"

############################################################
# Per-host additions
############################################################
# OS fragment, then host, then an untracked local.zsh. Existence-guarded so a
# missing fragment can never abort startup.
for _frag in \
    "$HOME/.config/zsh/${(L)$(uname -s)}.zsh" \
    "$HOME/.config/zsh/$(hostname -s).zsh" \
    "$HOME/.config/zsh/local.zsh"
do
    [[ -r "$_frag" ]] && source "$_frag"
done
unset _frag
