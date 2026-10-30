# ~/.zshrc — zsh configuration, at parity with shell/.bashrcx.
# Portable across WSL host, devcontainers, and bare arch.
# Stowed from dots/shell/.zshrc.

# Guard against double-sourcing.
[ -n "${_DOTS_ZSHRC_LOADED:-}" ] && return 0
_DOTS_ZSHRC_LOADED=1

# ─── Oh My Zsh (optional; the config works without it) ───────────────────────
# omz contributes plugins + completion when installed; every functional
# bit below (history, prompt, hooks) is omz-independent so a box without
# ~/.oh-my-zsh still gets full parity with the bash setup.
if [ -d "$HOME/.oh-my-zsh" ]; then
    export ZSH="$HOME/.oh-my-zsh"
    ZSH_THEME=""                     # the two-line prompt below replaces it
    plugins=(git)
    # our precmd/preexec title hooks own the terminal title
    DISABLE_AUTO_TITLE="true"
    source "$ZSH/oh-my-zsh.sh"
else
    # completion without omz
    autoload -Uz compinit && compinit -d "$HOME/.zcompdump"
fi

# ─── interactive-only niceties ───────────────────────────────────────────────
case $- in
    *i*)
        # History — parity with the bashrc's
        #   HISTCONTROL=ignoreboth:erasedups + HISTSIZE=9999.
        # zsh always appends (histappend) and knows the terminal size
        # (checkwinsize); cdspell/dirspell have no direct zsh equivalent.
        export HISTSIZE=9999
        export SAVEHIST=9999
        setopt HIST_IGNORE_ALL_DUPS     # erasedups
        setopt HIST_IGNORE_SPACE        # ignoreboth's leading-space half
        setopt HIST_REDUCE_BLANKS

        if [ -x /usr/bin/dircolors ]; then
            eval "$(dircolors -b)"
        fi

        # Modern two-line prompt, mirroring the bash one:
        #   line 1: user @ host :: (git branch X) ⟨rc⟩  ~/path
        #   line 2: >
        # with the branch green when the worktree is clean, yellow when
        # dirty, and the ⟨rc⟩ marker shown only for non-zero exits.
        __zsh_git_branch() {
            local b
            b=$(git symbolic-ref --short HEAD 2>/dev/null) && {
                printf '%s' "$b"
                return 0
            }
            b=$(git describe --tags --exact-match HEAD 2>/dev/null) && {
                printf '%s' "$b"
                return 0
            }
            git rev-parse --short HEAD 2>/dev/null
        }
        setopt PROMPT_SUBST
        __zsh_prompt_build() {
            local rc=$?                        # capture BEFORE any git call
            local git_info="" exit_info=""
            local b; b=$(__zsh_git_branch)
            if [ -n "$b" ]; then
                local colour=green
                if ! git diff --quiet --cached 2>/dev/null \
                   || ! git diff --quiet 2>/dev/null; then
                    colour=yellow               # dirty
                fi
                git_info=" %F{$colour}(git branch ${b})%F{default}"
            fi
            if [ "$rc" -ne 0 ]; then
                exit_info=" %F{red}⟨${rc}⟩%F{default}"
            fi
            PROMPT=$'\n'"%F{green}%n%f @ %F{green}%m%f ::${git_info}${exit_info} %F{cyan}${(D):-$PWD}%F{default}"$'\n%F{magenta}>%f '
        }

        # Color aliases (harmless if .aliases already set them).
        alias ls='ls --color=auto'
        alias grep='grep --color=auto'

        # Editor — same preference order as the bashrc.
        if command -v code >/dev/null 2>&1; then
            export EDITOR=code
        elif command -v nvim >/dev/null 2>&1; then
            export EDITOR=nvim
        elif command -v vim >/dev/null 2>&1; then
            export EDITOR=vim
        fi
        ;;
esac

# Keep the terminal (WM) title in sync with the running program, so
# window lists show 'nvim' / 'vi' instead of the terminal class.
# preexec fires when a command starts; precmd when the prompt returns.
# (Defined after the prompt's precmd so both run — zsh keeps a list.)
__title_set() { printf '\033]0;%s\007' "$1" }
__title_running() { __title_set "${1%% *}"; }
__title_idle() { __title_set "zsh ${(D):-$PWD}"; }
# zsh's precmd/preexec are single functions — compose via hooks (the
# zsh equivalent of bash's PROMPT_COMMAND list)
autoload -Uz add-zsh-hook
add-zsh-hook precmd __zsh_prompt_build
add-zsh-hook precmd __title_idle
add-zsh-hook preexec __title_running

# ─── ssh-agent (use systemd socket, don't launch our own) ────────────────────
# systemd's ssh-agent.socket listens on a fixed path; just export it and
# add keys. NOTE: commented out until fully configured in stow (parity
# with the bashrc's commented block).
# if [ -x "$HOME/.local/bin/check-wsl" ] && "$HOME/.local/bin/check-wsl"; then
#     export SSH_AUTH_SOCK="$XDG_RUNTIME_DIR/openssh_agent"
#     if [ -S "$SSH_AUTH_SOCK" ] && ! ssh-add -l >/dev/null 2>&1; then
#         for _key in "$HOME"/.ssh/id_ed25519 "$HOME"/.ssh/id_rsa; do
#             [ -f "$_key" ] && ssh-add "$_key" 2>/dev/null
#         done
#         unset _key
#     fi
# fi

# ─── exports & aliases ───────────────────────────────────────────────────────
[ -f "$HOME/.exports" ] && source "$HOME/.exports"
[ -f "$HOME/.aliases" ] && source "$HOME/.aliases"

# ─── machine-local secrets (transient, gitignored in shell/.cache/) ─────────
# Any *.env here is sourced into new shells; per-machine credentials
# (tokens) live outside version control forever.
for _secrets_file in "$HOME"/dots/shell/.cache/*.env; do
    [ -f "$_secrets_file" ] && . "$_secrets_file"
done
unset _secrets_file

# ─── MOTD display ───────────────────────────────────────────────────────────
# Show MOTD on first shell after boot, or when mail exists. Uses a
# marker file in /tmp to track if we've already shown MOTD this session.
_show_motd() {
    local _motd_marker="/tmp/.motd_shown_${PPID}"
    local _mail_spool="/var/mail/${USER:-root}"
    if [ ! -f "$_motd_marker" ] || \
       { [ -f "$_mail_spool" ] && [ "$_mail_spool" -nt "$_motd_marker" ]; }; then
        cat /etc/motd 2>/dev/null || true
        touch "$_motd_marker"
    fi
}
case $- in *i*) _show_motd ;; esac

# ─── get — the got wrapper (parity with the bashrc's get) ────────────────────
# A directory argument is cd'd into first; "-" means the previous
# directory (cd -), shifted off so got lists the restored directory
# instead of reading "-" as a help flag. got is POSIX sh — sourced under
# sh emulation so zsh's word-splitting quirks can't bite.
get() {
    emulate -L sh
    if [ $# -gt 0 ]; then
        case $1 in
            -)
                cd - || return 1
                shift
                ;;
            *)
                if [ -d "$1" ]; then
                    cd -- "$1" || return 1
                fi
                ;;
        esac
    fi
    source "$HOME/.local/bin/got" "$@"
}
