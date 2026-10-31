#!/usr/bin/env bash
# deploy-menu — selective deployment helper for doftiles.
#
# Modes:
#   --hook <pkg>   run the post-stow hook for <pkg>. Hooks that need a
#                  running WM / X server are GUARDED: they no-op with a
#                  note on headless targets instead of failing.
#   [P]            resolve the package selection and print the names,
#                  one per line: P="a b" is fine-grained (validated);
#                  otherwise a whiptail checklist when interactive;
#                  otherwise a plain numbered menu; without a TTY the
#                  call errors with usage.
set -euo pipefail
DOTS="$(cd "$(dirname "$0")/.." && pwd)"
cd "$DOTS"

# --- the package universe ------------------------------------------------
# A stow package = a top-level directory with .config/.local content.
# system-* packages stow to / instead (add-packages-system); helper
# dirs without dotfile content (scripts/) are not packages.
mapfile -t ALL_PKGS < <(for d in */; do
    d=${d%/}
    case "$d" in .*|system-*) continue ;; esac
    [ -d "$d/.config" ] || [ -d "$d/.local" ] || continue
    printf '%s\n' "$d"
done | sort)

# --- post-stow hooks -----------------------------------------------------
hook() {
    local pkg=$1
    case "$pkg" in
        shell)
            chmod +x shell/.local/bin/install/bashrc 2>/dev/null || true
            "$HOME/.local/bin/install/bashrc" || true
            # Windows Firefox wrapper — installed ONLY when the target
            # .exe actually exists. Stow links it unconditionally on
            # every restow, so the hook prunes the dangling link on
            # hosts that don't have Windows Firefox (or reinstates it
            # if the link went missing where the .exe IS available).
            local ffexe fflink
            ffexe="/mnt/c/Program Files/Mozilla Firefox/firefox.exe"
            fflink="$HOME/.local/bin/firefox"
            if [ -e "$ffexe" ]; then
                mkdir -p "$HOME/.local/bin"
                ln -sfn "$DOTS/shell/.local/bin/firefox" "$fflink"
            elif [ -L "$fflink" ] && \
                 [ "$(realpath -m "$fflink" 2>/dev/null || true)" = \
                   "$DOTS/shell/.local/bin/firefox" ]; then
                rm -f "$fflink"
                echo "deploy: $ffexe not found — firefox wrapper link removed"
            fi
            # credentials MOVED OUT: load-credentials used to fire here
            # (mid-deploy) and error on machines without ~/.my-credentials.
            # It now runs as the gated final step of `make bootstrap`
            # (Makefile target: credentials).
            ;;
        herbstluftwm)
            # the autostart's keybind state machines: when the herbctl
            # binary is missing, `on-deploy toolchain` builds + installs
            # it from the submodule (the assurance that used to be the
            # herbctl-ensure recipe; make all/wm/herbstluftwm all reach
            # the hook). Fail-soft — freshness lands via `make update` +
            # `on-deploy toolchain --force`.
            if [ ! -x "$HOME/.local/bin/herbctl" ]; then
                if [ -x "$HOME/.local/bin/on-deploy" ] && \
                   [ -f "$DOTS/depends/.local/share/herbctl/src/index.ts" ]; then
                    "$HOME/.local/bin/on-deploy" toolchain || \
                        echo "deploy: herbctl build FAILED — the get-* keybinds exec it" >&2
                else
                    echo "deploy: herbctl missing (no on-deploy or no submodule checkout) — run 'make install'"
                fi
            fi
            if herbstclient version >/dev/null 2>&1; then
                herbstclient reload
                "$HOME/.local/bin/reload_theme" -f
            else
                echo "deploy: no running hlwm — reload skipped"
            fi
            ;;
        polybar)
            if pgrep -x polybar >/dev/null 2>&1; then
                "$HOME/.local/bin/polyctl" reload
            else
                echo "deploy: polybar not running — reload skipped"
            fi
            ;;
        *) : ;;    # no hook for this package
    esac
}

