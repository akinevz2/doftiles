# herbst_floating — the float registers (mod-f / mod-x / mod-ctrl-f).
# Sourced by the herbstluftwm autostart's keys.d
# loop; stow-merged from this package.

# Mod-q: a focused float is ONLY un-floated (the closing branches run
# only when the focused window is not floating); tiling windows get
# closed, with a lone-window frame removed afterwards.
keyreg $Mod-q               chain ! lock \
                                  ! or . and , compare tags.focus.floating_focused = true \
                                             , attr clients.focus.floating off \
                                       . and , compare tags.focus.curframe_wcount = 1 \
                                             , close_and_remove \
                                       . close_or_remove \
                                  ! unlock  

# peek floats; when the floating layer is empty (or every float is
# hidden), offer the hidden windows via rofi; rofi_hidden exits
# non-zero when nothing is hidden, so fall back to the previous tag.
# Wrapped in sh -c because "spawn" itself is always truthy — the or
# chain has to see the script's exit code.
keyreg $Mod-g               spawn ~/.local/bin/polyframes hidden 

# tile helper: (re)tiles the focused frame's clients (polyframes tile)
keyreg $ModCtrl-t           spawn ~/.local/bin/polyframes tile

# quick float toggle for the focused window: floated windows are
# centered inside their focused frame (visual float indicator);
# pressing again re-unfloats — no focus chasing (hc_focus)
keyreg $Mod-f               spawn ~/.local/bin/hc_focus

# zoom: 3-state toggle for the focused window — float the focused
# window if tiled (a), maximize onto a <tag>-max tag if floating (b),
# restore via hc_unmaximize if maximized (c) (hc_zoom)
keyreg $ModCtrl-f          spawn ~/.local/bin/hc_zoom

keyreg $ModShift-f         attr clients.focus.fullscreen toggle

# tidying tool: pulls the focused client out of its frame (float +
# center on screen, focus back to tiling); with a float on the tag,
# an empty focused frame "drops" the float back in, a frame holding
# clients just toggles focus to the floating layer (hc_floatx)
keyreg $Mod-x               spawn ~/.local/bin/hc_floatx
