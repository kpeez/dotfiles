# mise installs Homebrew packages into /opt/homebrew (macOS only), without the brew CLI.
if test -d /opt/homebrew/bin
    fish_add_path /opt/homebrew/bin /opt/homebrew/sbin
end

fish_add_path $HOME/.local/bin
fish_add_path $HOME/.cargo/bin
fish_add_path --append /usr/local/bin

# Defaults
set -gx XDG_CONFIG_HOME $HOME/.config
set -gx XDG_DATA_HOME $HOME/.local/share
set -gx XDG_CACHE_HOME $HOME/.cache
set -gx EDITOR nvim
set -gx VISUAL $EDITOR
set -gx PAGER less
set -gx RCLONE_PROGRESS true
set -gx RIPGREP_CONFIG_PATH $HOME/.config/ripgrep/ripgreprc
set -gx MANPAGER "sh -c 'col -bx | bat -l man -p'"
set -g  fish_greeting ''

# Use Nu for interactive sessions, including SSH and non-login terminals.
# Set XDG paths first so macOS and Linux load the same Nu configuration.
# `env FISH_ONLY=1 fish` keeps an interactive Fish shell for recovery or testing.
# Remote tools can use `fish -i` with piped stdin; Nu's REPL requires a TTY.
if status is-interactive; and test -t 0; and not set -q FISH_ONLY; and command -sq nu
    # A shell parent means the user typed `fish`, so Fish stays. Atuin's
    # output capture restarts a Fish that already stayed under `atuin pty-proxy`.
    set -l ppid (ps -o ppid= -p $fish_pid | string trim)
    set -l parent (ps -o comm= -p $ppid | string trim | string replace -r '^-' '' | path basename)
    if not contains -- $parent nu fish zsh bash sh dash ksh atuin
        exec nu
    end
end

# Nu activates mise itself; only initialize Fish when it remains the shell.
# Hosts where mise manages nothing set MISE_SKIP_ACTIVATE (in their login environment).
if type -q mise; and not set -q MISE_SKIP_ACTIVATE
    mise activate fish | source
end

if status is-interactive
    abbr -a uvipython "uv run --with ipython ipython"
    # TUI aliases
    command -sq rg; and alias grep="rg"
    command -sq bat; and alias cat="bat"
    if command -sq eza
        alias ls="eza"
        alias ld="eza -lD"
        alias lf="eza -lF --color=never | command grep -v /"
        alias ll="eza -al --group-directories-first"
        alias lsa="eza -alF"
        alias lt="eza -al --sort=modified"
    end
    # git aliases/abbreviations
    alias gst="git status"
    alias ga="git add"
    alias gs="git switch"
    alias gbr="git branch"
    alias gpl="git pull"
    alias gps="git push"
    abbr -a gf "git fetch"
    abbr -a gcm "git commit"

    alias omp="oh-my-posh"
    # OSC 52 reaches the local clipboard on every host, including over ssh and
    # inside tmux (set-clipboard on), with no pbcopy or wl-copy dependency.
    # A command substitution does not see the function's stdin, so pipe into read.
    function pbc
        base64 | string join '' | read -l data
        printf '\e]52;c;%s\e\\' $data
    end

    # Directory shortcuts
    set -gx ICLOUD_DIR "$HOME/Library/Mobile Documents/com~apple~CloudDocs"

    # Interactive tool initializations
    set -gx FZF_DEFAULT_COMMAND "fd --type f --strip-cwd-prefix --hidden --exclude .git"
    if command -sq fzf_configure_bindings
        fzf_configure_bindings --directory --history --variables
    end
    # Atuin's Ctrl-R binding replaces fzf's history search where atuin is installed.
    # Init waits for the first prompt: its output capture restarts Fish under
    # `atuin pty-proxy` without the `-c` command, so `fish -i -c` lost it.
    if command -sq atuin
        function __atuin_init_at_prompt --on-event fish_prompt
            functions -e __atuin_init_at_prompt
            atuin init fish | source
        end
    end
    # Prompt engine. Starship stays installed for rollback; oh-my-posh owns the
    # prompt with the vendored theme in ~/.config/oh-my-posh/.
    if command -sq oh-my-posh
        oh-my-posh init fish --config "$HOME/.config/oh-my-posh/current_theme.omp.json" | source
    end
    # The wt wrapper lets `wt switch` cd the shell into the worktree.
    if command -sq wt
        wt config shell init fish | source
    end
    # zoxide must init last (right before prompt) to avoid its config-issue warning
    if command -sq zoxide
        zoxide init fish --cmd=cd | source
    end
end

# Added by OrbStack: command-line tools and integration
# This won't be added again if you remove it.
source ~/.orbstack/shell/init2.fish 2>/dev/null || :
