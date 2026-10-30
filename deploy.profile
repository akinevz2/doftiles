# deploy.profile — platform provisioning for on-deploy provision
# session: HOW the graphical session starts
#   greetd       a display manager owns the console (bare-OS targets)
#   wsl-systemd  NO display manager — hlwm runs as the systemd user
#                unit herbst.service, waiting for the Windows-side X
#                server (VcXsrv) to be reachable
session = wsl-systemd
#
# features (one per line): xserver | xinitrc | greeter
# none for this WSL2 host — the X server is the Windows app.
