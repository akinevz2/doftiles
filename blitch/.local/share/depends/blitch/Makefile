# blitch — PACKAGE ADAPTER (the 2026-11 router-Makefile): one file per
# dots submodule package declaring what is genuinely blitch-specific
# and owning only its concrete step recipes.
#
# on-deploy consumes the `metadata` contract below (one bare-value
# recipe per item, chained) and runs ALL routing/branching itself:
#   on-deploy managed blitch install|uninstall|status|<item>|...
# The make verbs stay the interface.
#
# Method format: PACKAGE=source|pkg (doftiles.conf). The submodule:
# blitch -> dots/blitch/.local/share/blitch.
# blitch is a plain `bun build --compile` project (@bunli/core as a
# library only — no bunli.config.ts, no bunli build step): the package
# script `build` compiles the standalone ./blitch binary at the
# checkout root (gitignored). Source-only: nothing published to any
# registry, so `pkg` is not a supported method.

# The router passes DOTS + PKG_ROOT on the make command line (from
# the doftiles.conf DOTS record — the installed dots location); the
# ?= fallbacks cover bare human invocation. No relative walk-ups.
DOTS     ?= $(HOME)/dots
PKG_ROOT ?= $(DOTS)/blitch
SUB_DIR  := $(abspath $(PKG_ROOT)/.local/share/blitch)
LINK     := $(abspath $(PKG_ROOT)/.local/bin)
ARTIFACT := $(LINK)/blitch
SYSBIN   := $(HOME)/.local/bin
ONDEPLOY := $(SYSBIN)/on-deploy

TOOLCHAIN_BINDIR := $(HOME)/.bun/bin
export PATH := $(TOOLCHAIN_BINDIR):$(PATH)

FORCE ?=
DRY   ?=
M     ?=
export FORCE DRY M

.DEFAULT_GOAL := all
.PHONY: toolchain build deps-dir deps-install compile link \
        install-source install uninstall status

# ── the default: build + link ("make; make install" cadence) ───────────
all: build link

# ── install/uninstall/status: deferrals (no branching here) ────────────
install:
	@$(ONDEPLOY) managed blitch install --method=$(M) --force=$(FORCE) --dry-run=$(DRY)

status:
	@$(ONDEPLOY) managed blitch status

uninstall:
	@rm -f "$(ARTIFACT)"

# ── the source route composed through steps ─────────────────────────────
install-source: build link

build: deps-install compile link

deps-dir:
	@mkdir -p "$(SUB_DIR)/node_modules/.tmp"

# no cross-submodule dependencies (@bunli/core comes from the npm
# registry) — a plain install, no tip re-resolve step
deps-install: deps-dir
	@env TMPDIR="$(SUB_DIR)/node_modules/.tmp" bun install --cwd "$(SUB_DIR)"

# compile — freshness guard: skip the standalone recompile when the
# checkout-root ./blitch binary is newer than every input (src/,
# package.json, tsconfig.json). FORCE=1 forces. bun.lock is
# deliberately excluded (bun install touches its mtime on no-change
# runs).
compile:
	@if [ "$(FORCE)" = "1" ] || [ ! -x "$(SUB_DIR)/blitch" ] || \
	   find "$(SUB_DIR)/src" "$(SUB_DIR)/package.json" "$(SUB_DIR)/tsconfig.json" \
	        -newer "$(SUB_DIR)/blitch" 2>/dev/null | grep -q .; then \
		cd "$(SUB_DIR)" && bun run build; \
	else \
		echo "blitch: up to date (FORCE=1 to rebuild)"; \
	fi

link:
	@$(ONDEPLOY) managed blitch link

# ── toolchain (defer) ───────────────────────────────────────────────────
toolchain:
	@$(ONDEPLOY) toolchain --bun

# ── the package metadata: one config item per recipe (value only!), ────
# ── chained; the ORDER is the contract (see lib/adapters.ts) ───────────
metadata: git_repo pkg_name methods_supported repos_pkg repos_pkg_name build_output

git_repo:
	@echo https://github.com/akinevz2/blitch

pkg_name:
	@echo blitch

methods_supported:
	@echo source

repos_pkg:
	@echo none

repos_pkg_name:
	@echo blitch

build_output:
	@echo blitch
