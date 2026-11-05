# dots — delegation-only Makefile.
#
# Every target here is a SHORT sequence of on-deploy commands (the
# exceptions build the on-deploy binary itself — it cannot exist before
# it runs: `_build-on-deploy` (the unconditional rebuild), and
# `on-depends` (submodule pull → rebuild → stow the depends package,
# self-contained so it works on FRESH installs where nothing exists
# yet). All procedural
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

.PHONY: bootstrap submodules _bootstrap-on-deploy _build-on-deploy on-depends \
        install all stow wm \
        restow unstow clean status services-check services-start \
        services-stop restart update deps

# ── bootstrap ─────────────────────────────────────────────────────────
# Full deployment in ONE call, safe on a systemd target with no
# running window manager. The only procedural step is on-depends
# (build + stow the toolchain before any delegation exists); the rest
# are on-deploy commands:
#   submodules        the dependency checkouts, at their remote tips
#   on-depends        submodule pull -> REBUILD the binary -> stow the
#                     depends package (the shim + component builders)
#   _bootstrap-on-deploy            install the binary when missing
#   components        bun + trust + herbctl + polyframes (depends pkg)
#   configure         edit the manifests (+ fold: applies itself;
#                     prompts for the git identity when ~/.my-credentials
#                     is absent)
#   install           the wm.requires requirement walk (installs the
#                     missing binaries from the target's repos)
#   preserve          the conflict resolver: packages -> per-file diff +
#                     decisions (non-tty falls back to archive-first
#                     keep flow), then stow -R per package
#   packages install  each package's own dependency Makefile rules
#   services check    daemon-reload + enable --now every service.order
#                     unit (units needing X stay enabled-but-failed)
#   status            the closing report
bootstrap: submodules _bootstrap-on-deploy
	@$(SELF) on-depends
	@$(ONDEPLOY_BIN) install || { [ $$? -eq 130 ] && exit 130 || true; }
	$(ONDEPLOY_BIN) preserve --only "$(WM_PACKAGES)"
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

# _build-on-deploy — ALWAYS rebuilds ~/.local/bin/on-deploy from the
# submodule checkout (bun through npm when bun itself is missing), then
# installs the binary. `_bootstrap-on-deploy` skips it when the binary
# already exists; `on-depends` calls it UNCONDITIONALLY (a submodule
# pull must land a fresh binary even when a stale one is installed).
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
	# the rename same-device (see components' bun_install note)
	cd "$(ONDEPLOY_SUBMOD)" && mkdir -p node_modules/.tmp && \
		TMPDIR="$$(pwd)/node_modules/.tmp" bun install; \
	cd "$(ONDEPLOY_SUBMOD)" && bun x bunli build --targets linux-x64 --minify; \
	mv -f "$(ONDEPLOY_SUBMOD)/dist/index" "$(ONDEPLOY_SUBMOD)/dist/on-deploy"; \
	rm -f "$(ONDEPLOY_SUBMOD)/dist/index.js.map"; \
	mkdir -p "$(HOME)/.local/bin"; \
	install -m 755 "$(ONDEPLOY_SUBMOD)/dist/on-deploy" "$(ONDEPLOY_BIN)"; \
	echo "on-deploy: built + installed $(ONDEPLOY_BIN)"

# _bootstrap-on-deploy — the delegation target seeded at bootstrap:
# installs the binary ONLY when missing (fresh systems), leaving the
# rebuilds to on-depends.
_bootstrap-on-deploy:
	@if [ -x "$(ONDEPLOY_BIN)" ]; then \
		echo "on-deploy: $(ONDEPLOY_BIN) deployed already — skipping"; \
		exit 0; \
	fi; \
	$(SELF) _build-on-deploy

# on-depends — self-contained maintenance step, safe on FRESH installs
# (no on-deploy binary, nothing stowed): pull the on-deploy submodule to
# its remote tip, REBUILD + install the binary, then stow the depends
# package directly (plain stow — the shim on.deploy + the install/
# deploy scripts + the component builders land in $HOME; the binary
# itself cannot delegate yet, it is only now being built).
on-depends: submodules _build-on-deploy
	@command -v stow >/dev/null 2>&1 || { \
		echo "on-depends: GNU stow missing — install stow (pacman -S stow / apt install stow)" >&2; \
		exit 2; \
	}
	stow -R -t "$(HOME)" depends
	@echo "on-depends: depends package stowed (on-deploy + shim available)"

# ── stowing ───────────────────────────────────────────────────────────
# install — configure FIRST (same folded apply as the bootstrap; the
# recorded configuration still re-applies and prompts for the git
# identity when absent), then resolve conflicts per package (preserve),
# then run each package's dependency Makefile — ONLY the packages
# manifested in wm.packages (no bare `packages install`, which would
# reach every package with a Makefile, including the individually
# deployable VNC/xrdp ones and their sudo steps). The on-deploy binary
# is bootstrapped FIRST so the delegations below can run.
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

# deps — the manifests must exist, then the safe pull + refresh the
# components the way update does
deps: wm
	@if ! ls -al $(WM_PACKAGES_FILE) wm.requires service.order; then \
		exit 1; \
	fi
	@$(SELF) update

# update — the safe pull directly in the repo: fetch + fast-forward
# (fallback --rebase --autostash), submodule sync, then the on-depends
# step (submodule pull → REBUILD + install the binary → stow the
# depends package), and finally the components refresh (--force: build
# the artifacts per the recorded method; bun/polyframes/herbctl live in
# the depends package).
update:
	git fetch
	git merge --ff-only
	git pull --rebase --autostash 2>/dev/null || true
	git submodule sync
	git submodule update --init --recursive
	$(SELF) on-depends
	$(ONDEPLOY_BIN) packages install --only depends

# on-deploy housekeeping verbs stay one call away:
#   $(ONDEPLOY_BIN) preserve <pkg> ...   conflict-safe restow
#   $(ONDEPLOY_BIN) archive <pkg>        record-container backups
#   $(ONDEPLOY_BIN) unarchive <pkg>      restore them
#   $(ONDEPLOY_BIN) configure --show     current configuration
# add them as Makefile targets only when they need a sequence.
