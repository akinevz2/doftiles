# mutt — PACKAGE ADAPTER (the 2026-11 router-Makefile, the bat shape):
# one file per dots package declaring what is genuinely mutt-specific
# and owning only its concrete step recipes.
#
# on-deploy consumes the `metadata` contract below (one bare-value
# recipe per item, chained) and runs ALL routing/branching itself:
#   on-deploy managed mutt install|uninstall|status|<metadata item>|...
#
# mutt deploys through the SYSTEM package manager only (apt package
# `mutt` — the binary name matches on both apt and pacman families).
# The wm.depends binary walk verifies `mutt` through the
# <target>.deploy protocol.

SYSBIN   := $(HOME)/.local/bin
ONDEPLOY := $(SYSBIN)/on-deploy

FORCE ?=
DRY   ?=
M     ?=
export FORCE DRY M

.DEFAULT_GOAL := install
.PHONY: build install install-source uninstall status

# build rung — the top-level `make stow/build` walk greps `^build:`;
# a pkg-only package has nothing to compile
build:
	@echo "mutt: pkg-only package — nothing to build (the transport owns the deploy)"

# ── install: the pkg route straight through on-deploy (the metadata
# contract drives the transport choice: apt | pacman by deploy target) ──
install install-source:
	@$(ONDEPLOY) managed mutt install --method=pkg --force=$(FORCE) --dry-run=$(DRY)

# ── uninstall/status: deferrals (no branching here) ────────────────────
uninstall:
	@$(ONDEPLOY) managed mutt uninstall

status:
	@$(ONDEPLOY) managed mutt status

# ── the package metadata: one config item per recipe (value only!), ────
# ── chained; the ORDER is the contract (see lib/adapters.ts consult) ──
metadata: git_repo pkg_name methods_supported repos_pkg repos_pkg_name

git_repo:
	@echo https://gitlab.com/muttmua/mutt

pkg_name:
	@echo mutt

methods_supported:
	@echo pkg

repos_pkg:
	@echo apt

repos_pkg_name:
	@echo mutt
