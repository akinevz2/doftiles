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
            "$HOME/.local/bin/load-credentials" || true
            ;;
        herbstluftwm)
            if herbstclient version >/dev/null 2>&1; then
                herbstclient reload
            else
                echo "deploy: no running hlwm — reload skipped"
            fi
            ;;
        herbst_theme)
            if herbstclient version >/dev/null 2>&1; then
                "$HOME/.local/bin/reload_theme" -f
            else
                echo "deploy: no running hlwm — theme apply skipped"
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
stowed() {
    local pkg=$1 rel first
    first=$(find "$pkg" -type f 2>/dev/null | head -1) || return 1
    [ -n "$first" ] || return 1
    rel=${first#"$pkg"/}
    [ -L "$HOME/$rel" ] || return 1
    case "$(readlink "$HOME/$rel")" in *"dots/$pkg/"*) return 0 ;; esac
    return 1
}

# --- dispatch ------------------------------------------------------------
if [ "${1:-}" = "--hook" ]; then
    [ -n "${2:-}" ] || { echo "deploy: --hook needs a package" >&2; exit 1; }
    hook "$2"
    exit 0
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
    echo "deploy: usage: make deploy P=\"shell herbst_theme\"" >&2
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
