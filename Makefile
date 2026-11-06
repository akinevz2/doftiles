# dots — delegation-only Makefile.
#
# Every target here is a SHORT sequence of on-deploy commands (the
# exception builds the on-deploy binary itself — it cannot exist before
# it runs: the depends PACKAGE hosts the bootstrap deployable
# (dots/depends/.local/state/depends/depends.Makefile; the adapter's
# bun-ensure goes through npm and the source route runs entirely
# locally). All procedural deployment logic lives in the on-deploy
# binary (built from depends/.local/share/on-deploy, installed to
# ~/.local/bin/on-deploy); installing the SUBMODULES is a package
# concern: each stow package owns its recipes in
# dots/<pkg>/.local/state/depends/<pkg>.Makefile, driven by
# `on-deploy depends --build|--install` (the `depends` target).
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
WM_PACKAGES_FILE := stows.required
WM_PACKAGES      := $(shell grep -vi '^#' $(WM_PACKAGES_FILE))

# deployment knobs: FORCE=1 -> on-deploy runs without confirmations and
# recovers from stow conflicts (repo unstow, then retry)
Y := $(if $(filter 1,$(FORCE)),-y,)

# the per-package depends Makefile of a stow package (make -f; the
# 2026-11 scheme) — run from the package directory
DEPS_MAKEFILE = -C $(CURDIR)/$(1) --no-print-directory -f \
	.local/state/depends/$(1).Makefile

.PHONY: depends trust toolchain submodules \
	build-on-deploy \\
	install all stow wm \
	restow unstow clean status services-check services-start \
	services-stop restart update

# ── depends ────────────────────────────────────────────────────────────
# THE bootstrap + deps chain, merged: submodules at their recorded
# pins -> the bootstrap deployable (depends.Makefile: bun-ensure
# through npm + build + link; the router swaps + stows the depends
# package) -> the configured system.required walk (sync at pins +
# per-package Makefiles) -> the bun trust steps.
depends: submodules
	@command -v stow >/dev/null 2>&1 || { \
		echo "depends: GNU stow missing — install stow (pacman -S stow / apt install stow)" >&2; \
		exit 2; \
	}
	@$(MAKE) -C depends --no-print-directory -f .local/state/depends/depends.Makefile install FORCE=1
	@$(SELF) trust
	$(ONDEPLOY_BIN) depends --install $(Y)

# trust — the bun postinstall policy steps for every checked-out bun
# submodule: per-checkout local trust + the global untrusted set. The
# logic lives in the depends package Makefile (it knows the artifacts).
trust:
	@$(MAKE) $(call DEPS_MAKEFILE,herbstutil) trust-local trust-global

# toolchain — the language toolchains: on-deploy installs the tools the
# per-package Makefiles build with (bun here for starters).
toolchain: depends
	$(ONDEPLOY_BIN) toolchain --bun $(Y)

# ── on-deploy itself ──────────────────────────────────────────────────
# build-on-deploy — ALWAYS rebuilds ~/.local/bin/on-deploy from the
# submodule checkout (bun through npm when bun itself is missing),
# then installs it: a pull must land a fresh binary even when a stale
# one is installed.
build-on-deploy:
	@$(MAKE) -C depends --no-print-directory -f .local/state/depends/depends.Makefile install FORCE=1

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
# ONLY the packages manifested in wm.required. The SUBMODULES are
# deployed by `deps` (on-deploy depends --install) — target order:
#   make bootstrap toolchain deps install
install: build-on-deploy
	@set -e; \
	$(ONDEPLOY_BIN) configure; \
	rc=$$?; \
	if [ $$rc -eq 130 ]; then exit 130; elif [ $$rc -ne 0 ]; then echo "install: configure FAILED — continuing (recorded config kept)"; fi; \
	$(ONDEPLOY_BIN) preserve --only "$(WM_PACKAGES)"; \
	$(ONDEPLOY_BIN) packages install $(WM_PACKAGES); \
	$(SELF) status

# all / stow / wm — restow the wm.required stack (stow -R per package)
all stow wm restow: build-on-deploy
	@$(ONDEPLOY_BIN) stow --only "$(WM_PACKAGES)"

# unstow / clean — remove the links (the user's real files stay)
unstow clean: build-on-deploy
	@$(ONDEPLOY_BIN) unstow --only "$(WM_PACKAGES)"

# ── services (the services.required manifest, driven by on-deploy) ────────
services-check: build-on-deploy
	@$(ONDEPLOY_BIN) services check

services-start: build-on-deploy
	@$(ONDEPLOY_BIN) services start

services-stop: build-on-deploy
	@$(ONDEPLOY_BIN) services stop

restart: build-on-deploy
	@$(ONDEPLOY_BIN) services restart

# ── reporting / maintenance ───────────────────────────────────────────
status: build-on-deploy
	@-$(ONDEPLOY_BIN) check
	@$(ONDEPLOY_BIN) services status
	@if [ ! -f "$(HOME)/.my-credentials" ]; then \
		echo "status: reminder — $(HOME)/.my-credentials is not set up; run 'on-deploy configure' on a tty to record your git identity"; \
	fi

# update — the safe pull directly in the repo: fetch + fast-forward
# (fallback --rebase --autostash), submodule sync, then UNCONDITIONALLY
# rebuild + install the binary from the freshly pulled submodule (a
# stale installed binary may predate the `depends` verb; also, a pull
# must land a fresh binary), and finally the per-package depends
# Makefiles — with the on-deploy artifact SKIPPED in them (already
# fresh; SKIP_ONDEPLOY is understood by the package Makefiles).
update:
	git fetch
	git merge --ff-only 2>/dev/null || git pull --rebase --autostash
	git submodule sync
	git submodule update --init --recursive
	$(SELF) build-on-deploy
	@SKIP_ONDEPLOY=1 $(ONDEPLOY_BIN) depends --install $(Y) || { \
		if [ -n "$(Y)" ]; then \
			echo "update: FORCE=1 — repo stow failed; unstowing before retry"; \
			$(ONDEPLOY_BIN) unstow $(Y); \
			SKIP_ONDEPLOY=1 $(ONDEPLOY_BIN) depends --install $(Y); \
		else \
			echo "update: stow failed — rerun with FORCE=1 to unstow and retry" >&2; \
			exit 1; \
		fi; \
	}

# on-deploy housekeeping verbs stay one call away:
#   $(ONDEPLOY_BIN) preserve <pkg> ...   conflict-safe restow
#   $(ONDEPLOY_BIN) archive <pkg>        record-container backups
#   $(ONDEPLOY_BIN) unarchive <pkg>      restore them
#   $(ONDEPLOY_BIN) configure --show     current configuration
#   $(ONDEPLOY_BIN) toolchain --bun|--rustup   language toolchains
#   $(ONDEPLOY_BIN) depends              submodule deploy step
# add them as Makefile targets only when they need a sequence.
