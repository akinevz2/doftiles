# polkit — STOW METAPACKAGE (the wsl shape: opt-in wiring, no
# submodule): the polkit authentication agent for the herbst session —
# the piece that draws the root dialog when pkexec fires (gdebi's apt
# step depends on it).
#
# The apt package is policykit-1-gnome (Ubuntu's build of the GNOME
# polkit agent). It ships NO binary on PATH — only an XDG autostart
# entry with OnlyShowIn=XFCE;Unity;X-Cinnamon, which a herbstluftwm
# session never satisfies, and xdg-desktop-autostart.target is dead
# here — so NEITHER the wm.depends binary walk NOR the distro
# autostart can carry it. This adapter owns the install (through the
# <target>.deploy protocol, exact package name) and the package owns
# the session wiring: polkit-agent.service (stowed alongside).

.PHONY: build install uninstall status

# the dots-relative deploy script (the <target>.deploy protocol)
DEPLOY := $(HOME)/dots/depends/.local/bin/install/ubuntu.deploy

FORCE ?=
DRY   ?=
export FORCE DRY

# the apt package this metapackage covers
PKG := policykit-1-gnome
# the agent binary the package installs (NOT on PATH — /usr/lib)
AGENT := /usr/lib/policykit-1-gnome/polkit-gnome-authentication-agent-1

.DEFAULT_GOAL := status

# build rung — a pkg-only package has nothing to compile
build:
	@echo "polkit: pkg-only package — the adapter owns the deploy (no binary for the walk)"

# ── install: the exact package name through the <target>.deploy ──────
# ── protocol (ubuntu.deploy exact-match fast path; sudo may ask)   ──
install:
	@if dpkg -s $(PKG) >/dev/null 2>&1; then \
		echo "polkit: $(PKG) installed"; \
	else \
		cmd=$$($(DEPLOY) install $(PKG)) || exit 1; \
		echo "         running: $$cmd"; \
		[ "$(DRY)" = 1 ] && exit 0; \
		sh -c "$$cmd" || exit 1; \
		echo "polkit: enable the session unit with 'make services-check'"; \
	fi

uninstall:
	@echo "polkit: no uninstall (system packages stay; remove by hand if ever needed)"

status:
	@if dpkg -s $(PKG) >/dev/null 2>&1; then \
		echo "  $(PKG)  installed"; \
	else \
		echo "  $(PKG)  MISSING"; \
	fi
	@if [ -x $(AGENT) ]; then \
		printf "  agent unit  "; systemctl --user is-active polkit-agent.service 2>/dev/null || true; \
	else \
		echo "  agent binary  MISSING"; \
	fi
