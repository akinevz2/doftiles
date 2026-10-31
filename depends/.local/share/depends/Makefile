# depends — package dependency Makefile (the dots/<pkg>/.local/share/<pkg>
# pattern). Every package that deploys BINARIES routes its dependency
# management through on-deploy; this Makefile is the package-side entry
# point the dots Makefile calls (make install runs `install` here after
# stowing).
#
# Artifacts owned by this package:
#   ~/.local/bin/polyframes   (on-deploy deps; method in
#                              ~/.config/doftiles.conf)
#   ~/.local/bin/herbctl      (on-deploy toolchain)
#   ~/.local/bin/on-deploy    (bootstrap-built; toolchain keeps it)
#
# All seven standard rules are defined; start/stop/enable/disable are
# deliberate no-ops — these are plain binaries, not services.

ONDEPLOY ?= $(HOME)/.local/bin/on-deploy

install:
	@if [ -x "$(ONDEPLOY)" ]; then \
		$(ONDEPLOY) toolchain || { echo "depends: toolchain FAILED" >&2; exit 1; }; \
		$(ONDEPLOY) deps || { echo "depends: deps FAILED" >&2; exit 1; }; \
	else \
		echo "depends: on-deploy missing — run 'make bootstrap' in ~/dots first" >&2; \
		exit 1; \
	fi

start stop enable disable:
	@echo "depends: nothing to $@ — the deployed artifacts are plain binaries"

uninstall:
	@if [ -x "$(ONDEPLOY)" ]; then \
		$(ONDEPLOY) deps --uninstall; \
		echo "depends: polyframes artifact removed (herbctl/on-deploy binaries left; rm -f ~/.local/bin/{herbctl,on-deploy} to drop them)"; \
	else \
		echo "depends: on-deploy missing" >&2; exit 1; \
	fi

status:
	@for bin in polyframes herbctl on-deploy; do \
		if [ -x "$(HOME)/.local/bin/$$bin" ]; then st=installed; else st=MISSING; fi; \
		printf '  %-12s %s\n' "$$bin" "$$st"; \
	done
	@if [ -f "$(HOME)/.config/doftiles.conf" ]; then \
		printf '  %-12s %s\n' method "$$(grep '^POLYFRAMES_METHOD' $(HOME)/.config/doftiles.conf | cut -d= -f2)"; \
	fi

.PHONY: install start stop enable disable uninstall status
