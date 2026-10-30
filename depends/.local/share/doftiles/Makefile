# doftiles deployment Makefile — the repo-side copy lives at
# <repo>/depends/.local/share/doftiles and is stowed to
# ~/.local/share/doftiles (the same files through the stow link).
# Every path anchors to the REAL location of this file, so the recipes
# work identically from either side.
#
# Owns the deployable dependencies (currently polyframes) and the safe
# repo update flow. The install method of each deployable is tracked
# in ~/.config/doftiles.conf so `update` and `uninstall` know how the
# artifact was deployed.
#
# polyframes deployment invariant (either recipe ends here):
#   ~/.local/bin/polyframes exists and [module/polyframes] execs it.

SHELL := /bin/bash

SELF   := $(lastword $(MAKEFILE_LIST))
ROOT   := $(patsubst %/,%,$(dir $(realpath $(SELF))))
DOTS   := $(abspath $(ROOT)/../../../..)
SUBMOD := $(DOTS)/depends/.local/share/polyframes
SUBREL := depends/.local/share/polyframes

POLYFRAMES_REPO ?= https://github.com/akinevz2/polyframes
POLYFRAMES_NPM  ?= github:akinevz2/polyframes
POLYFRAMES_BIN  ?= $(HOME)/.local/bin/polyframes
CONF            := $(HOME)/.config/doftiles.conf

# Toolchain-free artifact (github release asset, glibc linux-x64):
# the fallback path so machines without bun can still install.
RELEASE_ASSET ?= polyframes-linux-x64
RELEASE_URL   ?= $(POLYFRAMES_REPO)/releases/latest/download/$(RELEASE_ASSET)

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
		sed -i --follow-symlinks 's/^$(VAR)=.*/$(VAR)=$(VAL)/' $(CONF); \
	else \
		echo "$(VAR)=$(VAL)" >> $(CONF); \
	fi; \
	echo "$(VAR)=$(VAL)"

# --- polyframes: build from the git submodule checkout ------------------
# polyframes-sync — ensure the submodule checkout exists, put it on its
# main branch at the remote tip (the recorded commit is a detached
# checkout; the deployable should track the branch), and fast-forward.
# The submodule URL is https (see .gitmodules) — no git username or SSH
# key is ever needed to clone it; `sync` rewrites any stale recorded
# URL (e.g. from before the repo switched to https) back to .gitmodules.
# NOTE: this advances the checkout past the commit the superproject
# records — `git status` shows the submodule as modified; commit the
# bump when you want the new pin.
polyframes-sync:
	git -C $(DOTS) submodule sync -- $(SUBREL)
	git -C $(DOTS) submodule update --init -- $(SUBREL)
	git -C $(SUBMOD) checkout -q -B main origin/main
	git -C $(SUBMOD) pull --ff-only

deploy-fromsource: polyframes-sync
	@command -v bun >/dev/null 2>&1 || { \
		echo "deploy-fromsource: bun not found — install it (arch: pacman -S bun)" >&2; \
		echo "  or deploy via npm instead: make -C $(HOME)/.local/share/doftiles deploy-fromnpm" >&2; \
		exit 1; }
	cd $(SUBMOD) && bun install
	$(MAKE) -C $(SUBMOD) install
	@$(MAKE) --no-print-directory conf-set VAR=POLYFRAMES_METHOD VAL=source

# --- polyframes: install from npm ---------------------------------------
# Requires the package to be published; pre-publish the git URL installs
# the source tree (the bin entry runs through bun).
deploy-fromnpm:
	@command -v npm >/dev/null 2>&1 || { \
		echo "deploy-fromnpm: npm not found — install it (arch: pacman -S npm)" >&2; \
		exit 1; }
	npm install --global $(POLYFRAMES_NPM)
	@$(MAKE) --no-print-directory conf-set VAR=POLYFRAMES_METHOD VAL=npm

