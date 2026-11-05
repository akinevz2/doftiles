# dots — delegation-only Makefile.
#
# Every target here is a SHORT sequence of on-deploy commands (the
# exceptions build the on-deploy binary itself — it cannot exist before
# it runs: `_build-on-deploy` (the unconditional rebuild) and
# `_bootstrap-on-deploy` (install it only when missing)). All procedural
# deployment logic lives in the on-deploy binary
# (depends/.local/share/on-deploy, installed to ~/.local/bin/on-deploy);
# installing the SUBMODULES is a package concern: each stow package with
# submodules owns its recipes in
# dots/<pkg>/.local/state/depends/<pkg>.Makefile, driven by
# `on-deploy depends --build|--install` (the `deps` target).
#
# The verbs (on-deploy --help):
#   check search install pkg configure packages
#   stow unstow enable disable archive unarchive preserve services
#   toolchain depends
#
# Exit codes: 2 env/precondition, 1 operational failure, 0 ok/no-op.

SHELL  := /bin/bash
MAKE   := make
SELF   := $(MAKE) --no-print-directory

ONDEPLOY_BIN    := $(HOME)/.local/bin/on-deploy
ONDEPLOY_SUBMOD := $(CURDIR)/depends/.local/share/on-deploy# manifests (read by on-deploy, not by this Makefile)
WM_PACKAGES_FILE := wm.packages
WM_PACKAGES      := $(shell grep -vi '^#' $(WM_PACKAGES_FILE))

# toolchain/deps knobs: YES=1 -> on-deploy runs without confirmations
Y := $(if $(filter 1,$(YES)),-y,)

# the per-package depends Makefile of a stow package (make -f; the
# 2026-11 scheme) — run from the package directory
DEPS_MAKEFILE = -C $(CURDIR)/$(1) --no-print-directory -f \
	.local/state/depends/$(1).Makefile

.PHONY: bootstrap trust toolchain deps submodules \
	_bootstrap-on-deploy _build-on-deploy \
	install all stow wm \
	restow unstow clean status services-check services-start \
	services-stop restart update

# ── bootstrap ─────────────────────────────────────────────────────────
# DEPLOY ON-DEPLOY TO THE SYSTEM, nothing else — the delegation seed:
#   submodules            the dependency checkouts, at their remote tips
#   _bootstrap-on-deploy  install the binary when missing (fresh
#                         systems; bun is bootstrapped through npm
#                         inside the build when neither bun nor the
#                         platform provide it)
#   stow depends          the package lands in $HOME (the on.deploy
#                         shim + the install/ deploy scripts the
#                         binary's own machinery needs)
#   trust                 the bun-submodule trust steps (delegates to
#                         the depends package Makefile)
# A FULL deployment is the explicit chain now:
#   make bootstrap toolchain deps install
bootstrap: submodules
	@$(SELF) _bootstrap-on-deploy
	@command -v stow >/dev/null 2>&1 || { \
		echo "bootstrap: GNU stow missing — install stow (pacman -S stow / apt install stow)" >&2; \
		exit 2; \
	}
	stow -R -t "$(HOME)" depends
	@$(SELF) trust
	@echo "bootstrap: on-deploy deployed (full deploy: 'make toolchain deps install')"

# trust — the bun postinstall policy steps for every checked-out bun
# submodule: per-checkout local trust + the global untrusted set. The
# logic lives in the depends package Makefile (it knows the artifacts).
trust:
	@$(MAKE) $(call DEPS_MAKEFILE,depends) trust-local trust-global

# toolchain — the language toolchains: on-deploy installs the tools the
# per-package Makefiles build with (bun here for starters) and
# everything else the `deps` flow needs is delegation now.
toolchain: bootstrap
	$(ONDEPLOY_BIN) toolchain --bun $(Y)

# deps — the manifests must exist, then on-deploy drives the per-package
# depends Makefiles: `depends --install` = sync the submodules, build,
# and install (on-deploy depends --build for sync+build only).
deps: toolchain
	@if ! ls -l $(WM_PACKAGES_FILE) wm.requires service.order; then \
		exit 1; \
	fi
	$(ONDEPLOY_BIN) depends --install $(Y)

