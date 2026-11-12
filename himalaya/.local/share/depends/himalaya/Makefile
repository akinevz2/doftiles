# himalaya — PACKAGE ADAPTER (the 2026-11 router-Makefile): one file
# per dots package declaring what is genuinely himalaya-specific and
# owning only its concrete step recipes.
#
# on-deploy consumes the `metadata` contract below (FIVE bare values,
# positional) and runs ALL routing/branching itself:
#   on-deploy managed himalaya install|uninstall|status
#
# Method: source only. The upstream (pimalaya/himalaya) ships OFFICIAL
# prebuilt release binaries — the source route fetches the pinned
# linux-x86_64 release, verifies its sha256, and lands the binary in
# the package (gitignored; stow ships it):
#   dots/himalaya/.local/bin/himalaya -> ~/.local/bin/himalaya
# No cargo toolchain, no submodule (the only third-party dep is
# curl + tar). Repos_pkg "none" is the contract's harmless placeholder
# — apt carries no himalaya package (verified empty on ubuntu) and the
# bun/npm registries don't either.
#
# Version bumps: update VERSION + SHA256 (the digest is published on
# the release page). FORCE=1 refetches.

CURDIR_ABSPATH := $(patsubst %/,%,$(abspath $(CURDIR)))
LINK     := $(CURDIR_ABSPATH)/.local/bin
ARTIFACT := $(LINK)/himalaya
SYSBIN   := $(HOME)/.local/bin
ONDEPLOY := $(SYSBIN)/on-deploy

VERSION := 2.2.1
URL     := https://github.com/pimalaya/himalaya/releases/download/v$(VERSION)/himalaya.x86_64-linux.tgz
SHA256  := 5c5ba2724c162f82d0a0c71b6c03224ed44f8bef7b14ace5da0635d3af2665a0
DL_DIR  := /tmp/opencode/himalaya

FORCE ?=
DRY   ?=
M     ?=
export FORCE DRY M

.DEFAULT_GOAL := all
.PHONY: all build install-source install uninstall status toolchain \
        metadata git_repo pkg_name methods_supported repos_pkg repos_pkg_name

# ── the default: the source route's whole body ────────────────────────
all: build

# ── install/uninstall/status: deferrals (no branching here) ───────────
install:
	@$(ONDEPLOY) managed himalaya install --method=$(M) --force=$(FORCE) --dry-run=$(DRY)

uninstall:
	@rm -f "$(ARTIFACT)"

status:
	@$(ONDEPLOY) managed himalaya status

# ── build — freshness guard: skip the fetch when the artifact exists; ─
# ── FORCE=1 refetches (a version bump edits VERSION/SHA256) ───────────
build:
	@if [ "$(FORCE)" = "1" ] || [ ! -x "$(ARTIFACT)" ]; then \
		rm -rf "$(DL_DIR)"; \
		mkdir -p "$(DL_DIR)/out" "$(LINK)"; \
		curl -fL --retry 3 -o "$(DL_DIR)/himalaya.tgz" "$(URL)"; \
		echo "$(SHA256)  $(DL_DIR)/himalaya.tgz" | sha256sum -c -; \
		tar -xzf "$(DL_DIR)/himalaya.tgz" -C "$(DL_DIR)/out"; \
		BIN=$$(find "$(DL_DIR)/out" -type f -name himalaya | head -1); \
		test -n "$$BIN" || { echo "himalaya: binary not found in the release archive" >&2; exit 2; }; \
		install -m 0755 "$$BIN" "$(ARTIFACT)"; \
		rm -rf "$(DL_DIR)"; \
		echo "himalaya: deployed $(ARTIFACT)"; \
	else \
		echo "himalaya: up to date (FORCE=1 to refetch)"; \
	fi

install-source: build

# ── toolchain — none needed (prebuilt binary): an honest no-op that ───
# ── still answers the --check convention of the depends-% walker ──────
toolchain:
	@echo "himalaya: no toolchain required (prebuilt release binary)"

# ── the package metadata: one config item per recipe (value only!), ───
# ── chained; the ORDER is the contract (see lib/adapters.ts) ──────────
metadata: git_repo pkg_name methods_supported repos_pkg repos_pkg_name

git_repo:
	@echo https://github.com/pimalaya/himalaya

pkg_name:
	@echo himalaya

methods_supported:
	@echo source

repos_pkg:
	@echo none

repos_pkg_name:
	@echo himalaya
