# dots — delegation-only Makefile.
#
# Every target here is a SHORT sequence of on-deploy commands (the
# exception builds the on-deploy binary itself — it cannot exist before
# it runs: the depends PACKAGE hosts the bootstrap deployable
# (dots/depends/.local/share/depends/depends/Makefile; the adapter's
# bun-ensure goes through npm and the source route runs entirely
# locally). All procedural deployment logic lives in the on-deploy
# binary (built from depends/.local/share/on-deploy, installed to
# ~/.local/bin/on-deploy); installing the SUBMODULES is a package
# concern: each stow package owns its recipes in
# dots/<pkg>/.local/share/depends/<pkg>/Makefile, driven by
# `on-deploy depends --build|--install` (the `depends` target).
#
# The verbs (on-deploy --help):
#   check search install pkg configure packages
#   stow unstow enable disable archive unarchive preserve services
#   toolchain depends
#
# submodule map 2026-11 (GITMODULES.git + system.depends are in step):
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
# the stow-deployed user bins belong on PATH for the checks: `missing()`
# in on-deploy resolves on PATH only — ~/.local/bin must come first, or
# every stow-deployed artifact (polyframes... the WM helper scripts)
# reports MISSING and the platform resolver dead-ends (a SOURCE package
# never resolves through <target>.deploy)
export PATH := $(HOME)/.local/bin:$(PATH)
ONDEPLOY_SUBMOD := $(CURDIR)/depends/.local/share/on-deploy# manifests (read by on-deploy, not by this Makefile)
WM_PACKAGES_FILE := stow.depends
WM_PACKAGES      := $(shell grep -vi '^#' $(WM_PACKAGES_FILE))

# deployment knobs: FORCE=1 -> on-deploy runs without confirmations (--force -f) and
# recovers from stow conflicts (repo unstow, then retry)
F := $(if $(filter 1,$(FORCE)),-f,)

# WHEN CONFIGURE RUNS (the install target): only on a CLEAN-INSTALL (no
# recorded doftiles.conf yet), when a required manifest/recorded-conf
# file is modified or conflicting (post-rebase UU/DD noise included),
# or when a rebase is still mid-flight. Otherwise the recorded
# configuration suffices and configure is SKIPPED (the wizard would
# otherwise re-open on every install).
RECONFIGURE_REASON := $(shell cd "$(CURDIR)" && \
	if [ ! -f "$$HOME/.config/doftiles.conf" ]; then \
		echo clean-install; \
	elif [ -n "$$(git status --porcelain -- stows.required wm.required system.required services.required depends/.config/doftiles.conf)" ]; then \
		echo required-files-modified-or-conflicting; \
	elif [ -d .git/rebase-merge ] || [ -d .git/rebase-apply ]; then \
		echo rebase-in-progress; \
	fi)

# the per-package depends Makefile of a stow package (make -f; the
# 2026-11 scheme) — run from the package directory
DEPS_MAKEFILE = -C $(CURDIR)/$(1) --no-print-directory -f \
	.local/share/depends/$(1)/Makefile

.PHONY: depends bootstrap trust toolchain submodules bun rustup force-upgrade configure livereload \
	depends-% \
	on-deploy \
	install all stow wm \
	restow unstow clean status services-check services-start \
	services-stop restart update help add-packages

