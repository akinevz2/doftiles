# on-deploy — PACKAGE ADAPTER (the 2026-11 router-Makefile): one file
# per dots submodule package. NOTE the chicken-and-egg: the router
# route runs INSIDE on-deploy, so the toolchain rule requires the
# SYSBIN binary to already exist (no self-delegation); the dots
# `_build-on-deploy` prelude keeps its own bun ensure.
#
# on-deploy consumes the `metadata` contract below (one bare-value
# recipe per item, chained) and runs ALL routing/branching itself:
#   on-deploy managed on-deploy install|uninstall|status|<item>|...
#
# Method format: PACKAGE=source|pkg — but THIS package is source-only
# for now (the registry transports fail until the binary is published;
# the metadata records that honestly). The submodule:
# on-deploy -> dots/on-deploy/.local/share/on-deploy.
# start/stop/enable/disable are common on-deploy no-ops. start/stop/enable/disable are common on-deploy no-ops.

DOTS     := $(abspath $(CURDIR)/..)
SUB_DIR  := $(DOTS)/on-deploy/.local/share/on-deploy
LINK     := $(CURDIR)/.local/bin
ARTIFACT := $(LINK)/on-deploy
SYSBIN   := $(HOME)/.local/bin
ONDEPLOY := $(SYSBIN)/on-deploy

FORCE ?=
DRY   ?=
M     ?=
export FORCE DRY M

.DEFAULT_GOAL := all
.PHONY: toolchain build deps-dir deps-install compile rename-artifact link \
        install-source install uninstall status

# ── the deploy contract (one echo per key; on-deploy consults it) ──────
	@echo key=ON_DEPLOY
	@echo sub_dir=on-deploy/.local/share/on-deploy
	@echo artifact=on-deploy/.local/bin/on-deploy
	@echo install_name=on-deploy
	@echo lang=bun
	@echo transports=bun,npm
	@echo methods=source
	@echo source_default=source
	@echo src_target=install-source

# ── the default: build + link ("make; make install" cadence) ───────────
all: build link

# ── install/uninstall/status: deferrals (no branching here) ────────────
install:
	@$(ONDEPLOY) managed on-deploy install --method=$(M) --force=$(FORCE) --dry-run=$(DRY)

status:
	@$(ONDEPLOY) managed on-deploy status

uninstall:
	@rm -f "$(ARTIFACT)"

# ── the source route composed through steps ─────────────────────────────
install-source: build link

build: deps-install compile rename-artifact

deps-dir:
	@mkdir -p "$(SUB_DIR)/node_modules/.tmp"

deps-install: deps-dir
	@env TMPDIR="$(SUB_DIR)/node_modules/.tmp" bun install --cwd "$(SUB_DIR)"

compile:
	@cd "$(SUB_DIR)" && bun x bunli build --targets linux-x64 --minify

rename-artifact:
	@mv -f "$(SUB_DIR)/dist/index" "$(SUB_DIR)/dist/on-deploy"
	@rm -f "$(SUB_DIR)/dist/index.js.map"

link:
	@mkdir -p "$(LINK)"
	@install -m 755 "$(SUB_DIR)/dist/on-deploy" "$(ARTIFACT)"
	@echo "on-deploy: linked $(ARTIFACT)"

# ── toolchain (defer; no self-delegation: the binary must pre-exist) ────
toolchain:
	@test -x "$(SYSBIN)/on-deploy" || { echo "on-deploy: $(SYSBIN)/on-deploy missing — bun must be assured by the dots bootstrap (no self-delegation)" >&2; exit 2; }
	@$(SYSBIN)/on-deploy toolchain --bun

# ── the package metadata: one config item per recipe (value only!), ────
# ── chained; the ORDER is the contract (see lib/adapters.ts) ───────────
metadata: git_repo pkg_name methods_supported repos_pkg repos_pkg_name

git_repo:
	@echo https://github.com/akinevz2/on-deploy

pkg_name:
	@echo on-deploy

methods_supported:
	@echo source,pkg

repos_pkg:
	@echo bun,npm

repos_pkg_name:
	@echo on-deploy
