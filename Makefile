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
# submodule map 2026-11 (GITMODULES.git + system.required are in step):
#   dots/on-deploy/.local/share/on-deploy | dots/herbctl/.local/share/herbctl
#   dots/herbstutil/.local/share/herbstutil | dots/polyframes/.local/share/polyframes
#   dots/bat/.local/share/bat-src
#
# Exit codes: 2 env/precondition, 1 operational failure, 0 ok/no-op.

SHELL  := /bin/bash
MAKE   := make
SELF   := $(MAKE) --no-print-directory

ONDEPLOY_BIN    := $(HOME)/.local/bin/on-deploy
# the toolchains may live OUTSIDE the invoking shell's PATH (a
# non-login make run carries no ~/.profile): the checks + builds in
# this Makefile and the on-deploy verbs it drives resolve bun/rustup
# through the standard user toolchain dirs FIRST
export PATH := $(HOME)/.bun/bin:$(HOME)/.cargo/bin:$(PATH)
ONDEPLOY_SUBMOD := $(CURDIR)/depends/.local/share/on-deploy# manifests (read by on-deploy, not by this Makefile)
WM_PACKAGES_FILE := stows.required
WM_PACKAGES      := $(shell grep -vi '^#' $(WM_PACKAGES_FILE))

# deployment knobs: FORCE=1 -> on-deploy runs without confirmations (--force -f) and
# recovers from stow conflicts (repo unstow, then retry)
F := $(if $(filter 1,$(FORCE)),-f,)

# the per-package depends Makefile of a stow package (make -f; the
# 2026-11 scheme) — run from the package directory
DEPS_MAKEFILE = -C $(CURDIR)/$(1) --no-print-directory -f \
	.local/state/depends/$(1).Makefile

.PHONY: depends bootstrap trust toolchain submodules bun rustup clean-upgrade configure \
	depends-% \
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

# bootstrap — PHASE 2: the toolchain recipes (bun + rustup; each
# queries through on-deploy and installs via the system package
# manager only when absent), then the bun postinstall trust steps, and
# the configured system.required walk (sync + build + install per
# package Makefile). Explicit chain: make depends bootstrap install
bootstrap: depends bun rustup
	@$(SELF) trust
	$(ONDEPLOY_BIN) depends --install $(F)

# bun / rustup — the toolchain recipes (DISPENSABLE in-name file-style
# targets: deliberately NOT in .PHONY, though no file `bun`/`rustup`
# exists at the repo root — they re-run every make, and the --check
# query makes an installed toolchain a cheap no-op). The install goes
# through the system package manager (on-deploy's `<target>.deploy`
# walk), which needs root: the sudo prerequisite collects the grant
# UPFRONT (a clean TTY before anything runs) and ERRORS OUT (never
# hangs) when it cannot be obtained — sudo-via-make fails on purpose.
bun:
	@$(SELF) sudo
	@if $(ONDEPLOY_BIN) toolchain --bun --check; then \
		echo "bun: present — the toolchain recipe is a no-op"; \
	else \
		$(ONDEPLOY_BIN) toolchain --bun --yes $(F); \
	fi

rustup:
	@$(SELF) sudo
	@if $(ONDEPLOY_BIN) toolchain --rustup --check; then \
		echo "rustup: present — the toolchain recipe is a no-op"; \
	else \
		$(ONDEPLOY_BIN) toolchain --rustup --yes $(F); \
	fi

# trust — the bun postinstall policy steps for every checked-out bun
# submodule: per-checkout local trust + the global untrusted set. The
# logic lives in the herbstutil adapter (it owns the artifact).
trust:
	@$(MAKE) $(call DEPS_MAKEFILE,herbstutil) trust-local trust-global

# toolchain — the language toolchains alone (the migrated flow: run
# after make depends): composed of the per-toolchain verbs, BOTH
# checked (each verb: the --check query first, the system install only
# when absent — the FORCE knob feeds --yes/-f).
toolchain: depends
	$(ONDEPLOY_BIN) toolchain --bun --check || $(ONDEPLOY_BIN) toolchain --bun --yes $(F)
	$(ONDEPLOY_BIN) toolchain --rustup --check || $(ONDEPLOY_BIN) toolchain --rustup --yes $(F)

