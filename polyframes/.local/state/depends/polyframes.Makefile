# polyframes — PACKAGE ADAPTER (the 2026-11 router-Makefile): one file
# per dots submodule package declaring what is genuinely
# polyframes-specific and owning only its concrete step recipes.
#
# on-deploy consumes the `metadata` contract below (one bare-value
# recipe per item, chained) and runs ALL routing/branching itself:
#   on-deploy managed polyframes install|uninstall|status|<item>|...
# The make verbs stay the interface.
#
# Method format: PACKAGE=source|pkg (doftiles.conf). The submodule:
# polyframes -> dots/polyframes/.local/share/polyframes.
# NOTE: the nested bun package's install-hook ensure is a
# package-specific step (bun skips postinstalls on fresh installs).

DOTS     := $(abspath $(CURDIR)/..)
SUB_DIR  := $(DOTS)/polyframes/.local/share/polyframes
LINK     := $(CURDIR)/.local/bin
ARTIFACT := $(LINK)/polyframes
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
	@echo key=POLYFRAMES
	@echo sub_dir=polyframes/.local/share/polyframes
	@echo artifact=polyframes/.local/bin/polyframes
	@echo install_name=polyframes
	@echo lang=bun
	@echo transports=bun,npm
	@echo methods=source
	@echo source_default=source
	@echo src_target=install-source

# ── the default: build + link ("make; make install" cadence) ───────────
all: build link

# ── install/uninstall/status: deferrals (no branching here) ────────────
install:
	@$(ONDEPLOY) managed polyframes install --method=$(M) --force=$(FORCE) --dry-run=$(DRY)

status:
	@$(ONDEPLOY) managed polyframes status

uninstall:
	@rm -f "$(ARTIFACT)"

# ── the source route composed through steps ─────────────────────────────
install-source: build link

build: deps-install bun-hooks compile

deps-dir:
	@mkdir -p "$(SUB_DIR)/node_modules/.tmp"

deps-install: deps-dir
	@env TMPDIR="$(SUB_DIR)/node_modules/.tmp" bun install --cwd "$(SUB_DIR)"

# one logical operation: run the nested bun's install hook (bun skips
# postinstalls on fresh installs; idempotent, this IS a package step)
# MUST run with cwd = the checkout: bun's install.js resolves its
# fallback paths (node_modules/@oven/...) RELATIVE TO CWD — from the
# package root it leaks a node_modules/ there, which stow then folds
# into $HOME (the 2026-11-06 recurrence)
bun-hooks:
	@cd "$(SUB_DIR)" && node node_modules/bun/install.js 2>/dev/null || { echo "polyframes: node missing — the nested bun install hook was skipped" >&2; exit 1; }

compile:
	@$(MAKE) -C "$(SUB_DIR)" --no-print-directory build

link:
	@mkdir -p "$(LINK)"
	@ln -f "$(SUB_DIR)/dist/polyframes" "$(ARTIFACT)"
	@echo "polyframes: linked $(ARTIFACT)"

# ── toolchain (defer) ───────────────────────────────────────────────────
toolchain:
	@$(ONDEPLOY) toolchain --bun

# ── the package metadata: one config item per recipe (value only!), ────
# ── chained; the ORDER is the contract (see lib/adapters.ts) ───────────
metadata: git_repo pkg_name methods_supported repos_pkg repos_pkg_name

git_repo:
	@echo https://github.com/akinevz2/polyframes

pkg_name:
	@echo polyframes

methods_supported:
	@echo source,pkg

repos_pkg:
	@echo bun,npm

repos_pkg_name:
	@echo polyframes
