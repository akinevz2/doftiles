# profiles/wsl.profile — the WSL2 profile: hlwm runs as the systemd
# user unit herbst.service, waiting for the Windows-side X server
# (VcXsrv on localhost:0.0). No display manager, no X packages.
session = wsl-systemd
env = DISPLAY=localhost:0.0
units = herbst compton dunst hc_send-error-daemon