# configure — the reconfiguration gate for clean-upgrade (before stow):
# on an upgrade the deployment knobs may have changed — offer the TUI
# reconfiguration menu to the human on an INTERACTIVE terminal. A
# non-interactive shell may only proceed with FORCE=1 (the recorded
# config is applied as-is — what the remote/CI upgrades want); anything
# else errors out instead of hanging on the TUI.
configure:
	@if [ -t 0 ] || [ -n "$(F)" ]; then \
		$(ONDEPLOY_BIN) configure $(F); \
	else \
		echo "configure: non-interactive shell without FORCE=1 — refusing the reconfiguration menu" >&2; \
		echo "  rerun with FORCE=1 to re-apply the recorded config (on-deploy configure --force)" >&2; \
		exit 2; \
	fi

# help — the recipe listing
help:
	@echo "recipes:"
	@echo "  depends    submodules at recorded pins + the on-deploy deploy"
	@echo "  bootstrap  bun + rustup recipes + trust + the deps walk"
	@echo "  bun/rustup toolchain recipes: --check query, system install, sudo-gated"
	@echo "  update     fetch + ff + submodule sync + on-deploy rebuild + walk"
	@echo "  clean-upgrade  pull + submodule re-anchor + healing clean + rebuild + stow"
	@echo "  install    configure + preserve + packages install (wm.required)"
	@echo "  configure  the reconfiguration gate: TUI menu on a tty, else FORCE=1 or error"
	@echo "  all/stow/wm/restow  stow the wm.required stack"
	@echo "  stow-<pkg>/unstow-<pkg>  per-package stow/unstow (stow-depends...)"
	@echo "  depends-<pkg>  ONE submodule: toolchain check + scoped walk"

	@echo "  unstow/clean  drop the links"
	@echo "  status / services-check|start|stop / restart"
	@echo "  FORCE=1    the non-interactive + fail-safe knob (retry after unstow)"

# ── on-deploy itself ──────────────────────────────────────────────────
# on-deploy — ALWAYS rebuilds dots/on-deploy/.local/bin/on-deploy from the
# submodule checkout (dots/on-deploy/.local/share/on-deploy; bun through
# npm when bun itself is missing),
# then DEPLOYS the depends package (a pull must land a fresh binary
# even when a stale one is installed).
on-deploy:
	@$(MAKE) -C depends --no-print-directory -f .local/state/depends/depends.Makefile install FORCE=1
	@# the omitted recipe was stow-on-deploy: on a fresh clone (the
	@# clean-upgrade flow) nothing is stowed yet — the fresh binary sits
	@# at dots/on-deploy/.local/bin/on-deploy with NO ~/.local/bin link;
	@# stow the package FIRST so the link pre-exists the binary's first
	@# routing use (ONDEPLOY_RUN in the pattern verbs also falls back to
	@# the package artifact for the same reason)
	@$(SELF) stow-on-deploy
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
# unstow-herbctl...): each routes the package through on-deploy. NOTE
# the pattern verbs do NOT pull in the on-deploy build — composition
# with a fresh binary is explicit (the on-deploy target = adapter
# build + stow-depends). The binary is resolved THROUGH the home link
# first, ELSE the package artifact directly: on a fresh clone (the
# clean-upgrade flow) the ~/.local/bin link does not exist yet because
# the on-deploy package was never stowed — the chicken-and-egg break.
ONDEPLOY_RUN := $(shell if [ -x "$(ONDEPLOY_BIN)" ]; then echo $(ONDEPLOY_BIN); else echo $(CURDIR)/on-deploy/.local/bin/on-deploy; fi)

stow-%:
	@$(ONDEPLOY_RUN) stow --only "$*"

unstow-%:
	@$(ONDEPLOY_RUN) unstow --only "$*"

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
# (fallback --rebase --autostash), submodule sync, then the BOOTSTRAP
# chain (it reaches bat through the toolchain recipes — an update on a
# machine where bun/rustup dropped out or rustup lost its default
# toolchain can no longer dead-end mid-walk: bun/rustup recipes ensure
# them first, the same way `make bootstrap` does). SKIP_ONDEPLOY=1 in
# the walk keeps the on-deploy artifact out of the adapters (already
# fresh from the unconditional rebuild).
update:
	git fetch
	git merge --ff-only 2>/dev/null || git pull --rebase --autostash
	git submodule sync
	git submodule update --init --recursive
	# toolchain assurance ONLY when the check says missing: the recipes'
	# sudo prerequisite is skipped entirely on a healthy machine (a
	# headless update must not demand a root grant for a no-op)
	@$(ONDEPLOY_BIN) toolchain --bun --check || $(SELF) bun FORCE=$(FORCE)
	@$(ONDEPLOY_BIN) toolchain --rustup --check || $(SELF) rustup FORCE=$(FORCE)
	$(SELF) on-deploy
	@SKIP_ONDEPLOY=1 $(ONDEPLOY_BIN) depends --install $(F) || { \
		if [ -n "$(F)" ]; then \
			echo "update: FORCE=1 — repo stow failed; unstowing before retry"; \
			$(ONDEPLOY_RUN) unstow $(F); \
			systemctl --user daemon-reload 2>/dev/null || true; \
			echo "update: unstow done; units reload; no restart"; \
			SKIP_ONDEPLOY=1 $(ONDEPLOY_BIN) depends --install $(F); \
			systemctl --user daemon-reload 2>/dev/null || true; \
			units=$$(sed -e 's/#.*//' -e '/^[[:space:]]*$$/d' $(CURDIR)/services.required | tr -s ' \t' '\n' | grep -v '^$$'); \
			for u in $$units; do systemctl --user enable --no-block "$$u" 2>/dev/null || true; done; \
		else \
			echo "update: stow failed — rerun with FORCE=1 to unstow and retry" >&2; \
			exit 1; \
		fi; \
	}

