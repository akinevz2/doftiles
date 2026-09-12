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

exec "$NODE" "$DIR/index.js" "$@"