# ── depends ────────────────────────────────────────────────────────────
# PHASE 1 of the bootstrap: submodules at their recorded pins, then the
# bootstrap deployable (depends.Makefile: bun-ensure through npm when
# even bun is missing + build + link:: the router swaps + stows the
# depends package). ONLY on-deploy — nothing else: it cannot start the
# platform toolchains yet.
# depends — named after the *.depends manifests it services: restore
# any pull-pending personal manifests (pop + re-skip — the stash half
# runs inline in the pull targets, update / force-upgrade), then the
# submodule sync + update at recorded pins + the on-deploy bootstrap
# build.
depends:
	@if [ -s $(MANIFEST_STATE) ]; then \
		git stash pop 2>/dev/null \
			|| echo "depends: stash pop CONFLICTED — resolve by hand (the stash is kept)"; \
		for m in $(MANIFESTS); do git update-index --skip-worktree $$m 2>/dev/null || true; done; \
		rm -f $(MANIFEST_STATE); \
	fi
	git submodule sync
	# ALWAYS LATEST, ONE LEVEL ONLY: --remote pulls each submodule's
	# branch tip; the bare (non-recursive) update stops at the first
	# level — bat's deep nested submodules are skipped (they take a
	# very long time to update every time).
	git submodule update --init --remote
	# REATTACH TO main: --remote leaves detached HEADs (the checkout
	# is at the branch tip, but the submodule HEAD is not a branch) —
	# attach each submodule's HEAD to `main` (the tracked branch of
	# this repo's own submodules; the upstream's branch is the
	# default branch of the remote — resolved via the remote HEAD) so
	# the next commit/push inside the checkout lands on the branch,
	# not a detached HEAD. Only the FIRST-level submodules are touched
	# (the deep nested ones stay detached — upstream's asset
	# submodules).
	git submodule foreach --quiet 'b=$(git config -f .gitmodules --get submodule."$displaypath".branch 2>/dev/null); [ -n "$b" ] || b=main; git checkout -q -B "$b" 2>/dev/null; true'
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
		echo "sudo: collecting root grant; no mid-run prompts"; \
		sudo -v || { echo "sudo: declined — rerun with: sudo make bootstrap" >&2; exit 2; }; \
	else \
		echo "sudo: this recipe needs root — rerun with: sudo make bootstrap" >&2; \
		exit 2; \
	fi

# bootstrap — PHASE 2: the toolchain recipes (bun + rustup; each
# queries through on-deploy and installs via the system package
# manager only when absent), then the bun postinstall trust steps, and
# the configured system.depends walk (sync + build + install per
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
	@if $(ONDEPLOY_BIN) toolchain --bun --check; then \
		echo "bun: present (skip)"; \
	else \
		$(SELF) sudo || exit 1; \
		$(ONDEPLOY_BIN) toolchain --bun --yes $(F); \
	fi

rustup:
	@if $(ONDEPLOY_BIN) toolchain --rustup --check; then \
		echo "rustup: present (skip)"; \
	else \
		$(SELF) sudo || exit 1; \
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

# configure — the reconfiguration gate for force-upgrade (before stow):
# on an upgrade the deployment knobs may have changed — offer the TUI
# reconfiguration menu to the human on an INTERACTIVE terminal. A
# non-interactive shell may only proceed with FORCE=1 (the recorded
# config is applied as-is — what the remote/CI upgrades want); anything
# else errors out instead of hanging on the TUI.
configure:
	@if [ -t 0 ] || [ -n "$(F)" ]; then \
		$(ONDEPLOY_BIN) configure $(F); \
		$(MANIFEST_SKIP); \
	else \
		echo "configure: non-tty, no FORCE=1" >&2; \
		echo "  rerun: FORCE=1 make configure" >&2; \
		exit 2; \
	fi

# help — the recipe listing
help:
	@echo "recipes:"
	@echo "  depends    submodule sync + update at recorded pins + the on-deploy deploy"
	@echo "  bootstrap  depends + bun + rustup (+ the trust steps)"
	@echo "  bun        ensure the bun toolchain: --check query first, sudo-gated"
	@echo "      install when absent"
	@echo "  rustup     ensure the rustup toolchain: --check query first, sudo-gated"
	@echo "      install when absent"
	@echo "  trust      the bun postinstall policy steps (herbstutil package)"
	@echo "  toolchain  depends + both toolchain recipes (each --check first)"
	@echo "  configure  the reconfiguration gate: TUI menu on a tty, else"
	@echo "      FORCE=1 or error"
	@echo "  on-deploy  rebuild the binary from its checkout + stow the package"
	@echo "  submodules  submodule update --init --recursive --remote"
	@echo "  install    configure + preserve + packages install (wm.depends)"
	@echo "  all        stow the wm.depends stack"
	@echo "  stow       stow the wm.depends stack (the submodule build first)"
	@echo "  wm         stow the wm.depends stack"
	@echo "  restow     stow the wm.depends stack (the same recipe, restowed)"
	@echo "  build      compile the binary-deployed submodules from source"
	@echo "  stow-<pkg>  ONE package: on-deploy stow --only"
	@echo "  unstow-<pkg>  ONE package: on-deploy unstow --only"
	@echo "  depends-<pkg>  ONE submodule: toolchain check + scoped walk"
	@echo "  unstow     drop the wm.depends stack's links"
	@echo "  clean      drop the wm.depends stack's links"
	@echo "  update     fetch + ff + submodule sync + on-deploy rebuild + walk"
	@echo "  force-upgrade  pull + healing clean + the depends re-anchor/rebuild"
	@echo "      + stow"
	@echo "  livereload  restow unit pkgs, daemon-reload, per-unit reload"
	@echo "  status     on-deploy check + services status + the credentials"
	@echo "      reminder"
	@echo "  services-check  on-deploy services check"
	@echo "  services-start  on-deploy services start"
	@echo "  services-stop  on-deploy services stop"
	@echo "  restart    on-deploy services restart"
	@echo "  add-packages  the wm.depends binary walk: verify + install the"
	@echo "      missing (YES=1 headless; sudo grant on a tty)"
	@echo "knobs:"
	@echo "  FORCE=1    the non-interactive + fail-safe knob (retry after unstow)"

