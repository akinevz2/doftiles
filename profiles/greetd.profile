# profiles/greetd.profile — the DISPLAY-MANAGER profile: greetd +
# tuigreet own the console; the user picks herbstluftwm from the
# greeter's session list (the xsessions entry provision writes).
session = greetd
env = DISPLAY=:0
features = xserver xinitrc greeter
units = compton dunst hc_send-error-daemon
