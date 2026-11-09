# polybar deployment orchestration.
#
# Owns: running polyctl, and the theme apply. Binary dependency
# management (the polyframes artifact) defers to the depends package's
# `components` command — see dots/depends/.local/share/depends/Makefile.

COMPONENTS ?= $(HOME)/.local/bin/components

theme:
	@# timeout guard: a dead X must fail the hook, never wedge the
	@# caller's `packages install` (runRule captures output — a hang
	@# here is invisible until the caller is interrupted). Guards:
	@# no X / no reloader -> skip with a note (headless deploys keep
	@# their exit code clean); no `timeout` -> the bare command.
	@if [ -z "$${DISPLAY:-}" ] || ! command -v $(HOME)/.local/bin/reload_theme >/dev/null 2>&1; then \
		echo "polybar: theme skipped (no X or no reloader)"; exit 0; \
	fi; \
	if ! herbstclient ping 2>/dev/null; then \
		echo "polybar: theme skipped (no WM)"; exit 0; \
	fi; \
	if command -v timeout >/dev/null 2>&1; then \
		timeout 60 $(HOME)/.local/bin/reload_theme -f || { echo "polybar: theme FAILED (timeout/exit $$?)" >&2; exit 1; }; \
	else \
		$(HOME)/.local/bin/reload_theme -f || { echo "polybar: theme FAILED (exit $$?)" >&2; exit 1; }; \
	fi

install:
	@if [ ! -x "$(HOME)/.local/bin/polyframes" ]; then \
		echo "polybar: polyframes missing — deploy its package: 'make update' (on-deploy depends drives dots/polyframes)" >&2; \
		exit 1; \
	fi; \
	echo "polybar: polyframes present"
	@# -f is NOT propagated through MAKEFLAGS (make strips -C/-f/-o/-W),
	@# so the recursive call re-states the adapter makefile explicitly
	@$(MAKE) --no-print-directory -f $(firstword $(MAKEFILE_LIST)) theme

start:
	~/.local/bin/polyctl up

stop:
	~/.local/bin/polyctl down

enable:
	@echo "polybar: enable is owned by the autostart/herbst session — nothing to do"

disable:
	@echo "polybar: disable is owned by the autostart/herbst session — nothing to do"

uninstall:
	@echo "polybar: config is stow-managed — unstow the polybar package instead; the polyframes artifact uninstalls via the depends package ('make -C ~/dots/depends/.local/share/depends uninstall')"

status:
	@if [ -x "$(HOME)/.local/bin/polyframes" ]; then st=installed; else st=MISSING; fi; \
	printf '  %-12s %s\n' polyframes "$$st"
	@pgrep -af 'polybar' >/dev/null && echo "  bar: running" || echo "  bar: not running"

# "make reload" = the theme + the bar restart (a full refresh).
reload: theme
	~/.local/bin/polyctl reload

up: start

down: stop

.PHONY: theme install start stop enable disable uninstall status reload up down
