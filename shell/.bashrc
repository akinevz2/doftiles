# ~/.bashrc — sourced by interactive bash shells.
# Portable across WSL host, devcontainers, and bare arch.
# Stowed from arch-dots/shell/.bashrc.

# ─── early: ssh-agent bootstrap ───────────────────────────────────────────────
# On the WSL host we start a local agent and load the key so its socket can be
# forwarded into devcontainers. Inside a devcontainer, SSH_AUTH_SOCK is already
# set to the forwarded socket (/ssh-agent) by devcontainer.json remoteEnv, so
# we leave it alone.
_ssh_agent_bootstrap() {
    # If a forwarded socket is already set and live, use it as-is.
    if [ -n "${SSH_AUTH_SOCK:-}" ] && [ -S "$SSH_AUTH_SOCK" ]; then
        # Verify the agent actually responds before trusting it.
        if ssh-add -l >/dev/null 2>&1 || [ $? -eq 1 ]; then
            return 0
        fi
    fi

    # Otherwise start a per-user agent. Reuse an existing one if present.
    local agent_env="$HOME/.ssh/agent-env"
    if [ -f "$agent_env" ]; then
        # shellcheck disable=SC1090
        source "$agent_env" 2>/dev/null
    fi
    if [ -z "${SSH_AUTH_SOCK:-}" ] || [ ! -S "$SSH_AUTH_SOCK" ] || ! ssh-add -l >/dev/null 2>&1; then
        local started
        started=$(ssh-agent -s 2>/dev/null)
        if [ -n "$started" ]; then
            echo "$started" > "$agent_env"
            chmod 600 "$agent_env"
            # shellcheck disable=SC1090
            source "$agent_env" >/dev/null 2>&1
        fi
    fi

    # Load the default key if the agent has no identities.
    if [ -n "${SSH_AUTH_SOCK:-}" ] && [ -S "$SSH_AUTH_SOCK" ]; then
        if ! ssh-add -l >/dev/null 2>&1; then
            ssh-add ~/.ssh/id_ed25519 ~/.ssh/id_rsa 2>/dev/null
        fi
    fi
}
_ssh_agent_bootstrap
unset -f _ssh_agent_bootstrap

# ─── exports & aliases ───────────────────────────────────────────────────────
[ -f "$HOME/.exports"  ] && source "$HOME/.exports"
[ -f "$HOME/.aliases"  ] && source "$HOME/.aliases"
[ -f "$HOME/.config/aliases" ] && source "$HOME/.config/aliases"

# ─── interactive-only niceties ────────────────────────────────────────────────
case $- in
    *i*)
        # History.
        export HISTCONTROL=ignoreboth:erasedups
        export HISTSIZE=9999
        export HISTFILESIZE=9999
        shopt -s histappend checkwinsize cdspell dirspell

        # Prompt (minimal; p10k is zsh-only).
        if [ -x /usr/bin/dircolors ]; then
            eval "$(dircolors -b)"
        fi
        PS1='\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]$(__git_ps1 " (%s)")\$ '

        # Color aliases (harmless if .aliases already set them).
        alias ls='ls --color=auto'
        alias grep='grep --color=auto'

        # Editor.
        if command -v nvim >/dev/null 2>&1; then
            export EDITOR=nvim
        elif command -v vim >/dev/null 2>&1; then
            export EDITOR=vim
        fi
        ;;
esac