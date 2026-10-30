# herbst_nav — navigation keybinds (window/tag focus, cycling, tags).
# Sourced by the herbstluftwm autostart's keys.d
# loop; stow-merged from this package.

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
# the window up (#window leaves the frame, --level=all); when there is
# nothing above, with >1 window in the focused frame it cycles -1,
# otherwise it tries cycle_frame, then falls through to rotating the
# frame tree.
keyreg $ModShift-w  or , shift --level=all up \
                      , or ! and . compare tags.focus.frame_count gt 1 \
                                 . cycle_frame \
                           ! cycle -1 \
                      , chain ! lock ! rotate ! unlock

keyreg $ModShift-s  or  , and . compare tags.focus.curframe_wcount = 0 \
                              . remove \
                        , and . compare tags.focus.curframe_wcount gt 1 \
                              . or , shift down \
                                   , chain ! split bottom \
                                           ! shift down

keyreg $ModShift-x          use_previous

keyreg $ModShift-d  or \
                    . and \
                            , compare tags.focus.curframe_wcount gt 1 \
                            , cycle_layout +1 max grid vertical \
                    . remove

keyreg $Mod-d   or \
                , and \
                    . compare tags.focus.curframe_wcount gt 3 \
                            . cycle_layout +1 max vertical grid horizontal \
                , and \
                    . compare tags.focus.curframe_wcount = 2 \
                    . cycle_layout +1 vertical max horizontal \
                , cycle_layout -1 vertical horizontal max

keyreg $ModShift-z          attr clients.focus.minimized toggle

# tag switcher
keyreg $Mod-t               spawn ~/.local/bin/polyframes tags

# FOCUS — hjkl stays within visible clients; arrows traverse all
# frames/layers (levels exchanged: hjkl was all, arrows was visible;
# directions unchanged on both sets)
keyreg $Mod-h                   focus --level=all left

keyreg $Mod-j                   focus --level=all down

keyreg $Mod-k                   focus --level=all up

keyreg $Mod-l                   focus --level=all right

keyreg $Mod-Left                or . focus left . focus --level=all left

keyreg $Mod-Down                or . focus down . focus --level=all down

keyreg $Mod-Up                  or . focus up . focus --level=all up

keyreg $Mod-Right               or . focus right . focus --level=all right

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

keyreg $Mod-bracketleft     use_index -1 --skip-visible

keyreg $Mod-bracketright    use_index +1 --skip-visible

keyreg $ModCtrl-comma       resize left +$resizestep

keyreg $ModCtrl-period      resize right +$resizestep

keyreg $Mod-comma           cycle_all --skip-invisible -1

keyreg $Mod-period          cycle_all --skip-invisible +1

keyreg $ModShift-comma      shift left

keyreg $ModShift-period     shift right
