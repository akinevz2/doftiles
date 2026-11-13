# polytags — PACKAGE ADAPTER (the 2026-11 router-Makefile): one file
# per dots submodule package declaring what is genuinely
# polytags-specific and owning only its concrete step recipes.
#
# on-deploy consumes the `metadata` contract below (one bare-value
# recipe per item, chained) and runs ALL routing/branching itself:
#   on-deploy managed polytags install|uninstall|status|<item>|...
# The make verbs stay the interface.
#
# Method format: PACKAGE=source|pkg (doftiles.conf). The submodule:
# polytags -> dots/polytags/.local/share/polytags.
# NOTE: the nested bun package's install-hook ensure is a
# package-specific step (bun skips postinstalls on fresh installs).

DOTS     ?= $(HOME)/dots
PKG_ROOT ?= $(DOTS)/polytags
SUB_DIR  := $(abspath $(PKG_ROOT)/.local/share/polytags)
LINK     := $(abspath $(PKG_ROOT)/.local/bin)
ARTIFACT := $(LINK)/polytags
SYSBIN   := $(HOME)/.local/bin
ONDEPLOY := $(SYSBIN)/on-deploy

TOOLCHAIN_BINDIR := $(HOME)/.bun/bin
export PATH := $(TOOLCHAIN_BINDIR):$(PATH)

FORCE ?=
DRY   ?=
M     ?=
export FORCE DRY M

.DEFAULT_GOAL := all
.PHONY: toolchain build deps-dir deps-install bun-hooks compile link \
        install-source install uninstall status

# ── the deploy contract (one echo per key; on-deploy consults it) ──────
	@echo key=POLYTAGS
	@echo sub_dir=polytags/.local/share/polytags
	@echo artifact=polytags/.local/bin/polytags
	@echo install_name=polytags
	@echo lang=bun
	@echo transports=bun,npm
	@echo methods=source
	@echo source_default=source
	@echo src_target=install-source

# ── the default: build + link ("make; make install" cadence) ───────────
all: build link

# ── install/uninstall/status: deferrals (no branching here) ────────────
install:
	@$(ONDEPLOY) managed polytags install --method=$(M) --force=$(FORCE) --dry-run=$(DRY)

status:
	@$(ONDEPLOY) managed polytags status

uninstall:
	@rm -f "$(ARTIFACT)"

# ── the source route composed through steps ─────────────────────────────
install-source: build link

build: deps-install bun-hooks compile link

deps-dir:
	@mkdir -p "$(SUB_DIR)/node_modules/.tmp"

deps-install: deps-dir
	@env TMPDIR="$(SUB_DIR)/node_modules/.tmp" bun install --cwd "$(SUB_DIR)"

# bun-hooks — freshness guard: the nested bun postinstall's ENTIRE job
# is linking the platform binary into node_modules/bun/bin/ (bun skips
# postinstalls on fresh installs; this IS the insurance step). When
# bun.exe is already present the hook has nothing to do — skip the
# ~6s node/install.js run. FORCE=1 forces.
#
# MUST run with cwd = the checkout: bun's install.js resolves its
# fallback paths (node_modules/@oven/...) RELATIVE TO CWD — from the
# package root it leaks a node_modules/ there, which stow then folds
# into $HOME (the 2026-11-06 recurrence)
bun-hooks:
	@if [ "$(FORCE)" = "1" ] || [ ! -x "$(SUB_DIR)/node_modules/bun/bin/bun.exe" ]; then \
		cd "$(SUB_DIR)" && node node_modules/bun/install.js 2>/dev/null || \
			{ echo "polytags: node missing — the nested bun install hook was skipped" >&2; exit 1; }; \
	else \
		echo "polytags: bun install hook up to date (FORCE=1 to re-run)"; \
	fi

# compile — freshness guard: skip the ~120MB standalone recompile when
# dist/polytags is newer than every input (src/, package.json,
# bunli.config.ts). FORCE=1 forces. bun.lock is deliberately excluded
# (bun install touches its mtime on no-change runs).
compile:
	@if [ "$(FORCE)" = "1" ] || [ ! -x "$(SUB_DIR)/dist/polytags" ] || \
	   find "$(SUB_DIR)/src" "$(SUB_DIR)/package.json" "$(SUB_DIR)/bunli.config.ts" \
	        -newer "$(SUB_DIR)/dist/polytags" 2>/dev/null | grep -q .; then \
		$(MAKE) -C "$(SUB_DIR)" --no-print-directory build; \
	else \
		echo "polytags: up to date (FORCE=1 to rebuild)"; \
	fi

link:
	@$(ONDEPLOY) managed polytags link

# ── toolchain (defer) ───────────────────────────────────────────────────
toolchain:
	@$(ONDEPLOY) toolchain --bun

# ── the package metadata: one config item per recipe (value only!), ────
# ── chained; the ORDER is the contract (see lib/adapters.ts) ───────────
metadata: git_repo pkg_name methods_supported repos_pkg repos_pkg_name build_output

git_repo:
	@echo https://github.com/akinevz2/polytags

pkg_name:
	@echo polytags

methods_supported:
	@echo source,pkg

repos_pkg:
	@echo bun,npm

repos_pkg_name:
	@echo polytags

build_output:
	@echo dist/polytags
