# oama — PACKAGE ADAPTER (the 2026-11 router-Makefile): one file per
# dots package declaring what is genuinely oama-specific and owning
# only its concrete step recipes.
#
# on-deploy consumes the `metadata` contract below (FIVE bare values,
# positional) and runs ALL routing/branching itself:
#   on-deploy managed oama install|uninstall|status
#
# Method: source only. The upstream (pdobsan/oama) ships OFFICIAL
# precompiled STATIC release binaries — the source route fetches the
# pinned linux-x86_64 release, verifies its sha256, and lands the
# binary in the package (gitignored; stow ships it):
#   dots/oama/.local/bin/oama -> ~/.local/bin/oama
# No toolchain, no submodule. repos_pkg "none" is the contract's
# harmless placeholder (oama is in no registry or apt repo).
#
# oama is the OAuth credential manager the himalaya package's
# gmail/msgraph token commands call: `oama access <email>` prints a
# fresh access token (oama renews it automatically in the background).
#
# Version bumps: update VERSION + SHA256 (the digest is published on
# the release page). FORCE=1 refetches.

CURDIR_ABSPATH := $(patsubst %/,%,$(abspath $(CURDIR)))
LINK     := $(CURDIR_ABSPATH)/.local/bin
ARTIFACT := $(LINK)/oama
SYSBIN   := $(HOME)/.local/bin
ONDEPLOY := $(SYSBIN)/on-deploy

VERSION := 0.22.0
URL     := https://github.com/pdobsan/oama/releases/download/$(VERSION)/oama-$(VERSION)-Linux-x86_64.tar.gz
SHA256  := 63596bb58471448aa3c63a35e17aa4e4c086c35730d98bcca230fec18779a620
DL_DIR  := /tmp/opencode/oama

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
	@$(ONDEPLOY) managed oama install --method=$(M) --force=$(FORCE) --dry-run=$(DRY)

uninstall:
	@rm -f "$(ARTIFACT)"

status:
	@$(ONDEPLOY) managed oama status

# ── build — freshness guard: skip the fetch when the artifact exists; ─
# ── FORCE=1 refetches (a version bump edits VERSION/SHA256) ───────────
build:
	@if [ "$(FORCE)" = "1" ] || [ ! -x "$(ARTIFACT)" ]; then \
		rm -rf "$(DL_DIR)"; \
		mkdir -p "$(DL_DIR)/out" "$(LINK)"; \
		curl -fL --retry 3 -o "$(DL_DIR)/oama.tar.gz" "$(URL)"; \
		echo "$(SHA256)  $(DL_DIR)/oama.tar.gz" | sha256sum -c -; \
		tar -xzf "$(DL_DIR)/oama.tar.gz" -C "$(DL_DIR)/out"; \
		BIN=$$(find "$(DL_DIR)/out" -type f -name oama | head -1); \
		test -n "$$BIN" || { echo "oama: binary not found in the release archive" >&2; exit 2; }; \
		install -m 0755 "$$BIN" "$(ARTIFACT)"; \
		rm -rf "$(DL_DIR)"; \
		echo "oama: deployed $(ARTIFACT)"; \
	else \
		echo "oama: up to date (FORCE=1 to refetch)"; \
	fi

install-source: build

# ── toolchain — none needed (prebuilt static binary) ──────────────────
toolchain:
	@echo "oama: no toolchain required (prebuilt release binary)"

# ── the package metadata: one config item per recipe (value only!), ───
# ── chained; the ORDER is the contract (see lib/adapters.ts) ──────────
metadata: git_repo pkg_name methods_supported repos_pkg repos_pkg_name

git_repo:
	@echo https://github.com/pdobsan/oama

pkg_name:
	@echo oama

methods_supported:
	@echo source

repos_pkg:
	@echo none

repos_pkg_name:
	@echo oama