# ── on-deploy itself ──────────────────────────────────────────────────
# _build-on-deploy — ALWAYS rebuilds ~/.local/bin/on-deploy from the
# submodule checkout (bun through npm when bun itself is missing), then
# installs the binary. `_bootstrap-on-deploy` skips it when the binary
# already exists; the depends Makefile's on-deploy artifact calls it
# UNCONDITIONALLY (a submodule pull must land a fresh binary even when
# a stale one is installed).
_build-on-deploy:
	@if [ ! -f "$(ONDEPLOY_SUBMOD)/src/index.ts" ]; then \
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
	# bun's own postinstall downloads the bun runtime into os.tmpdir()
	# and renames it into node_modules — on remote boxes /tmp is often
	# tmpfs (EXDEV, cross-device rename); TMPDIR under the module keeps
	# the rename same-device
	cd "$(ONDEPLOY_SUBMOD)" && mkdir -p node_modules/.tmp && \
		TMPDIR="$$(pwd)/node_modules/.tmp" bun install; \
	cd "$(ONDEPLOY_SUBMOD)" && bun x bunli build --targets linux-x64 --minify; \
	mv -f "$(ONDEPLOY_SUBMOD)/dist/index" "$(ONDEPLOY_SUBMOD)/dist/on-deploy"; \
	rm -f "$(ONDEPLOY_SUBMOD)/dist/index.js.map"; \
	mkdir -p "$(HOME)/.local/bin"; \
	install -m 755 "$(ONDEPLOY_SUBMOD)/dist/on-deploy" "$(ONDEPLOY_BIN)"; \
	echo "on-deploy: built + installed $(ONDEPLOY_BIN)"

# _bootstrap-on-deploy — the delegation target seeded by bootstrap:
# installs the binary ONLY when missing (fresh systems), leaving the
# pull-refresh rebuilds to the depends Makefile's on-deploy artifact.
_bootstrap-on-deploy:
	@if [ -x "$(ONDEPLOY_BIN)" ]; then \
		echo "on-deploy: $(ONDEPLOY_BIN) deployed already — skipping"; \
		exit 0; \
	fi; \
	$(SELF) _build-on-deploy

# submodules — ensure every dependency subrepo is initialized AND at
# its remote tip (--remote): the depends components build and the
# on-deploy build compile from these checkouts, so they must be fresh
# before anything runs. `on-deploy depends` resyncs them itself.
submodules:
	git submodule update --init --recursive --remote

# ── stowing ───────────────────────────────────────────────────────────
# install — configure FIRST (same apply; prompts for the git identity
# when ~/.my-credentials is absent), then resolve conflicts per package
# (preserve), then run each package's OLD-pattern dependency Makefile —
# ONLY the packages manifested in wm.packages. The SUBMODULES are
# deployed by `deps` (on-deploy depends --install) — target order:
#   make bootstrap toolchain deps install
install: _bootstrap-on-deploy
	@set -e; \
	$(ONDEPLOY_BIN) configure; \
	rc=$$?; \
	if [ $$rc -eq 130 ]; then exit 130; elif [ $$rc -ne 0 ]; then echo "install: configure FAILED — continuing (recorded config kept)"; fi; \
	$(ONDEPLOY_BIN) preserve --only "$(WM_PACKAGES)"; \
	$(ONDEPLOY_BIN) packages install $(WM_PACKAGES); \
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

# update — the safe pull directly in the repo: fetch + fast-forward
# (fallback --rebase --autostash), submodule sync, then on-deploy drives
# the per-package depends Makefiles — which rebuild the on-deploy binary
# UNCONDITIONALLY as their first artifact, so a pulled submodule always
# lands a fresh binary.
update:
	git fetch
	git merge --ff-only
	git pull --rebase --autostash 2>/dev/null || true
	git submodule sync
	git submodule update --init --recursive
	$(ONDEPLOY_BIN) depends --install $(Y)

# on-deploy housekeeping verbs stay one call away:
#   $(ONDEPLOY_BIN) preserve <pkg> ...   conflict-safe restow
#   $(ONDEPLOY_BIN) archive <pkg>        record-container backups
#   $(ONDEPLOY_BIN) unarchive <pkg>      restore them
#   $(ONDEPLOY_BIN) configure --show     current configuration
#   $(ONDEPLOY_BIN) toolchain --bun|--rustup   language toolchains
#   $(ONDEPLOY_BIN) depends              submodule deploy step
# add them as Makefile targets only when they need a sequence.
