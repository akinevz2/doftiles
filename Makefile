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

.PHONY: depends bootstrap trust toolchain submodules \
	on-deploy \
	install all stow wm \
	restow unstow clean status services-check services-start \
	services-stop restart update help

# ── depends ────────────────────────────────────────────────────────────
# PHASE 1 of the bootstrap: submodules at their recorded pins, then the
# bootstrap deployable (depends.Makefile: bun-ensure through npm when
# even bun is missing + build + link:: the router swaps + stows the
# depends package). ONLY on-deploy — nothing else: it cannot start the
# platform toolchains yet.
depends:
	git submodule sync
	git submodule update --init --recursive
	@$(SELF) on-deploy

# sudo — the pre-flight grant: the root-check lives here (recipes that
# need root depend on this target). As root we just proceed; otherwise
# the grant is collected UPFRONT (a clean TTY, before anything else
# runs — the mid-flight sudo prompt inside the TUI flows broke the
# terminal echo). With the grant missing (non-tty or declined) the
# make ERRORS OUT and asks for the sudo rerun.
sudo:
	@if [ "$$(id -u)" = 0 ]; then \
		echo "sudo: running as root already"; \
	elif sudo -n true 2>/dev/null; then \
		echo "sudo: cached grant present"; \
	elif [ -t 0 ]; then \
		echo "sudo: collecting the root grant UPFRONT (the rustup platform install needs it; no mid-run prompts)"; \
		sudo -v || { echo "sudo: declined — rerun with: sudo make bootstrap" >&2; exit 2; }; \
	else \
		echo "sudo: this recipe needs root — rerun with: sudo make bootstrap" >&2; \
		exit 2; \
	fi

# bootstrap — PHASE 2: on-deploy installs the REST of the bootstrap:
# bun (no-op when the system ships it — assumed) and rustup (bat's
# source route), the bun postinstall trust steps, and the configured
# system.required walk (sync + build + install per package Makefile).
# Explicit chain: make depends bootstrap install
bootstrap: depends
	@$(SELF) sudo
	$(ONDEPLOY_BIN) toolchain --bun $(Y)
	$(ONDEPLOY_BIN) toolchain --rustup $(Y)
	@$(SELF) trust
	$(ONDEPLOY_BIN) depends --install $(Y)

# trust — the bun postinstall policy steps for every checked-out bun
# submodule: per-checkout local trust + the global untrusted set. The
# logic lives in the herbstutil adapter (it owns the artifact).
trust:
	@$(MAKE) $(call DEPS_MAKEFILE,herbstutil) trust-local trust-global

# toolchain — the language toolchains alone (the migrated flow: run
# after make depends).
toolchain: depends
	$(ONDEPLOY_BIN) toolchain --bun $(Y)

# help — the recipe listing
help:
	@echo "recipes:"
	@echo "  depends    submodules at recorded pins + the on-deploy deploy"
	@echo "  bootstrap  the toolchains (bun/rustup) + trust + the deps walk"
	@echo "  toolchain  bun alone (make depends first)"
	@echo "  update     fetch + ff + submodule sync + on-deploy rebuild + walk"
	@echo "  install    configure + preserve + packages install (wm.required)"
	@echo "  all/stow/wm/restow  stow the wm.required stack"
	@echo "  stow-<pkg>/unstow-<pkg>  per-package stow/unstow (stow-depends...)"

	@echo "  unstow/clean  drop the links"
	@echo "  status / services-check|start|stop / restart"
	@echo "  FORCE=1    the non-interactive + fail-safe knob (retry after unstow)"

# ── on-deploy itself ──────────────────────────────────────────────────
# on-deploy — ALWAYS rebuilds ~/.local/bin/on-deploy from the
# submodule checkout (bun through npm when bun itself is missing),
# then DEPLOYS the depends package (a pull must land a fresh binary
# even when a stale one is installed).
on-deploy:
	@$(MAKE) -C depends --no-print-directory -f .local/state/depends/depends.Makefile install FORCE=1
	@$(SELF) stow-depends

# submodules — the REMOTE variant (the depends components build from
# these checkouts): explicit only, the recorded-pins doctrine is the
# default path.
submodules:
	git submodule update --init --recursive --remote

# ── stowing ───────────────────────────────────────────────────────────
# install — configure FIRST (same apply; prompts for the git identity
# when ~/.my-credentials is absent), then resolve conflicts per package
# (preserve), then run each package's OLD-pattern dependency Makefile —
# ONLY the packages manifested in wm.required. The SUBMODULES are
# deployed by the bootstrap chain (make depends bootstrap) — target order:
#   make depends bootstrap install
install: on-deploy
	@set -e; \
	$(ONDEPLOY_BIN) configure; \
	rc=$$?; \
	if [ $$rc -eq 130 ]; then exit 130; elif [ $$rc -ne 0 ]; then echo "install: configure FAILED — continuing (recorded config kept)"; fi; \
	$(ONDEPLOY_BIN) preserve --only "$(WM_PACKAGES)"; \
	$(ONDEPLOY_BIN) packages install $(WM_PACKAGES); \
	$(SELF) status

# all / stow / wm — restow the wm.required stack (stow -R per package)
all stow wm restow: on-deploy
	@$(ONDEPLOY_BIN) stow --only "$(WM_PACKAGES)"

# stow-<dots-package> / unstow-<dots-package> — the per-package pattern
# spelling of the stow/unstow flows (make stow-depends, make
# unstow-herbctl...): each routes the package through on-deploy after
# the binary is fresh (a pull must land a fresh binary even when a
# stale one is installed)
stow-%: on-deploy
	@$(ONDEPLOY_BIN) stow --only "$*"

unstow-%: on-deploy
	@$(ONDEPLOY_BIN) unstow --only "$*"

# unstow / clean — remove the links (the user's real files stay)
unstow clean: on-deploy
	@$(ONDEPLOY_BIN) unstow --only "$(WM_PACKAGES)"

# ── services (the services.required manifest, driven by on-deploy) ────────
services-check: on-deploy
	@$(ONDEPLOY_BIN) services check

services-start: on-deploy
	@$(ONDEPLOY_BIN) services start

services-stop: on-deploy
	@$(ONDEPLOY_BIN) services stop

restart: on-deploy
	@$(ONDEPLOY_BIN) services restart

# ── reporting / maintenance ───────────────────────────────────────────
status: on-deploy
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
	$(SELF) on-deploy
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