# add-packages — the wm.depends requirement walk: verify every binary,
# install the MISSING ones through the <target>.deploy protocol (the
# package resolution is the deploy script's; sudo prompts on a tty).
# Headless: YES=1 installs without confirmations (still needs the sudo
# grant); without it the walk fails fast listing the missing binaries.
add-packages:
	@$(ONDEPLOY_BIN) install $(if $(YES),--yes)

# ── on-deploy itself ──────────────────────────────────────────────────
# on-deploy — rebuilds dots/on-deploy/.local/bin/on-deploy from the
# submodule checkout WHEN THE CHECKOUT IS FRESHER than the artifact
# (a pull updates the source mtimes, so pulled changes always land a
# fresh binary; FORCE=1 forces). The depends package hosts the
# bootstrap build; the adapter build + stow ride on every invocation.
on-deploy:
	@$(MAKE) -C depends --no-print-directory -f .local/share/depends/depends/Makefile install FORCE=$(FORCE)
	@# the omitted recipe was stow-on-deploy: on a fresh clone (the
	@# force-upgrade flow) nothing is stowed yet — the fresh binary sits
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
	git submodule update --init --remote

# ── stowing ───────────────────────────────────────────────────────────
# install — configure FIRST (same apply; prompts for the git identity
# when ~/.my-credentials is absent), then resolve conflicts per package
# (preserve), then run each package's OLD-pattern dependency Makefile —
# ONLY the packages manifested in wm.depends. The SUBMODULES are
# deployed by the bootstrap chain (make depends bootstrap) — target order:
#   make depends bootstrap install
install: on-deploy
	@set -e; \
	reason='$(RECONFIGURE_REASON)'; \
	if [ -n "$$reason" ]; then \
		echo "install: configure ($$reason)"; \
		ONDEPLOY_INSTALL_CHAIN=1 $(ONDEPLOY_BIN) configure; \
	else \
		echo "install: configure skipped (config recorded; manifests clean — 'on-deploy configure' to edit)"; \
	fi; \
	rc=$$?; \
	if [ $$rc -eq 130 ]; then exit 130; elif [ $$rc -ne 0 ]; then echo "install: configure FAILED — continuing (recorded config kept)"; fi; \
	$(ONDEPLOY_BIN) preserve --only "$(WM_PACKAGES)"; \
	$(ONDEPLOY_BIN) packages install $(WM_PACKAGES); \
	$(SELF) status

# all / stow / wm — restow the wm.depends stack (stow -R per package)
# WITH the submodule build first: the binary-deployed submodules (herbctl)
# ship their compiled artifact as the package bin — a fresh checkout
# (make update / depends) only reaches the system when the build runs
# and re-folds the binary into the package's .local/bin. stow therefore
# depends on the build step, so `make stow` deploys the latest source.
all stow wm restow: on-deploy build
	@$(ONDEPLOY_BIN) stow --only "$(WM_PACKAGES)"

