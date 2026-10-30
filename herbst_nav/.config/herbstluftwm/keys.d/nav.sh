# herbst_nav — navigation keybinds (window/tag focus and cycling).
# Sourced by the herbst_wm autostart's keys.d loop; stow-merged
# from the herbst_nav package.

# was $ModAlt-Tab → now Alt+Shift+`
keyreg $Mod-c       or \
                    . and \
                        , compare tags.focus.tiling.root.split_type = vertical \
                        , compare tags.focus.floating_focused = 0 \
                        , rotate \
                    . chain \
                        , cycle_frame \
                        , jumpto urgent

keyreg $Mod-w       chain : lock : or \
                                , and \
                            ! compare tags.focus.floating_focused = 1 \
                            ! attr tags.focus.floating_focused off \
                                , and \
                            ! compare tags.focus.curframe_wcount gt 1 \
                            ! cycle +1 \
                       , focus --level=frame up \
                       , cycle_frame : unlock

# ModShift-w: mirror of Mod-w's cycle -1 register — first tries shifting

keyreg $ModShift-x          use_previous

keyreg $ModShift-z          attr clients.focus.minimized toggle

# tag switcher
keyreg $Mod-t               spawn ~/.local/bin/polyframes tags


# FOCUS — hjkl stays within visible clients; arrows traverse all
# frames/layers (levels exchanged: hjkl was all, arrows was visible;
# directions unchanged on both sets)
keyreg $Mod-h                   focus --level=visible left
keyreg $Mod-j                   focus --level=visible down
keyreg $Mod-k                   focus --level=visible up
keyreg $Mod-l                   focus --level=visible right
keyreg $Mod-Left                or . focus --level=all left . focus --level=all left
keyreg $Mod-Down                or . focus --level=all down . focus --level=all down
keyreg $Mod-Up                  or . focus --level=all up . focus --level=all up
keyreg $Mod-Right               or . focus --level=all right . focus --level=all right

# SHIFT windows — Alt+Ctrl+arrows and Alt+Ctrl+hjkl
# (hjkl slot freed up by dropping the old focus aliases)
keyreg $ModCtrl-h               shift --level=all left
keyreg $ModCtrl-j               shift --level=all down
keyreg $ModCtrl-k               shift --level=all up
keyreg $ModCtrl-l               shift --level=all right
keyreg $ModCtrl-Left            or . shift --level=frame left . shift --level=all left
keyreg $ModCtrl-Down            or . shift --level=frame down . shift --level=all down
keyreg $ModCtrl-Up              or . shift --level=frame up . shift --level=all up
keyreg $ModCtrl-Right           or . shift --level=frame right . shift --level=all right


# scroll wheel: cycle windows within current frame (up = previous, down = next)
herb mousebind $Mod-Button4 call cycle +1
herb mousebind $Mod-Button5 call cycle -1

keyreg $Mod-comma           cycle_all --skip-invisible -1
keyreg $Mod-period          cycle_all --skip-invisible +1
keyreg $ModShift-comma      shift left
keyreg $ModShift-period     shift right

