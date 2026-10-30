# depends — deployment and dependency management for doftiles.
#
# Owns the deployable dependencies (currently polyframes) and the safe
# repo update flow. The install method of each deployable is tracked
# in ~/.config/doftiles.conf (stowed from this package) so `update`
# and `uninstall` know how the artifact was deployed.
#
# polyframes deployment invariant (either recipe ends here):
#   ~/.local/bin/polyframes exists and [module/polyframes] execs it.

SHELL := /bin/bash

POLYFRAMES_SUBMODULE := .local/share/polyframes
POLYFRAMES_REPO      ?= https://github.com/akinevz2/polyframes
POLYFRAMES_NPM       ?= github:akinevz2/polyframes
POLYFRAMES_BIN       ?= $(HOME)/.local/bin/polyframes
CONF                 := $(HOME)/.config/doftiles.conf

# --- conf helpers -------------------------------------------------------
# The conf is a flat KEY=VALUE file (sh-sourceable). It lives in the
# repo via stow, so method changes show up as a tracked diff.
#   make conf-get VAR=POLYFRAMES_METHOD
#   make conf-set  VAR=POLYFRAMES_METHOD VAL=npm
conf-get:
	@. $(CONF) 2>/dev/null && printf '%s\n' "$${!VAR:-}"

conf-set:
	@touch $(CONF); \
	if grep -q "^$(VAR)=" $(CONF); then \
		sed -i 's/^$(VAR)=.*/$(VAR)=$(VAL)/' $(CONF); \
	else \
		echo "$(VAR)=$(VAL)" >> $(CONF); \
	fi; \
	echo "$(VAR)=$(VAL)"

# --- polyframes: build from the git submodule checkout ------------------
# Conditional clone: initializes the submodule from the URL recorded in
# .gitmodules only when the checkout is missing; otherwise refreshes it.
deploy-fromsource:
	@test -d $(POLYFRAMES_SUBMODULE)/.git || \
	    git submodule update --init -- $(POLYFRAMES_SUBMODULE)
	git -C $(POLYFRAMES_SUBMODULE) pull --ff-only
	$(MAKE) -C $(POLYFRAMES_SUBMODULE) install
	@$(MAKE) --no-print-directory conf-set VAR=POLYFRAMES_METHOD VAL=source

# --- polyframes: install from npm ---------------------------------------
# Requires the package to be published; pre-publish the git URL installs
# the source tree (the bin entry runs through bun).
deploy-fromnpm:
	npm install --global $(POLYFRAMES_NPM)
	@$(MAKE) --no-print-directory conf-set VAR=POLYFRAMES_METHOD VAL=npm

# --- update -------------------------------------------------------------
# 1. the dots repo: fast-forward, falling back to a rebase with
#    autostash (local changes ride along, conflicts stop for manual
#    resolution — nothing is ever silently discarded);
# 2. submodules: sync to the commits recorded by the superproject;
# 3. the polyframes artifact: refresh per the recorded install method.
update:
	@git fetch origin; \
	if git merge --ff-only origin/main 2>/dev/null; then \
		echo "update: fast-forwarded to origin/main"; \
	elif git pull --rebase --autostash origin main; then \
		echo "update: rebased onto origin/main"; \
	fi
	@git submodule update --init --recursive
	@. $(CONF) 2>/dev/null; \
	case "$${POLYFRAMES_METHOD:-none}" in \
		source) \
			git -C $(POLYFRAMES_SUBMODULE) pull --ff-only && \
			$(MAKE) -C $(POLYFRAMES_SUBMODULE) install ;; \
		npm) \
			npm install --global $(POLYFRAMES_NPM) ;; \
		*) \
			echo "update: polyframes not deployed by doftiles" \
			    "(POLYFRAMES_METHOD=$${POLYFRAMES_METHOD:-unset})" ;; \
	esac

# --- uninstall ----------------------------------------------------------
# Removes the deployed artifact per the recorded method; the submodule
# checkout is left in place (it is version-controlled content).
uninstall:
	@. $(CONF) 2>/dev/null; \
	case "$${POLYFRAMES_METHOD:-none}" in \
		npm) \
			npm uninstall --global polyframes ;; \
		source) \
			rm -f $(POLYFRAMES_BIN) ;; \
		*) \
			echo "uninstall: nothing recorded in $(CONF)" ;; \
	esac; \
	$(MAKE) --no-print-directory conf-set VAR=POLYFRAMES_METHOD VAL=none

.PHONY: conf-get conf-set deploy-fromsource deploy-fromnpm update uninstall
