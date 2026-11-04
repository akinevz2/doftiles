# polybar deployment orchestration.
#
# Owns: running polyctl, and the theme apply. Binary dependency
# management (the polyframes artifact) defers to the depends package's
# `components` command — see dots/depends/.local/share/depends/Makefile.

COMPONENTS ?= $(HOME)/.local/bin/components

theme:
	$(HOME)/.local/bin/reload_theme -f

install:
	@if [ -x "$(COMPONENTS)" ]; then \
		$(COMPONENTS) || { echo "polybar: components FAILED (polyframes)" >&2; exit 1; }; \
	else \
		echo "polybar: components missing — stow the depends package (make -C ~/dots depends)" >&2; \
		exit 1; \
	fi
	@$(MAKE) --no-print-directory theme

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