# build — compile each binary-deployed submodule from its checkout into
# the package bin (the committed artifact is the deployable): a fresh
# checkout (make update / depends) only reaches the system when the
# build runs and re-folds the binary into the package's .local/bin.
# The per-package router-Makefiles (.local/share/depends/<pkg>/Makefile)
# own the concrete steps (deps-install, compile, rename-artifact, link);
# this target just walks them — on-deploy's own build lives in the
# on-deploy target (the bootstrap).
build: on-deploy update
	@for m in $(wildcard */.local/share/depends/*/Makefile); do \
		[ -f "$$m" ] || continue; \
		grep -q "^build:" "$$m" || continue; \
		pkg=$${m%%/.local/share/depends/*}; \
		echo "==$$pkg build"; \
		$(MAKE) -C "$$pkg" --no-print-directory -f ".local/share/depends/$$pkg/Makefile" build || exit 1; \
	done

# stow-<dots-package> / unstow-<dots-package> — the per-package pattern
# spelling of the stow/unstow flows (make stow-depends, make
# unstow-herbctl...): each routes the package through on-deploy. NOTE
# the pattern verbs do NOT pull in the on-deploy build — composition
# with a fresh binary is explicit (the on-deploy target = adapter
# build + stow-depends). The binary is resolved THROUGH the home link
# first, ELSE the package artifact directly: on a fresh clone (the
# force-upgrade flow) the ~/.local/bin link does not exist yet because
# the on-deploy package was never stowed — the chicken-and-egg break.
ONDEPLOY_RUN := $(shell if [ -x "$(ONDEPLOY_BIN)" ]; then echo $(ONDEPLOY_BIN); else echo $(CURDIR)/on-deploy/.local/bin/on-deploy; fi)

stow-%:
	@$(ONDEPLOY_RUN) stow --only "$*"

unstow-%:
	@$(ONDEPLOY_RUN) unstow --only "$*"

# unstow / clean — remove the links (the user's real files stay)
unstow clean: on-deploy
	@$(ONDEPLOY_BIN) unstow --only "$(WM_PACKAGES)"

# ── services (the services.depends manifest, driven by on-deploy) ────────
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

# the skip-worktree dance — manifests (MANIFESTS) are tracked but users
# hide their personal dirtiness with `git update-index --skip-worktree`;
# a pull bringing upstream manifest changes would otherwise fight the
# user. The STASH half runs inline in the pull targets (update /
# force-upgrade); the RESTORE half lives in `depends` — the file-named
# rule for the *.depends manifests — which every pull target invokes
# right after its pull. A stash-pop CONFLICT is the volition point:
# resolve by hand (the stash is kept for recovery).
MANIFESTS := stow.depends wm.depends system.depends services.depends
MANIFEST_STATE := .git/doftiles-manifest-skip

define MANIFEST_STASH
	: > $(MANIFEST_STATE); \
	for m in $(MANIFESTS); do \
		git ls-files --error-unmatch $$m >/dev/null 2>&1 || continue; \
		flag=$$(git ls-files -v $$m | cut -c1); \
		[ "$$flag" = S ] || continue; \
		git update-index --no-skip-worktree $$m; \
		if git diff --quiet -- $$m && git diff --cached --quiet -- $$m; then \
			continue; \
		fi; \
		if git stash push -q -m "doftiles manifest $$m" -- $$m; then \
			echo $$m >> $(MANIFEST_STATE); \
		else \
			git update-index --skip-worktree $$m; \
		fi; \
	done
endef

# MANIFEST_SKIP — flag DIRTY manifests skip-worktree (after a configure
# edit personalizes them). Clean manifests are deliberately NOT flagged:
# an S-flagged clean file would silently block its own mainline updates.
define MANIFEST_SKIP
	for m in $(MANIFESTS); do \
		git ls-files --error-unmatch $$m >/dev/null 2>&1 || continue; \
		if ! git diff --quiet -- $$m 2>/dev/null || \
		   ! git diff --cached --quiet -- $$m 2>/dev/null; then \
			git update-index --skip-worktree $$m 2>/dev/null || true; \
		fi; \
	done
endef

# update — the safe pull directly in the repo: fetch + fast-forward
# (fallback --rebase --autostash), submodule sync, then the BOOTSTRAP
# chain (it reaches bat through the toolchain recipes — an update on a
# machine where bun/rustup dropped out or rustup lost its default
# toolchain can no longer dead-end mid-walk: bun/rustup recipes ensure
# them first, the same way `make bootstrap` does). SKIP_ONDEPLOY=1 in
# the walk keeps the on-deploy artifact out of the adapters (already
# fresh from the unconditional rebuild).
update:
	$(MANIFEST_STASH)
	git fetch
	git merge --ff-only 2>/dev/null || git pull --rebase --autostash
	@$(SELF) depends
	# NO submodule installs here (pinned checkouts only): modules get
	# synced/local, nothing is built or deployed — so a chained
	# `make update install` does not run the install step twice. The
	# on-deploy binary IS rebuilt (fresh source must land a fresh
	# binary; the depends rule above owns that build); everything else
	# installs via the explicit targets.
	# toolchain assurance ONLY when the check says missing: the recipes'
	# sudo prerequisite is skipped entirely on a healthy machine (a
	# headless update must not demand a root grant for a no-op)
	@$(ONDEPLOY_BIN) toolchain --bun --check || $(SELF) bun FORCE=$(FORCE)
	@$(ONDEPLOY_BIN) toolchain --rustup --check || $(SELF) rustup FORCE=$(FORCE)

# force-upgrade — the LAYOUT-HEAL upgrade (2026-11): the full sequence for
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
force-upgrade:
	$(MANIFEST_STASH)
	git fetch
	git merge --ff-only 2>/dev/null || git pull --rebase --autostash
	@$(MAKE) -C depends --no-print-directory -f .local/share/depends/depends/Makefile clean
	@$(SELF) depends
	@$(SELF) configure
	@$(SELF) stow

# depends-% — ONE submodule package install (make depends-bat,
# depends-herbctl, depends-herbstutil, depends-polyframes — any
# submodule in system.depends; an unknown name fails inside the walk
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
		echo "depends-$*: $$tool missing — run make $$tool" >&2; \
		exit 2; \
	fi
	$(ONDEPLOY_BIN) depends --install --only "$*" $(F)

# herbst (Alias=x-window-manager) is a bulletproof reload: the WM binary
# MUST NOT restart (only force-upgrade may) — the reconfig goes through
# herbstclient reload. dunst has ExecReload (dunstctl); compton and
# hc_send-error-daemon only reload by restart; check-x-server is an
# X-probe — never touched live.
# NOTE systemd re-reads herbst/dunst ExecReload only after a reload of
# the unit files — the restow + daemon-reload below happens BEFORE any
# service reload.
livereload: on-deploy
	@$(ONDEPLOY_RUN) check
	@units=$$(sed -e 's/#.*//' -e '/^[[:space:]]*$$/d' $(if $(wildcard services.depends),services.depends,services.required) | tr -s ' \t' '\n' | grep -v '^$$'); \
	pkgs=""; \
	for u in $$units; do \
		p=""; \
		for t in $(CURDIR)/*/.config/systemd/user/$$u.service; do \
			[ -e "$$t" ] || continue; \
			d=$${t#$(CURDIR)/}; p=$${d%%/*}; \
		done; \
		[ -n "$$p" ] && pkgs="$$pkgs $$p" || echo "livereload: no unit $$u"; \
	done; \
	pkgs=$$(tr ' ' '\n' <<< "$$pkgs" | sort -u | tr '\n' ' '); \
	echo "livereload: restow $$pkgs"; \
	$(ONDEPLOY_RUN) stow --only "$$pkgs" || exit 1; \
	systemctl --user daemon-reload 2>/dev/null || true; \
	DISP=$$(systemctl --user show-environment 2>/dev/null | sed -n 's/^DISPLAY=//p'); \
	[ -n "$$DISP" ] || DISP=$$($(ONDEPLOY_RUN) detect-server --dry-run 2>/dev/null || true); \
	DISP=$${DISP:-localhost:0.0}; \
	export DISPLAY=$$DISP; \
	for u in $$units; do \
		case $$u in \
			herbst) \
				herbstclient reload 2>/dev/null \
					&& echo "herbst: reloaded (binary kept)" \
					|| echo "herbst: no WM? reload FAIL" >&2;; \
			check-x-server) :;; \
			*) \
				systemctl --user try-reload-or-restart --no-block $$u 2>/dev/null \
					&& echo "$$u: reload" \
					|| echo "$$u: reload FAIL" >&2;; \
		esac; \
	done

# on-deploy housekeeping verbs stay one call away:
#   $(ONDEPLOY_BIN) preserve <pkg> ...   conflict-safe restow
#   $(ONDEPLOY_BIN) archive <pkg>        record-container backups
#   $(ONDEPLOY_BIN) unarchive <pkg>      restore them
#   $(ONDEPLOY_BIN) configure --show     current configuration
#   $(ONDEPLOY_BIN) toolchain --bun|--rustup   language toolchains
#   $(ONDEPLOY_BIN) depends              submodule deploy step
# add them as Makefile targets only when they need a sequence.
