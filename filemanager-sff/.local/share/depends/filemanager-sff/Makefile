# filemanager-sff — PACKAGE ADAPTER (pkg-only, the 2026-11 walk shape):
# the grouping of the sff terminal file manager and its pfs-utils
# helper (the Phosh File Chooser pfs-open frontend).
#
# Install rides the wm.depends BINARY walk (`make add-packages` /
# `make install`'s requirement walk): the manifest carries the binary
# names `sff` and `pfs-open`; the <target>.deploy protocol resolves
# pfs-open -> apt package pfs-utils via the ubuntu.deploy alias table.
# The adapter owns NO install logic — only verification (install) and
# dpkg reporting (status). No managed/pkg route: the metadata contract
# is deliberately absent, the group spans MULTIPLE system packages and
# the managed verb installs a single name (see the grouping comment in
# desktop-environment for its one adapter-owned exception).

.PHONY: build install uninstall status

# the dots-relative deploy script (the <target>.deploy protocol)
DEPLOY := $(HOME)/dots/depends/.local/bin/install/ubuntu.deploy

# the apt packages this grouping covers (status/dpkg reporting)
PKGS := sff pfs-utils

.DEFAULT_GOAL := status

# build rung — a pkg-only package has nothing to compile
build:
	@echo "filemanager-sff: pkg-only package — the wm.depends walk owns the deploy"

# ── install: verify the walk DID its job (the requirement walk runs ──
# ── BEFORE the packages walk in `make install`; a missing binary    ──
# ── here means the walk was skipped or failed — say so loudly)      ──
install:
	@ok=1; \
	for bin in sff pfs-open; do \
		if ! command -v "$$bin" >/dev/null 2>&1; then \
			echo "filemanager-sff: binary '$$bin' missing — run 'make add-packages' (YES=1 headless)" >&2; \
			ok=0; \
		fi; \
	done; \
	[ "$$ok" = 1 ] && echo "filemanager-sff: requirement walk ok (sff, pfs-open on PATH)" || exit 1

uninstall:
	@echo "filemanager-sff: no uninstall (system packages stay; remove by hand if ever needed)"

status:
	@for pkg in $(PKGS); do \
		if dpkg -s "$$pkg" >/dev/null 2>&1; then \
			echo "  $$pkg  installed"; \
		else \
			echo "  $$pkg  MISSING"; \
		fi; \
	done
