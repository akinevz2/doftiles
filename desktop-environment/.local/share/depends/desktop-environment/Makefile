# desktop-environment — PACKAGE ADAPTER (pkg-only, the 2026-11 walk
# shape): the .deb installer tooling (gdebi + gdebi-core) and the
# pfs-common support files.
#
# Install rides the wm.depends BINARY walk (`make add-packages` /
# `make install`'s requirement walk): the manifest carries the binary
# name `gdebi`, which the <target>.deploy protocol resolves to the apt
# package `gdebi` — and the gdebi GUI package DEPENDS on gdebi-core
# (= same version), so one binary carries both.
#
# THE EXCEPTION — pfs-common: it ships NO binary, so the binary walk
# can never verify or install it. The adapter's install rule owns it
# through the SAME <target>.deploy protocol (ubuntu.deploy resolves
# and prints the install command — no apt logic of its own here).
# No managed/pkg route: the metadata contract is deliberately absent,
# the managed verb installs a single name and this group spans two
# independent system packages.

.PHONY: build install uninstall status

# the dots-relative deploy script (the <target>.deploy protocol)
DEPLOY := $(HOME)/dots/depends/.local/bin/install/ubuntu.deploy

FORCE ?=
DRY   ?=
export FORCE DRY

# the apt packages this grouping covers (status/dpkg reporting); the
# walk carries gdebi (-> gdebi + gdebi-core), the adapter carries
# pfs-common
PKGS := gdebi gdebi-core pfs-common

.DEFAULT_GOAL := status

# build rung — a pkg-only package has nothing to compile
build:
	@echo "desktop-environment: pkg-only package — the wm.depends walk owns the deploy"

# ── install: gdebi via the walk (verify only), pfs-common HERE ────────
install:
	@if ! command -v gdebi >/dev/null 2>&1; then \
		echo "desktop-environment: binary 'gdebi' missing — run 'make add-packages' (YES=1 headless)" >&2; \
		exit 1; \
	fi
	@if dpkg -s pfs-common >/dev/null 2>&1; then \
		echo "desktop-environment: pfs-common installed"; \
	else \
		cmd=$$($(DEPLOY) install pfs-common) || exit 1; \
		echo "         running: $$cmd"; \
		[ "$(DRY)" = 1 ] && exit 0; \
		sh -c "$$cmd" || exit 1; \
	fi

uninstall:
	@echo "desktop-environment: no uninstall (system packages stay; remove by hand if ever needed)"

status:
	@for pkg in $(PKGS); do \
		if dpkg -s "$$pkg" >/dev/null 2>&1; then \
			echo "  $$pkg  installed"; \
		else \
			echo "  $$pkg  MISSING"; \
		fi; \
	done
