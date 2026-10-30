#!/bin/sh
# ~/.xinitrc — the X session client script for the generic arch deployment
# (arch-generic branch). Started with:
#
#     make startx        # startx ~/.xinitrc -- vt6, display :0
#
# herbstluftwm sources ~/.config/herbstluftwm/autostart when it comes
# up; the autostart script brings in the compositor, bar, and keybinds
# for the rest of the session.

exec herbstluftwm
