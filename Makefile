# dots — delegation-only Makefile.
#
# Every target here is a SHORT sequence of on-deploy commands (the
# one exception is `_bootstrap-on-deploy`, which builds the on-deploy
# binary itself — it cannot exist before it runs). All procedural
# deployment logic lives in the on-deploy binary
# (depends/.local/share/on-deploy, installed to ~/.local/bin/on-deploy)
# except installing components (bun, herbctl, polyframes), which belongs
# to the depends package: depends/.local/share/depends/Makefile ->
# depends/.local/bin/components.
#
# The verbs (on-deploy --help):
#   check search install pkg configure packages
#   stow unstow enable disable archive unarchive preserve services
#
# Exit codes: 2 env/precondition, 1 operational failure, 0 ok/no-op.

SHELL  := /bin/bash
MAKE   := make
SELF   := $(MAKE) --no-print-directory

ONDEPLOY_BIN    := $(HOME)/.local/bin/on-deploy
ONDEPLOY_SUBMOD := $(CURDIR)/depends/.local/share/on-deploy

# manifests (read by on-deploy, not by this Makefile)
WM_PACKAGES_FILE := wm.packages
WM_PACKAGES      := $(shell grep -vi '^#' $(WM_PACKAGES_FILE))

# the stow set for bulk targets
STOW_ONLY := $(patsubst %,--only %,$(WM_PACKAGES))

.PHONY: bootstrap submodules _bootstrap-on-deploy install all stow wm \
        restow unstow clean status services-check services-start \
        services-stop restart update deps

# ── bootstrap ─────────────────────────────────────────────────────────
# Full deployment in ONE call, safe on a systemd target with no
# running window manager. Nothing procedural here — each step is an
# on-deploy command:
#   submodules        the dependency checkouts, at their remote tips
#   _bootstrap-on-deploy            build ~/.local/bin/on-deploy
#   components        bun + trust + herbctl + polyframes (depends pkg)
#   configure         edit the manifests (+ fold: applies itself;
#                     prompts for the git identity when ~/.my-credentials
#                     is absent)
#   install           the wm.requires requirement walk (installs the
#                     missing binaries from the target's repos)
#   stow              stow -R every package in wm.packages
#   packages install  each package's own dependency Makefile rules
#   services check    daemon-reload + enable --now every service.order
#                     unit (units needing X stay enabled-but-failed)
#   status            the closing report
bootstrap: submodules _bootstrap-on-deploy
	@-$(ONDEPLOY_BIN) configure
	@-$(ONDEPLOY_BIN) install
	$(ONDEPLOY_BIN) stow --only "$(WM_PACKAGES)"
	$(ONDEPLOY_BIN) packages install
	$(SELF) services-check
	$(SELF) status
	@echo "bootstrap: complete"

# submodules — ensure every dependency subrepo is initialized AND at
# its remote tip (--remote): the depends components builders and the
# on-deploy build compile from these checkouts, so they must be fresh
# before anything runs.
submodules:
	git submodule update --init --recursive --remote

# _bootstrap-on-deploy — the one recipe that must stay: it builds the
# on-deploy binary itself when missing (bun-through-npm fallback), so
# the delegation targets below have something to call.
_bootstrap-on-deploy:
	@if [ -x "$(ONDEPLOY_BIN)" ]; then \
		echo "on-deploy: $(ONDEPLOY_BIN) deployed already — skipping"; \
		exit 0; \
	fi; \
	if [ ! -f "$(ONDEPLOY_SUBMOD)/src/index.ts" ]; then \
		echo "on-deploy: submodule checkout missing — run 'make submodules' first" >&2; \
		exit 1; \
	fi; \
	if ! command -v bun >/dev/null 2>&1; then \
		if ! command -v npm >/dev/null 2>&1; then \
			echo "on-deploy: neither bun nor npm found — install node/npm first (arch: pacman -S npm)" >&2; \
			exit 1; \
		fi; \
		echo "on-deploy: bun missing — installing through npm"; \
		npm install --global bun; \
	fi; \
	cd "$(ONDEPLOY_SUBMOD)" && bun install; \
	cd "$(ONDEPLOY_SUBMOD)" && bun x bunli build --targets linux-x64 --minify; \
	mv -f "$(ONDEPLOY_SUBMOD)/dist/index" "$(ONDEPLOY_SUBMOD)/dist/on-deploy"; \
	rm -f "$(ONDEPLOY_SUBMOD)/dist/index.map"; \
	mkdir -p "$(HOME)/.local/bin"; \
	install -m 755 "$(ONDEPLOY_SUBMOD)/dist/on-deploy" "$(ONDEPLOY_BIN)"; \
	echo "on-deploy: installed $(ONDEPLOY_BIN)"

# ── stowing ───────────────────────────────────────────────────────────
# install — stow the stack, then run each package's dependency
# Makefile (dots/<pkg>/.local/share/<pkg>/Makefile). The on-deploy
# binary is bootstrapped FIRST so the delegations below can run;
# `configure` is NOT folded in here (the interactive bootstrap does
# it; incremental runs keep the recorded configuration).
install: _bootstrap-on-deploy
	@set -e; \
	$(ONDEPLOY_BIN) stow --only "$(WM_PACKAGES)"; \
	$(ONDEPLOY_BIN) packages install; \
	$(SELF) status

# all / stow / wm — restow the wm.packages stack (stow -R per package)
all stow wm restow: _bootstrap-on-deploy
	@$(ONDEPLOY_BIN) stow --only "$(WM_PACKAGES)"

# unstow / clean — remove the links (the user's real files stay)
unstow clean: _bootstrap-on-deploy
	@$(ONDEPLOY_BIN) unstow --only "$(WM_PACKAGES)"

# ── services (the service.order manifest, driven by on-deploy) ────────
services-check: _bootstrap-on-deploy
	@$(ONDEPLOY_BIN) services check

services-start: _bootstrap-on-deploy
	@$(ONDEPLOY_BIN) services start

services-stop: _bootstrap-on-deploy
	@$(ONDEPLOY_BIN) services stop

restart: _bootstrap-on-deploy
	@$(ONDEPLOY_BIN) services restart

# ── reporting / maintenance ───────────────────────────────────────────
status: _bootstrap-on-deploy
	@-$(ONDEPLOY_BIN) check
	@$(ONDEPLOY_BIN) services status
	@if [ ! -f "$(HOME)/.my-credentials" ]; then \
		echo "status: reminder — $(HOME)/.my-credentials is not set up; run 'on-deploy configure' on a tty to record your git identity"; \
	fi

# deps — the manifests must exist, then the safe pull + refresh the
# components the way update does
deps: wm
	@if ! ls -al $(WM_PACKAGES_FILE) wm.requires service.order; then \
		exit 1; \
	fi
	@$(SELF) update

# update — the safe pull directly in the repo: fetch + fast-forward
# (fallback --rebase --autostash), submodule sync, then re-run the
# components install (--force: refresh the artifacts per the recorded
# method; the submodule bump lands in the checkout).
update:
	git fetch
	git merge --ff-only
	git pull --rebase --autostash 2>/dev/null || true
	git submodule sync
	git submodule update --init --recursive
	$(ONDEPLOY_BIN) packages install --only depends

# on-deploy housekeeping verbs stay one call away:
#   $(ONDEPLOY_BIN) preserve <pkg> ...   conflict-safe restow
#   $(ONDEPLOY_BIN) archive <pkg>        record-container backups
#   $(ONDEPLOY_BIN) unarchive <pkg>      restore them
#   $(ONDEPLOY_BIN) configure --show     current configuration
# add them as Makefile targets only when they need a sequence.
