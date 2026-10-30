# profiles/nested.profile — the NESTED profile: herbstluftwm inside an
# Xvfb framebuffer on :1, shared over VNC (:5901) and browser-noVNC
# (:6081). The "temporary" profile — co-installable with the primary
# profile (its units own :0; the nested stack owns :1 exclusively).
#
# Browse in at http://localhost:6081 (novnc serves the nested desktop).
# dunst is intentionally NOT enabled here: the primary profile's dunst
# already shows notifications; two instances would fight over the bus.
session = nested
features = nested
units = xvfb-nested x11vnc-nested novnc-nested herbst-nested hc_send-error-daemon
