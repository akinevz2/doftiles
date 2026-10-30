# profiles/xinit.profile — the NATIVE profile: a real X server on the
# console, the session started by startx running ~/.xinitrc (which execs
# herbstluftwm; no display manager). For bare-OS machines (the friend's
# arch box).
session = xinit
env = DISPLAY=:0
features = xserver xinitrc
units = compton dunst hc_send-error-daemon