# --- polyframes: install the github release asset -------------------------
# No git clone, no bun, no npm: fetch the latest release artifact over
# https (public repo, no credentials) straight into ~/.local/bin —
# the friend-arch path that never happens to have a JS toolchain.
deploy-fromrelease:
	@command -v curl >/dev/null 2>&1 || command -v wget >/dev/null 2>&1 || { \
		echo "deploy-fromrelease: neither curl nor wget found (arch: pacman -S curl)" >&2; \
		exit 1; }
	@tmp=$$(mktemp /tmp/polyframes-install.XXXXXX); \
	rc=0; \
	if command -v curl >/dev/null 2>&1; then \
		curl -fL --retry 3 --user-agent doftiles-deploy $(RELEASE_URL) -o "$$tmp" || rc=1; \
	else \
		wget -q -O "$$tmp" $(RELEASE_URL) || rc=1; \
	fi; \
	if [ $$rc -eq 0 ]; then \
		install -m 755 "$$tmp" $(POLYFRAMES_BIN); \
		rm -f "$$tmp"; \
		$(MAKE) --no-print-directory conf-set VAR=POLYFRAMES_METHOD VAL=release; \
		echo "deploy-fromrelease: installed $(RELEASE_URL) -> $(POLYFRAMES_BIN)"; \
	else \
		rm -f "$$tmp"; \
		echo "deploy-fromrelease: download failed from $(RELEASE_URL)" >&2; \
		exit 1; \
	fi

# --- deploy --------------------------------------------------------------
# Dispatch on the recorded install method; no record (or "none") tries
# a source build when bun exists and falls back to the toolchain-free
# release download otherwise.
deploy:
	@. $(CONF) 2>/dev/null; \
	method=$${POLYFRAMES_METHOD:-none}; \
	if [ "$$method" != npm ] && [ "$$method" != release ] && ! command -v bun >/dev/null 2>&1; then \
		if command -v curl >/dev/null 2>&1 || command -v wget >/dev/null 2>&1; then \
			echo "deploy: bun missing — falling back to the github release artifact"; \
			$(MAKE) --no-print-directory deploy-fromrelease; \
			exit $$?; \
		fi; \
		echo "deploy: neither bun nor curl/wget found — cannot install polyframes (arch: pacman -S bun curl)" >&2; \
		exit 1; \
	fi; \
	case "$$method" in \
		npm)     $(MAKE) --no-print-directory deploy-fromnpm ;; \
		release) $(MAKE) --no-print-directory deploy-fromrelease ;; \
		*)       $(MAKE) --no-print-directory deploy-fromsource ;; \
	esac

# --- ensure ----------------------------------------------------------------
# Idempotent entry point for `make install`/bootstrap: deploy ONLY when
# the artifact is missing, so re-running bootstrap never rebuilds a
# working polyframes. `deploy` remains the force-redeploy handle.
ensure:
	@if [ -x "$(POLYFRAMES_BIN)" ]; then \
		method=$$($(MAKE) --no-print-directory conf-get VAR=POLYFRAMES_METHOD); \
		echo "ensure: $(POLYFRAMES_BIN) already deployed (method=$${method:-unset}) — skipping"; \
	else \
		$(MAKE) --no-print-directory deploy; \
	fi

# --- update --------------------------------------------------------------
# 1. the dots repo: fast-forward, falling back to a rebase with
#    autostash (local changes ride along, conflicts stop for manual
#    resolution — nothing is ever silently discarded);
# 2. submodules: sync to the commits recorded by the superproject;
# 3. the polyframes artifact: refresh per the recorded install method.
update:
	@git -C $(DOTS) fetch origin; \
	if git -C $(DOTS) merge --ff-only origin/main 2>/dev/null; then \
		echo "update: fast-forwarded to origin/main"; \
	elif git -C $(DOTS) pull --rebase --autostash origin main; then \
		echo "update: rebased onto origin/main"; \
	fi
	@git -C $(DOTS) submodule update --init --recursive
	@. $(CONF) 2>/dev/null; \
	case "$${POLYFRAMES_METHOD:-none}" in \
		source) \
			$(MAKE) --no-print-directory polyframes-sync && \
			cd $(SUBMOD) && bun install && \
			$(MAKE) -C $(SUBMOD) install ;; \
		release) \
			$(MAKE) --no-print-directory deploy-fromrelease ;; \
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
		release) \
			rm -f $(POLYFRAMES_BIN) ;; \
		source) \
			rm -f $(POLYFRAMES_BIN) ;; \
		*) \
			echo "uninstall: nothing recorded in $(CONF)" ;; \
	esac; \
	$(MAKE) --no-print-directory conf-set VAR=POLYFRAMES_METHOD VAL=none

.PHONY: conf-get conf-set deploy polyframes-sync deploy-fromsource deploy-fromnpm update uninstall