# clean-upgrade — the LAYOUT-HEAL upgrade (2026-11): the full sequence for
# a machine whose on-disk deployment predates the CURRENT layout (the
# resplit doctrine: each bun submodule hosts its own stow package; depends
# is the special meta-package — no submodule config, no artifacts, build/
# link delegate into dots/on-deploy). Exactly what a resplit half-landed
# system needs, in order:
#   1. the pull (fetch + ff-only, fallback rebase --autostash) so the new
#      .gitmodules + Makefiles + package files ARE here
#   2. submodule sync + re-init: both WORKING COPIES and the absorbed
#      module gitdirs get re-anchored at the new paths (git rm --cached +
#      moved worktrees leave the gitlinks at the old paths; a stale
#      core.worktree silently serves the dead checkout)
#   3. the healing clean (depends.Makefile): unstow the depends package,
#      sweep the stale residue plain stow -D cannot match (folded/per-file
#      links into dots/depends/.local/share/<pkg> and dangling
#      ~/.local/{bin,share} links for the moved artifacts), drop the
#      legacy artifact copies from dots/depends/.local/bin (it refuses on
#      any file without an owner artifact), restow depends (remnants) +
#      every owning package
#   4. the binary: rebuild + redeploy dots/on-deploy/.local/bin/on-deploy
#      from the freshly anchored checkout (master `on-deploy` target)
#   5. make stow: the full stack restows with NO conflicts — the whole
#      point of steps 3-4 (a conflict here means a non-owned real file
#      sits at a link target; stow's message names it, inspect by hand)
clean-upgrade:
	git fetch
	git merge --ff-only 2>/dev/null || git pull --rebase --autostash
	git submodule sync
	git submodule update --init --recursive
	@$(MAKE) -C depends --no-print-directory -f .local/state/depends/depends.Makefile clean
	@$(SELF) on-deploy
	@$(SELF) configure
	@$(SELF) stow

# depends-% — ONE submodule package install (make depends-bat,
# depends-herbctl, depends-herbstutil, depends-polyframes — any
# submodule in system.required; an unknown name fails inside the walk
# with the misconfiguration report). The bulk walk (depends --install)
# silently assumes its prerequisites; the explicit verb honors them:
#   1. the on-deploy binary exists (a fresh clone: `make depends` first)
#   2. the package's toolchain REALLY works — the --check query fails
#      LOUDLY pointing at `make bun`/`make rustup` (their sudo grant is
#      inherent to the system install) instead of a cryptic mid-build
#      "could not choose a version of cargo" error
#   3. only then the scoped walk (synced, --only <pkg>, FORCE-threaded)
depends-%:
	@if [ ! -x "$(ONDEPLOY_BIN)" ]; then $(SELF) depends; fi
	@tool=$$([ "$*" = bat ] && echo rustup || echo bun); \
	if ! $(ONDEPLOY_BIN) toolchain --$$tool --check; then \
		echo "depends-$*: the '$$tool' toolchain is missing or unusable — run 'make $$tool' first (system install, sudo-gated)" >&2; \
		exit 2; \
	fi
	$(ONDEPLOY_BIN) depends --install --only "$*" $(F)

# on-deploy housekeeping verbs stay one call away:
#   $(ONDEPLOY_BIN) preserve <pkg> ...   conflict-safe restow
#   $(ONDEPLOY_BIN) archive <pkg>        record-container backups
#   $(ONDEPLOY_BIN) unarchive <pkg>      restore them
#   $(ONDEPLOY_BIN) configure --show     current configuration
#   $(ONDEPLOY_BIN) toolchain --bun|--rustup   language toolchains
#   $(ONDEPLOY_BIN) depends              submodule deploy step
# add them as Makefile targets only when they need a sequence.
