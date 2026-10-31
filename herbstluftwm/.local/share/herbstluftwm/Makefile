# herbstluftwm — package dependency Makefile (the dots/<pkg>/
# .local/share/<pkg> pattern). The WM stack's binary dependency is
# herbctl (the keybind state machines); it is built and installed by
# `on-deploy toolchain`, so every rule here defers to on-deploy.
#
# The WM services themselves (herbst/compton) are owned by the dots
# Makefile service.order flow; start/stop/enable/disable here act on
# THIS package's units only.

UNITS := herbst.service compton.service
ONDEPLOY ?= $(HOME)/.local/bin/on-deploy

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

.PHONY: install start stop enable disable uninstall status
