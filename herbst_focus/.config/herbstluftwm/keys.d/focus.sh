# herbst_focus — the focus/peek keybinds (mod-s grid, frame
# cycling). Sourced by the herbst_wm autostart's keys.d loop.

# cycle; was $Mod-s / $ModShift-s
# zoom/peek grid — focuses the frame below first; when there is none,
# falls back to the window cycle / pseudotile toggle
keyreg $Mod-s               chain : lock \
                                  :  or , jumpto urgent \
                                        , focus --level=frame down \
                                        , and . attr tags.focus.floating_focused on \
                                              . attr clients.focus.floating off \
                                              . attr clients.focus.pseudotile off \
                                        , and ! compare tags.focus.curframe_wcount gt 1 \
                                              ! cycle -1 \
                                              ! attr clients.focus.pseudotile off \
                                        , pseudotile toggle \
                                  : unlock
                                            
                                            
                                            

# was $ModAlt-Tab → now Alt+Shift+`

keyreg $ModCtrl-r          or , and . compare tags.focus.frame_count lt 3 . chain ! lock ! rotate ! unlock \
                              , and . compare tags.focus.frame_count gt 1 . cycle_frame \
