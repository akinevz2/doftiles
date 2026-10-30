# herbst_focus — the focus/peek keybinds (mod-s grid, frame cycling).
# Sourced by the herbstluftwm autostart's keys.d
# loop; stow-merged from this package.

# ModShift-r: rotate the tree (>3 frames) or cycle frames forward; on
# a single frame it cycles windows in the opposite direction of
# ModShift-w.
keyreg $ModCtrl-r spawn ~/.local/bin/herbctl get-rotate

keyreg $Mod-e spawn ~/.local/bin/herbctl get-explore

# cycle; was $Mod-s / $ModShift-s
# zoom/peek grid — focuses the frame below first; when there is none,
# falls back to the window cycle / pseudotile toggle
# The floating branch: `attr tags.focus.floating_focused true` focuses
# the floating layer AND doubles as the "are there (non-minimized)
# floats" conditional — it fails on an empty floating layer, falling
# through to the alternatives (the failure is quieted in the
# hc_send-error-daemon's QUIET_MATCH).
keyreg $Mod-s spawn ~/.local/bin/herbctl get-south
