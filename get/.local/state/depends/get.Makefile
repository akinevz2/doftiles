# get — PACKAGE ADAPTER (the 2026-11 router-Makefile shape): one file
# per dots submodule package declaring what is genuinely get-specific
# and owning only its concrete step recipes.
#
# on-deploy consumes the `metadata` contract below (FIVE bare values,
# positional; run `make -f get.Makefile metadata`) and routes:
#   on-deploy managed get install|uninstall|status
# Method format: methods=source only — plain shell files, no toolchain,
# no pkg transport ("none" is a harmless placeholder for the contract's
# 4th positional; the transports lookup simply misses it).
#
# The submodule: got-source -> dots/get/.local/share/got-source.
# Artifacts (gitignored, stow ships them):
#   dots/get/.local/bin/got          -> ~/.local/bin/got
#   dots/get/.local/share/got/get.sh -> ~/.local/share/got/get.sh
#   (the latter is sourced by shell/.shellx.rc)

# Paths derive from THIS Makefile's location (dots/get/.local/state/
# depends/), so the adapter behaves under `make -C dots/get -f ...`
# (the on-deploy consult) and bare `make -f ...` from the dots root.
MAKEFILE_DIR := $(patsubst %/,%,$(dir $(abspath $(lastword $(MAKEFILE_LIST)))))
DOTS_GET := $(abspath $(MAKEFILE_DIR)/../../..)
DOTS     := $(abspath $(MAKEFILE_DIR)/../../../..)
SUB_DIR  := $(DOTS_GET)/.local/share/got-source
LINK     := $(DOTS_GET)/.local/bin
SHARE    := $(DOTS_GET)/.local/share/got
ARTIFACT := $(LINK)/got
GET_SH   := $(SHARE)/get.sh
ONDEPLOY := $(HOME)/.local/bin/on-deploy

FORCE ?=
DRY   ?=
M     ?=
export FORCE DRY M

.DEFAULT_GOAL := all
.PHONY: toolchain build sync checkout link install-source install \
        uninstall status

# ── the default: build + link ("make; make install" cadence) ──────────
all: build link

# ── install/uninstall/status: deferrals (no branching here) ───────────
install:
	@$(ONDEPLOY) managed get install --method=$(M) --force=$(FORCE) --dry-run=$(DRY)

status:
	@$(ONDEPLOY) managed get status

uninstall:
	@rm -f "$(ARTIFACT)" "$(GET_SH)"

# ── the source route composed through steps (no toolchain: plain ──────
# ── POSIX shell files; toolchain is a loud no-op for the walkers) ─────
install-source: build link

build: sync checkout

sync:
	@git -C "$(DOTS)" submodule sync "get/.local/share/got-source"

checkout:
	@git -C "$(DOTS)" submodule update --init --recursive "get/.local/share/got-source"

# no pull: the checkout is FROZEN at the recorded pin — the submodule
# update reasserts it; a bump is a manual git operation (the
# upstream-owned nested-assets doctrine)
link:
	@test -f "$(SUB_DIR)/got" || { echo "get: checkout missing $(SUB_DIR)/got" >&2; exit 2; }
	@mkdir -p "$(LINK)" "$(SHARE)"
	@ln -f "$(SUB_DIR)/got" "$(ARTIFACT)"
	@cp -f "$(SUB_DIR)/get.sh" "$(GET_SH)"
	@chmod 0755 "$(ARTIFACT)" && chmod 0644 "$(GET_SH)"
	@echo "get: linked $(ARTIFACT) + $(GET_SH)"

# ── toolchain — none needed (plain shell files): an honest no-op that ─
# ── still answers the --check convention of the depends-% walker ──────
toolchain:
	@echo "get: no toolchain required (plain shell files)"

# ── the package metadata: one config item per recipe (value only!), ────
# ── chained; the ORDER is the contract (see lib/adapters.ts) ───────────
metadata: git_repo pkg_name methods_supported repos_pkg repos_pkg_name

git_repo:
	@echo https://github.com/akinevz2/got-source

pkg_name:
	@echo got-source

methods_supported:
	@echo source

repos_pkg:
	@echo none

repos_pkg_name:
	@echo got
