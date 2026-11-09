# bat — PACKAGE ADAPTER (the 2026-11 router-Makefile): one file per
# dots package declaring what is genuinely bat-specific and owning
# only its concrete step recipes.
#
# on-deploy consumes the `metadata` contract below (one bare-value
# recipe per item, chained) and runs ALL routing/branching itself:
#   on-deploy managed bat install|uninstall|status|<metadata item>|...
# The make verbs stay the interface (the depends walk calls them).
#
# 2026-11 SOURCES PRUNED: the bat-src submodule was dropped from
# .gitmodules (the cargo/release build routes with it). bat deploys
# through the SYSTEM package manager only: the adapter's pkg route
# installs the PACKAGE name (repos_pkg_name), and the BINARY name
# (batcat on Debian/Ubuntu, bat on Arch) is owned by the wm.depends
# binary walk — the <target>.deploy protocol resolves batcat ->
# apt-cache -> package bat. doftiles.conf records BAT=pkg.

DOTS     := $(abspath $(CURDIR)/..)
SYSBIN   := $(HOME)/.local/bin
ONDEPLOY := $(SYSBIN)/on-deploy

FORCE ?=
DRY   ?=
M     ?=
export FORCE DRY M

.DEFAULT_GOAL := install
.PHONY: build install-source install uninstall status

# build rung — the top-level `make stow/build` walk greps `^build:`;
# a pkg-only package has nothing to compile
build:
	@echo "bat: pkg-only package — nothing to build (the transport owns the deploy)"

# ── install: the pkg route straight through on-deploy (the metadata
# contract drives the transport choice: apt | pacman by deploy target) ──
install install-source:
	@$(ONDEPLOY) managed bat install --method=pkg --force=$(FORCE) --dry-run=$(DRY)

# ── uninstall/status: deferrals (no branching here) ────────────────────
uninstall:
	@$(ONDEPLOY) managed bat uninstall

status:
	@$(ONDEPLOY) managed bat status

# ── the package metadata: one config item per recipe (value only!), ────
# ── chained; the ORDER is the contract (see lib/adapters.ts consult) ──
metadata: git_repo pkg_name methods_supported repos_pkg repos_pkg_name

git_repo:
	@echo https://github.com/sharkdp/bat

pkg_name:
	@echo bat

methods_supported:
	@echo pkg

repos_pkg:
	@echo apt

repos_pkg_name:
	@echo bat
