#!/bin/sh
# polyframes.sh — polybar module entrypoint for the polyframes renderer.
# Bridges polybar's custom/script module to the Node implementation in
# .config/polybar/polyframes (index.js).
#
# Usage (polybar config):
#   custom/polyframes = ~/.config/polybar/scripts/polyframes.sh
#   ...or with args:  ~/.config/polybar/scripts/polyframes.sh scroll_focus 0 Alacritty down
#
# Verbose logging:
#   ON by default — all layers log to /tmp/polyframes.log (append).
#   polyframes.sh -v ui,format ...  only those layers
#   POLYFRAMES_VERBOSE=ui,clients,frames,format  layer selection
#
# The log file is /tmp/polyframes.log:
#   tail -f /tmp/polyframes.log
#
# All real logic lives in the polyframes JS modules; this shim only
# forwards arguments and preserves the exit status.

# WSLg exposes a Wayland socket (wayland-0) that dual-backend apps like
# rofi 2.0 autodetect — rofi then aborts or maps onto WSLg's Weston
# compositor instead of VcXsrv. This session is X11-only; make sure the
# Wayland variable never reaches node/rofi even if some parent (e.g. a
# systemd user unit importing the login env) leaked it in.
unset WAYLAND_DISPLAY

DIR=$(cd "$HOME/.config/polybar/polyframes" && pwd)
NODE=$(which node)

# Polybar runs under the systemd user manager and never sources nvm's
# shell init, so `which node` can come up empty (the shim then dies with
# a cryptic "31: : Permission denied" from exec'ing ""). Fall back to the
# nvm install (newest version wins), then to a fixed local symlink.
if [ -z "$NODE" ] || [ ! -x "$NODE" ]; then
    for n in "$HOME"/.config/nvm/versions/node/*/bin/node; do
        [ -x "$n" ] && NODE=$n
    done
fi
if [ -z "$NODE" ] || [ ! -x "$NODE" ]; then
    NODE="$HOME/.local/bin/node"
fi
if [ ! -x "$NODE" ]; then
    echo "polyframes: node not found (PATH lacks nvm; no ~/.local/bin/node)" >&2
    exit 127
fi

exec "$NODE" "$DIR/index.js" "$@" 
