# herbstutil — PACKAGE ADAPTER (the 2026-11 router-Makefile): one file
# per dots submodule package (this is a REGISTRY package: the artifact
# is the npm/bun global install, no dots binary; it also hosts the bun
# trust steps the dots bootstrap's `make trust` delegates to).
#
# on-deploy consumes the `metadata` contract below (one bare-value
# recipe per item, chained) and runs ALL routing/branching itself:
#   on-deploy managed herbstutil install|uninstall|status|<item>|...
# The make verbs stay the interface.
#
# Method format: PACKAGE=source|pkg (doftiles.conf). The submodule:
# herbstutil -> dots/herbstutil/.local/share/herbstutil.

DOTS    := $(abspath $(CURDIR)/..)
SUB_DIR := $(DOTS)/herbstutil/.local/share/herbstutil
SYSBIN  := $(HOME)/.local/bin
ONDEPLOY := $(SYSBIN)/on-deploy

FORCE ?=
DRY   ?=
M     ?=
export FORCE DRY M

.DEFAULT_GOAL := all
.PHONY: toolchain deps-dir deps-install link install-source \
        install uninstall status trust-setup trust-walk trust-report \
        trust-local trust-global

# ── the deploy contract (one echo per key; on-deploy consults it) ──────
	@echo key=HERBSTUTIL
	@echo sub_dir=herbstutil/.local/share/herbstutil
	@echo artifact=
	@echo stow=0
	@echo install_name=herbstutil
	@echo lang=bun
	@echo transports=bun,npm
	@echo methods=source
	@echo source_default=source
	@echo src_target=install-source

# ── the default: prepare the source (no artifact; make install deploys) ─
all: deps-install
build: deps-install

# ── install/status: deferrals (no branching here) ──────────────────────
install:
	@$(ONDEPLOY) managed herbstutil install --method=$(M) --force=$(FORCE) --dry-run=$(DRY)

status:
	@$(ONDEPLOY) managed herbstutil status

# ── the source route composed through steps ─────────────────────────────
install-source: deps-install link-src

deps-dir:
	@mkdir -p "$(SUB_DIR)/node_modules/.tmp"

deps-install: deps-dir
	@env TMPDIR="$(SUB_DIR)/node_modules/.tmp" bun install --cwd "$(SUB_DIR)"

# one logical operation: global install straight from the checkout
# link-src — freshness guard: the global `bun add -g` re-copies the
# whole checkout + runs its postinstall (~4-6s) — skip when the global
# install's version matches the checkout's package.json. FORCE=1
# forces (dirty checkouts without a version bump included).
link-src:
	@if [ "$(FORCE)" = "1" ]; then need=1; \
	else \
		gpkg="$(HOME)/.bun/install/global/node_modules/herbstutil/package.json"; \
		if [ ! -f "$$gpkg" ]; then need=1; else \
			gver=$$(sed -n 's/.*"version": *"\([^"]*\)".*/\1/p' "$$gpkg" | head -1); \
			lver=$$(sed -n 's/.*"version": *"\([^"]*\)".*/\1/p' "$(SUB_DIR)/package.json" | head -1); \
			if [ -n "$$gver" ] && [ "$$gver" = "$$lver" ]; then need=0; else need=1; fi; \
		fi; \
	fi; \
	if [ "$${need:-0}" = 1 ]; then \
		bun add -g "$(SUB_DIR)"; \
	else \
		echo "herbstutil: global install up to date ($$gver) (FORCE=1 to reinstall)"; \
	fi

link:
	@echo "herbstutil: no link — the artifact is the global install (install-source)"

# ── the PLAIN uninstall step (on-deploy adds the transport removes and
#    the conf record reset) ───────────────────────────────────────────────
uninstall:
	@echo "herbstutil: no artifact — registry removals are on-deploy's"

# ── toolchain (defer) ───────────────────────────────────────────────────
toolchain:
	@$(ONDEPLOY) toolchain --bun

# ── the bun trust steps (the dots bootstrap's `make trust` path) ───────
# trust-local: for EVERY bun submodule checkout of the dots repo, ask
# bun which dependencies have blocked lifecycle scripts and trust them
# (bun's default trust policy blocks postinstalls; AGENTS.md quirk 17)

trust-local: trust-report

trust-report:
	@pcount=0; \
	untrusted=0; \
	for p in $$(git config --file "$(DOTS)/.gitmodules" --get-regexp 'submodule[^ ]*\.path$$' 2>/dev/null | cut -d' ' -f2); do \
		dir="$(DOTS)/$$p"; \
		[ -d "$$dir" ] || continue; \
		[ -f "$$dir/package.json" ] || continue; \
		pcount=$$((pcount + 1)); \
		blocked=$$(cd "$$dir" && bun pm untrusted 2>/dev/null || true); \
		[ -n "$$blocked" ] || continue; \
		untrusted=$$((untrusted + 1)); \
		echo "  trust: $$p"; \
		printf '%s\n' "$$blocked" | while read -r line; do \
			case "$$line" in node_modules/*) pkg="$${line#node_modules/}"; pkg="$${pkg%%/*}" ;; *) continue ;; esac; \
			(cd "$$dir" && bun pm trust "./node_modules/$$pkg" >/dev/null 2>&1) \
				&& echo "    trusted $$pkg" \
				|| echo "    $$pkg stayed blocked"; \
		done; \
	done; \
	echo "herbstutil: trust walked $$pcount checkout(s)"

trust-global:
	@echo "herbstutil: trusting the global untrusted set"
	@untrusted=$$(bun pm untrusted -g 2>/dev/null || true); \
	for pkg in polyframes herbctl herbstutil @opencode/cli bun; do \
		printf '%s' "$$untrusted" | grep -qF "node_modules/$$pkg" || continue; \
		bun pm trust -g "$$pkg" >/dev/null 2>&1 && echo "  trusted -g $$pkg" || echo "  $$pkg stayed blocked"; \
	done

# ── the package metadata: one config item per recipe (value only!), ────
# ── chained; the ORDER is the contract (see lib/adapters.ts) ───────────
metadata: git_repo pkg_name methods_supported repos_pkg repos_pkg_name

git_repo:
	@echo https://github.com/akinevz2/herbstutil

pkg_name:
	@echo herbstutil

methods_supported:
	@echo source,pkg

repos_pkg:
	@echo bun,npm

repos_pkg_name:
	@echo herbstutil