# --- stowed-state detection (for TUI preselection) -----------------------
# Resolves the first package file's live path to its canonical repo
# location — stow may fold DIRECTORY links, so the file itself is not
# necessarily a symlink; the resolved path is.
stowed() {
    local pkg=$1 rel first target
    first=$(find "$pkg" -type f -print -quit 2>/dev/null)
    [ -n "$first" ] || return 1
    rel=${first#"$pkg"/}
    [ -e "$HOME/$rel" ] || return 1
    target=$(realpath -m "$HOME/$rel" 2>/dev/null) || return 1
    case "$target" in *"/dots/$pkg/"*) return 0 ;; esac
    return 1
}

# --- deploy.profile TUI ---------------------------------------------------
# The on-deploy provisioning manifest. Same value sets as on-deploy's
# src/lib/profile.ts — keep them in sync (the binary is the authority;
# a bad combination here is caught again there).
PROFILE_FILE="$DOTS/deploy.profile"
SESSIONS="greetd wsl-systemd xinit nested"
FEATURES="xserver xinitrc greeter nested xrdp"
# the distro target: on-deploy's provisioners branch on this (pacman vs
# apt) and the requirement walk resolves binaries via
# ~/.local/bin/install/<target>.deploy — keep in sync with configure.ts
TARGETS="ubuntu debian manjaro arch fedora"
REQUIRES_FILE="$DOTS/wm.requires"

# trim whitespace (front only is enough for our canonical file)
ltrim() { local s=$1; s=${s#"${s%%[![:space:]]*}"}; printf '%s' "$s"; }

parse_profile() {
    CUR_SESSION=""; CUR_FEATURES=""; CUR_UNITS=""; CUR_ENV=()
    [ -f "$PROFILE_FILE" ] || return 0
    local line t key val
    while IFS= read -r line || [ -n "$line" ]; do
        t=$(ltrim "$line")
        [ -z "$t" ] && continue
        case "$t" in \#*) continue ;; esac
        if [[ "$t" == *=* ]]; then
            key=$(ltrim "${t%%=*}")
            val=$(ltrim "${t#*=}")
            case "$key" in
                session)  CUR_SESSION=$val ;;
                features) CUR_FEATURES="$CUR_FEATURES${CUR_FEATURES:+ }$val" ;;
                units)    CUR_UNITS="$CUR_UNITS${CUR_UNITS:+ }$val" ;;
                env)      CUR_ENV+=("$val") ;;
            esac
        else
            # bare feature words (the original one-per-line form)
            CUR_FEATURES="$CUR_FEATURES${CUR_FEATURES:+ }$t"
        fi
    done < "$PROFILE_FILE"
}

write_profile() {
    local session=$1 features=$2 units=$3; shift 3
    {
        printf '# deploy.profile — platform provisioning for on-deploy provision\n'
        printf '# (regenerated by the `make deploy` profile TUI)\n'
        printf 'session = %s\n' "$session"
        printf 'features = %s\n' "$features"
        printf 'units = %s\n' "$units"
        local e
        for e in "$@"; do printf 'env = %s\n' "$e"; done
    } > "$PROFILE_FILE"
}

# repo units — the checklist universe for the `units` key
mapfile -t REPO_UNITS < <(find . -name '*.service' -not -path './.git/*' \
    -printf '%f\n' 2>/dev/null | sed 's/\.service$//' | sort -u)

