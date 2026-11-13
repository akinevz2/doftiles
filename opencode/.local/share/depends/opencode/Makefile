# opencode — PACKAGE ADAPTER (the 2026-11 router-Makefile): one file
# per dots package; this is a REGISTRY METApackage — no submodule
# checkout, no dots-owned artifact: the deployment IS the bun global
# install of @opencode/cli (opencode-ai's release channel — bun is the
# only install variant, per the adapter's transport set).
#
# on-deploy consumes the `metadata` contract below (one bare-value
# recipe per item, chained) and runs ALL routing/branching itself:
#   on-deploy managed opencode install|uninstall|status|<item>|...
# The make verbs stay the interface.
#
# Method format: opencode=# pkg (doftiles.conf). No submodule: no
# source route — pkg (bun) is the only valid method.

SYSBIN  := $(HOME)/.local/bin
ONDEPLOY := $(SYSBIN)/on-deploy

FORCE ?=
DRY   ?=
M     ?=
export FORCE DRY M

.DEFAULT_GOAL := install
.PHONY: build install-source install uninstall status trust

# build rung — the top-level `make stow/build` walk greps `^build:`;
# a registry metapackage has nothing to compile
build:
	@echo "opencode: registry package — nothing to build (the artifact is the global install; install owns the deploy)"

# ── install: the pkg route straight through on-deploy (bun is the only
# variant; the metadata contract drives the transport choice) ───────────
install install-source:
	@$(ONDEPLOY) managed opencode install --method=pkg --force=$(FORCE) --dry-run=$(DRY)

# post-install trust (bun's policy may block @opencode/cli's
# postinstall; the herbstutil trust-global walk covers it too, this is
# the package-owned belt-and-braces)
trust:
	@bun pm trust -g "@opencode/cli" >/dev/null 2>&1 \
		&& echo "opencode: trusted -g @opencode/cli" \
		|| echo "opencode: -g trust nothing to grant"

# ── uninstall/status: deferrals (no branching here) ────────────────────
uninstall:
	@echo "opencode: registry removal is on-deploy's (managed opencode uninstall)"

status:
	@$(ONDEPLOY) managed opencode status

# ── the package metadata: one config item per recipe (value only!), ────
# ── chained; the ORDER is the contract (see adapters.ts consult) ───────
metadata: git_repo pkg_name methods_supported repos_pkg repos_pkg_name

git_repo:
	@echo https://github.com/sst/opencode

pkg_name:
	@echo opencode

methods_supported:
	@echo pkg

repos_pkg:
	@echo bun

repos_pkg_name:
	@echo @opencode/cli
