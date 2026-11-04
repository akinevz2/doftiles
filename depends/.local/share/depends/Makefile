# depends — package dependency Makefile (the dots/<pkg>/.local/share/<pkg>
# pattern). Every package that deploys BINARIES routes its installation
# through its own Makefile; this one execs the package-local command
# `depends/.local/bin/components` (stowed to ~/.local/bin/components):
# bun, bun trust, herbctl — and polyframes with its install method
# recorded in ~/.config/doftiles.conf.
#
# The dots Makefile reaches here via `on-deploy packages install`
# (after stowing). The dots Makefile ALSO builds ~/.local/bin/on-deploy
# itself (bootstrap) — installing components is a package concern, but
# a missing on-deploy binary is the dots repo's bootstrap problem.
#
# All seven standard rules are defined; start/stop/enable/disable are
# deliberate no-ops — these are plain binaries, not services.

COMPONENTS ?= $(HOME)/.local/bin/components

install:
	@if [ -x "$(COMPONENTS)" ]; then \
		$(COMPONENTS) || { echo "depends: components FAILED" >&2; exit 1; }; \
	else \
		echo "depends: ~/.local/bin/components missing — stow the depends package (make -C ~/dots depends)" >&2; \
		exit 1; \
	fi

start stop enable disable:
	@echo "depends: nothing to $@ — the deployed artifacts are plain binaries"

uninstall:
	@$(COMPONENTS) --uninstall; \
	echo "depends: polyframes artifact removed (herbctl binary left; rm -f ~/.local/bin/herbctl to drop it)"

status:
	@for bin in polyframes herbctl on-deploy components; do \
		if [ -x "$(HOME)/.local/bin/$$bin" ]; then st=installed; else st=MISSING; fi; \
		printf '  %-12s %s\n' "$$bin" "$$st"; \
	done
	@if [ -f "$(HOME)/.config/doftiles.conf" ]; then \
		printf '  %-12s %s\n' method "$$(grep '^POLYFRAMES_METHOD' $(HOME)/.config/doftiles.conf | cut -d= -f2)"; \
	fi

.PHONY: install start stop enable disable uninstall status
