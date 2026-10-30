# deploy.profile — platform provisioning features for on-deploy provision
# One feature per line: xserver | xinitrc | greeter
#
# Absent/empty = no provisioning. This WSL2 host: the X server is
# VcXsrv on Windows reached over TCP (localhost:0.0), so nothing to
# provision. A bare-OS target (ubuntu server, the manjaro machine)
# would list:
#   xserver
#   xinitrc
#   greeter