profile_tui() {
    parse_profile
    local session=${CUR_SESSION:-wsl-systemd}
    local cur_features=$CUR_FEATURES cur_units=$CUR_UNITS
    # current distro target: last non-comment line of wm.requires
    local cur_target
    cur_target=$(grep -v '^[[:space:]]*#' "$REQUIRES_FILE" | grep -v '^[[:space:]]*$' | tail -1)
    local env_csv
    env_csv=$(IFS=,; echo "${CUR_ENV[*]}")
    local sel opts item
    while :; do
        # --- distro target (menu) ---
        opts=()
        for item in $TARGETS; do
            if [ "$item" = "$cur_target" ]; then opts+=("$item" "(current)")
            else opts+=("$item" ""); fi
        done
        sel=$(whiptail --title "deploy.profile — distro target" \
            --menu "Which distro is this machine?
Drives package-manager choice (pacman vs apt) and the
~/.local/bin/install/<target>.deploy requirement script." \
            0 62 0 "${opts[@]}" 3>&1 1>&2 2>&3) || return 0
        if [ "$sel" != "$cur_target" ]; then
            # same write as `on-deploy configure --target <t>`: replace
            # the last non-comment, non-blank line of wm.requires
            local ln
            ln=$(grep -nv '^[[:space:]]*#\|^[[:space:]]*$' "$REQUIRES_FILE" \
                | tail -1 | cut -d: -f1)
            if [ -n "$ln" ] && sed -i "${ln}s/.*/$sel/" "$REQUIRES_FILE"; then
                cur_target=$sel
            else
                echo "deploy: failed to write target into wm.requires" >&2
            fi
            if [ ! -x "$HOME/.local/bin/install/$cur_target.deploy" ]; then
                whiptail --title "no deploy script" --msgbox \
"No ~/.local/bin/install/$cur_target.deploy yet — missing wm.requires
binaries can NOT be auto-installed on $cur_target.

Continue only if the required binaries are already present
(or create the script first). OK to continue anyway." 0 62 || return 0
            fi
            echo "wm.requires: deploy target -> $cur_target"
        fi
        # --- session model (radiolist) ---
        opts=()
        for item in $SESSIONS; do
            if [ "$item" = "$session" ]; then opts+=("$item" "" ON)
            else opts+=("$item" "" OFF); fi
        done
        sel=$(whiptail --title "deploy.profile — session model" \
            --radiolist "How does the graphical session start?
<greetd> a display manager owns the console
<wsl-systemd> hlwm as herbst.service, waits for VcXsrv
<xinit> startx runs ~/.xinitrc
<nested> hlwm in the Xvfb framebuffer (VNC/noVNC)" \
            0 62 0 "${opts[@]}" 3>&1 1>&2 2>&3) || return 0
        session=$sel

        # --- features (checklist) ---
        opts=()
        for item in $FEATURES; do
            if printf '%s\n' "$cur_features" | grep -qw "$item"; then opts+=("$item" "" ON)
            else opts+=("$item" "" OFF); fi
        done
        sel=$(whiptail --title "deploy.profile — features" \
            --checklist "Space toggles; OK continues.
<xserver> X server packages
<xinitrc> write ~/.xinitrc session line
<greeter> the greetd greeter (requires session = greetd)
<nested> Xvfb + x11vnc + noVNC stack
<xrdp> RDP :3390 onto the shared framebuffer" \
            0 62 0 "${opts[@]}" 3>&1 1>&2 2>&3) || return 0
        sel=${sel//\"/}
        cur_features=$(echo "$sel" | tr -s ' ')
        cur_features=${cur_features# }

        # conflict rule, same as on-deploy's profile.ts:
        # greeter implies greetd and conflicts with any other session
        if printf '%s\n' "$cur_features" | grep -qw greeter \
            && [ "$session" != "greetd" ]; then
            whiptail --title "conflict" --msgbox \
"feature 'greeter' requires session = greetd
(a display manager owns the console).

Adjust the session model or drop the greeter feature." 0 62 || return 0
            continue
        fi

        # --- units (checklist; universe = repo *.service files) ---
        opts=()
        for item in "${REPO_UNITS[@]}"; do
            if printf '%s\n' "$cur_units" | grep -qw "$item"; then opts+=("$item" "" ON)
            else opts+=("$item" "" OFF); fi
        done
        if [ "${#opts[@]}" -gt 0 ]; then
            sel=$(whiptail --title "deploy.profile — systemd user units" \
                --checklist "Units this profile enables (additive across profiles)." \
                0 62 0 "${opts[@]}" 3>&1 1>&2 2>&3) || return 0
            sel=${sel//\"/}
            cur_units=$(echo "$sel" | tr -s ' ')
            cur_units=${cur_units# }
        fi

        # --- env lines (free text; comma-separated KEY=VALUE) ---
        sel=$(whiptail --title "deploy.profile — env" \
            --inputbox "Env lines written to ~/.config/doftiles/env.
Comma-separated KEY=VALUE pairs; empty for none.

Current: ${env_csv:-<none>}" \
            0 62 "$env_csv" 3>&1 1>&2 2>&3) || return 0
        local e bad=""
        CUR_ENV=()
        for e in $(tr ',' ' ' <<<"$sel"); do
            if [[ "$e" =~ ^[A-Za-z_][A-Za-z0-9_]*= ]]; then
                CUR_ENV+=("$e")
            else
                bad="$bad $e"
            fi
        done
        if [ -n "$bad" ]; then
            whiptail --title "malformed env" --msgbox \
"Not KEY=VALUE:$bad — dropped. OK to continue anyway." 0 62 || return 0
        fi

        write_profile "$session" "$cur_features" "$cur_units" "${CUR_ENV[@]}"
        echo "deploy.profile: session=$session features=[$cur_features] units=[$cur_units] env=[${CUR_ENV[*]:-none}]"
        return 0
    done
}

# --- dispatch ------------------------------------------------------------
if [ "${1:-}" = "--hook" ]; then
    [ -n "${2:-}" ] || { echo "deploy: --hook needs a package" >&2; exit 1; }
    hook "$2"
    exit 0
fi

if [ "${1:-}" = "--profile" ]; then
    profile_tui
    exit 0
fi

# --stowed <pkg> — exit 0 when the package is currently stowed into
# $HOME (used by `make status`).
if [ "${1:-}" = "--stowed" ]; then
    [ -n "${2:-}" ] || exit 1
    if stowed "$2"; then exit 0; fi
    exit 1
fi

P=${1:-}

if [ -n "$P" ]; then
    # fine-grained: validate every name, then print
    for want in $P; do
        ok=""
        for cand in "${ALL_PKGS[@]}"; do [ "$cand" = "$want" ] && ok=1; done
        if [ -z "$ok" ]; then
            echo "deploy: unknown package '$want'" >&2
            echo "deploy: available: ${ALL_PKGS[*]}" >&2
            exit 1
        fi
        echo "$want"
    done
    exit 0
fi

if [ ! -t 0 ]; then
    echo "deploy: non-interactive without P= — nothing selected" >&2
    echo "deploy: usage: make deploy P=\"shell herbstluftwm\"" >&2
    exit 1
fi

# --- TUI: whiptail checklist ---------------------------------------------
if command -v whiptail >/dev/null 2>&1; then
    args=()
    for pkg in "${ALL_PKGS[@]}"; do
        if stowed "$pkg"; then state=ON; else state=OFF; fi
        args+=("$pkg" "" "$state")
    done
    sel=$(whiptail --title "doftiles — selective deploy" \
        --checklist "Space toggles; OK stows the selected packages." \
        0 60 0 "${args[@]}" 3>&1 1>&2 2>&3) || exit 0
    # shellcheck disable=SC2086
    for pkg in $(sed 's/"//g' <<<"$sel"); do echo "$pkg"; done
    exit 0
fi

# --- fallback: plain numbered menu ---------------------------------------
echo "selective deploy — available packages:"
i=1
for pkg in "${ALL_PKGS[@]}"; do
    if stowed "$pkg"; then mark="*"; else mark=" "; fi
    printf '  %s %2d) %s\n' "$mark" "$i" "$pkg"
    i=$((i + 1))
done
echo "(* = currently stowed)"
read -r -p "package numbers or names, space-separated (empty aborts): " reply
[ -n "$reply" ] || exit 0
for token in $reply; do
    if [[ "$token" =~ ^[0-9]+$ ]] && [ "$token" -ge 1 ] \
        && [ "$token" -le "${#ALL_PKGS[@]}" ]; then
        echo "${ALL_PKGS[$((token - 1))]}"
    else
        echo "$token"
    fi
done
