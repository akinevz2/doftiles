# herbctl — PACKAGE ADAPTER (the 2026-11 router-Makefile): one file per
# dots submodule package declaring what is genuinely herbctl-specific
# and owning only its concrete step recipes.
#
# on-deploy consumes the `metadata` contract below (one bare-value
# recipe per item, chained) and runs ALL routing/branching itself:
#   on-deploy managed herbctl install|uninstall|status|<item>|...
# The make verbs stay the interface.
#
# Method format: PACKAGE=source|pkg (doftiles.conf). The submodule:
# herbctl -> dots/herbctl/.local/share/herbctl.

DOTS     := $(abspath $(CURDIR)/..)
SUB_DIR  := $(DOTS)/herbctl/.local/share/herbctl
LINK     := $(CURDIR)/.local/bin
ARTIFACT := $(LINK)/herbctl
SYSBIN   := $(HOME)/.local/bin
ONDEPLOY := $(SYSBIN)/on-deploy

TOOLCHAIN_BINDIR := $(HOME)/.bun/bin
export PATH := $(TOOLCHAIN_BINDIR):$(PATH)

FORCE ?=
DRY   ?=
M     ?=
export FORCE DRY M

.DEFAULT_GOAL := all
.PHONY: toolchain build deps-dir deps-install compile rename-artifact link \
        install-source install uninstall status

# ── the deploy contract (one echo per key; on-deploy consults it) ──────
	@echo key=HERBCTL
	@echo sub_dir=herbctl/.local/share/herbctl
	@echo artifact=herbctl/.local/bin/herbctl
	@echo install_name=herbctl
	@echo lang=bun
	@echo transports=bun,npm
	@echo methods=source
	@echo source_default=source
	@echo src_target=install-source

# ── the default: build + link ("make; make install" cadence) ───────────
all: build link

# ── install/uninstall/status: deferrals (no branching here) ────────────
install:
	@$(ONDEPLOY) managed herbctl install --method=$(M) --force=$(FORCE) --dry-run=$(DRY)

status:
	@$(ONDEPLOY) managed herbctl status

uninstall:
	@rm -f "$(ARTIFACT)"

# ── the source route composed through steps ─────────────────────────────
install-source: build link

build: deps-install compile rename-artifact link

deps-dir:
	@mkdir -p "$(SUB_DIR)/node_modules/.tmp"

deps-install: deps-dir
	@env TMPDIR="$(SUB_DIR)/node_modules/.tmp" bun install --cwd "$(SUB_DIR)"

# compile — freshness guard: skip the ~120MB standalone recompile when
# dist/herbctl is newer than every input (src/, package.json,
# bunli.config.ts). FORCE=1 forces. bun.lock is deliberately excluded
# (bun install touches its mtime on no-change runs).
compile:
	@if [ "$(FORCE)" = "1" ] || [ ! -x "$(SUB_DIR)/dist/herbctl" ] || \
	   find "$(SUB_DIR)/src" "$(SUB_DIR)/package.json" "$(SUB_DIR)/bunli.config.ts" \
	        -newer "$(SUB_DIR)/dist/herbctl" 2>/dev/null | grep -q .; then \
		cd "$(SUB_DIR)" && bun x bunli build --targets linux-x64 --minify; \
	else \
		echo "herbctl: up to date (FORCE=1 to rebuild)"; \
	fi

# rename-artifact — no-op when compile was skipped (dist/index only
# exists right after a real build)
rename-artifact:
	@if [ -f "$(SUB_DIR)/dist/index" ]; then \
		mv -f "$(SUB_DIR)/dist/index" "$(SUB_DIR)/dist/herbctl"; \
	fi

link:
	@mkdir -p "$(LINK)"
	@ln -f "$(SUB_DIR)/dist/herbctl" "$(ARTIFACT)"
	@echo "herbctl: linked $(ARTIFACT)"

# ── toolchain (defer) ───────────────────────────────────────────────────
toolchain:
	@$(ONDEPLOY) toolchain --bun

# ── the package metadata: one config item per recipe (value only!), ────
# ── chained; the ORDER is the contract (see lib/adapters.ts) ───────────
metadata: git_repo pkg_name methods_supported repos_pkg repos_pkg_name

git_repo:
	@echo https://github.com/akinevz2/herbctl

pkg_name:
	@echo herbctl

methods_supported:
	@echo source,pkg

repos_pkg:
	@echo bun,npm

repos_pkg_name:
	@echo herbctl
