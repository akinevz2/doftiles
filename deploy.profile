# deploy.profile — platform provisioning for on-deploy provision
# session: HOW the graphical session starts
#   greetd       a display manager owns the console (bare-OS targets)
#   wsl-systemd  NO display manager — hlwm runs as the systemd user
#                unit herbst.service, waiting for the Windows-side X
#                server (VcXsrv) to be reachable
session = wsl-systemd
#
# features (one per line): xserver | xinitrc | greeter | nested | xrdp
# none of the primary-profile features for this WSL2 host — the X
# server is the Windows app. The nested stack (Xvfb :1 + x11vnc :5900
# + noVNC :6080) IS running here, and the xrdp feature layers RDP
# :3390 onto the same shared framebuffer (xrdp's Xvnc module attaches
# to x11vnc; connect an RDP client to the WSL IP; 3389 is deliberately
# left free for the Windows side's own RDP/portproxy).
features = nested xrdp
units = xvfb x11vnc novnc
# env: none needed — the units' DISPLAY defaults (localhost:0.0/1.0)
# come from the unit files themselves.
# NOTE (2026-10): the running services bind :1 (old unit text) while
# the deployed units read :0 — restart xvfb/x11vnc to reconcile when
# the primary session is not active.
