# herbstluftwm — package dependency Makefile (the dots/<pkg>/
# .local/share/<pkg> pattern). The WM stack's binary dependency is
# herbctl (the keybind state machines); it is built and installed by
# `on-deploy toolchain`, so the standard rules defer to on-deploy.
#
# The FEATURE rules (xserver, xinitrc, nested, xrdp, greeter) hold the
# bash implementations of the session's package-group special steps;
# they defer the platform package-manager work to `on-deploy pkg`.
# The deployment model + features are configured in deploy.profile
# (on-deploy configure); these rules read it for their guards.
# Run them via `on-deploy packages <rule>` or directly:
#   make -C ~/.local/share/herbstluftwm nested
#
# The WM services themselves (herbst/compton) are owned by the dots
# Makefile service.order flow; start/stop/enable/disable here act on
# THIS package's units only.

UNITS := herbst.service
ONDEPLOY ?= $(HOME)/.local/bin/on-deploy
DOTS     ?= $(HOME)/dots
PROFILE  := $(DOTS)/deploy.profile

# the deploy target = the last non-comment line of wm.requires
TARGET := $(shell grep -v '^\s*#' $(DOTS)/wm.requires | tail -1)
ARCH := $(filter arch manjaro,$(TARGET))
PKG := $(if $(ARCH),pacman,apt)

pkg-install:
	@$(ONDEPLOY) pkg install $(1)

install:
	@if [ -x "$(ONDEPLOY)" ]; then \
		$(ONDEPLOY) toolchain || { echo "herbstluftwm: toolchain FAILED (herbctl)" >&2; exit 1; }; \
	else \
		echo "herbstluftwm: on-deploy missing — run 'make bootstrap' in ~/dots first" >&2; \
		exit 1; \
	fi

start:
	@systemctl --user start --no-block $(UNITS)

stop:
	@systemctl --user stop --no-block $(UNITS)

enable:
	@systemctl --user enable $(UNITS)

disable:
	@systemctl --user disable $(UNITS) 2>/dev/null || \
		echo "herbstluftwm: disable was a no-op (linked units: drop the .wants symlinks by hand)"

uninstall:
	@echo "herbstluftwm: nothing to uninstall — config is stow-managed; herbctl is removed with the depends package"

status:
	@echo "== herbstluftwm =="
	@if [ -x "$(HOME)/.local/bin/herbctl" ]; then st=installed; else st=MISSING; fi; \
	printf '  %-12s %s\n' herbctl "$$st"
	@for u in $(UNITS); do \
		printf '  %-20s %s\n' "$$u" "$$(systemctl --user is-active $$u 2>/dev/null)"; \
	done

# xserver — the startx-capable set (managed-X platforms only; the
# wsl-systemd model verifies the EXTERNAL VcXsrv instead)
xserver:
	@if grep -q 'wsl-systemd' $(PROFILE) 2>/dev/null; then \
		echo "xserver: wsl-systemd — external X server, nothing to install"; \
		exit 0; \
	fi; \
	if [ "$(PKG)" = pacman ]; then \
		$(ONDEPLOY) pkg install xorg-server xorg-xinit xorg-xauth; \
	else \
		$(ONDEPLOY) pkg install xserver-xorg-core xserver-xorg xinit xauth; \
	fi

# xinitrc — ~/.xinitrc execs herbstluftwm; other exec lines are
# commented out (xinit runs only the FIRST exec)
xinitrc:
	@if grep -qx 'exec herbstluftwm' $$HOME/.xinitrc 2>/dev/null; then \
		echo "xinitrc: already execs herbstluftwm"; exit 0; fi; \
	if [ -f $$HOME/.xinitrc ]; then \
		sed -i 's|^\s*exec\s|# on-deploy: replaced by herbstluftwm session — |' $$HOME/.xinitrc; \
		printf 'exec herbstluftwm\n' >> $$HOME/.xinitrc; \
		echo "xinitrc: appended exec herbstluftwm"; \
	else \
		printf '#!/bin/sh\n\nexec herbstluftwm\n' > $$HOME/.xinitrc; \
		echo "xinitrc: created $$HOME/.xinitrc"; \
	fi

# nested — the shared framebuffer stack is NOT this package's: xvfb,
# x11vnc and novnc are individual packages (each with its own Makefile,
# deployable independently); xrdp is its own package too. This rule
# only chains their install for convenience.
nested:
	@for pkg in xvfb x11vnc novnc; do \
		$(MAKE) --no-print-directory -C $(DOTS)/$$pkg/.local/share/$$pkg install || exit 1; \
	done

# greeter — a display manager is inherently SYSTEM-level (it owns the
# console before any user session exists): only the package install +
# presence check happen here; no /etc or /usr/share files are written.
# Bare-OS targets must configure greetd by hand (or accept that this
# dots deployment is user-session-only).
greeter:
	@if [ "$(PKG)" = pacman ]; then \
		$(ONDEPLOY) pkg install greetd greetd-tuigreet; \
	else \
		$(ONDEPLOY) pkg install greetd; \
	fi; \
	command -v greetd >/dev/null && echo "greeter: greetd present — system config (/etc/greetd) is NOT managed by dots"

.PHONY: install start stop enable disable uninstall status xserver xinitrc nested greeter
