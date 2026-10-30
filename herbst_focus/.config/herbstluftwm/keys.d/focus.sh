# herbst_focus — the focus/peek keybinds (mod-s grid, frame cycling).
# Sourced by the herbstluftwm autostart's keys.d
# loop; stow-merged from this package.

# ModShift-r: rotate the tree (>3 frames) or cycle frames forward; on
# a single frame it cycles windows in the opposite direction of
# ModShift-w.
keyreg $ModCtrl-r          or , and . compare tags.focus.frame_count lt 3 . chain ! lock ! rotate ! unlock \
                              , and . compare tags.focus.frame_count gt 1 . cycle_frame \
                              , cycle +1

keyreg $Mod-e               or . and , compare tags.focus.frame_count gt 1 , cycle_frame -1 . chain ! split explode ! cycle_frame

# cycle; was $Mod-s / $ModShift-s
# zoom/peek grid — focuses the frame below first; when there is none,
# falls back to the window cycle / pseudotile toggle
# The floating branch: `attr tags.focus.floating_focused true` focuses
# the floating layer AND doubles as the "are there (non-minimized)
# floats" conditional — it fails on an empty floating layer, falling
# through to the alternatives (the failure is quieted in the
# hc_send-error-daemon's QUIET_MATCH).
keyreg $Mod-s               chain : lock \
                                  :  or , and . compare tags.focus.urgent_count gt 0 . jumpto urgent \
                                        , focus --level=frame down \
                                        , and . attr tags.focus.floating_focused true \
                                              . attr tags.focus.focused_client.floating off \
                                              . attr tags.focus.focused_client.pseudotile off \
                                        , and ! compare tags.focus.curframe_wcount gt 1 \
                                              ! cycle -1 \
                                              ! attr clients.focus.pseudotile off \
                                        , pseudotile toggle \
                                  : unlock
