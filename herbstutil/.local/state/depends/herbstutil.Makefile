# herbstutil — per-package depends Makefile (the 2026-11 scheme). The
# submodule checkout is a REGISTRY package: it is deployed through the
# npm/bun GLOBAL install (not a bundled binary). Also hosts the bun
# trust steps (the dots bootstrap's `make trust` delegates here).
#
#   make install            ensure — global install when missing
#   make install FORCE=1    reinstall even when present
#   make install DRY=1      print what would run, change nothing
#   make trust-local        bun trust for every checked-out bun
#                           submodule of the dots repo
#   make trust-global       bun pm trust -g (the global untrusted set)

DOTS    := $(abspath $(CURDIR)/..)
SUB_DIR := $(DOTS)/herbstutil/.local/share/herbstutil
SYSBIN  := $(HOME)/.local/bin

FORCE ?=
DRY   ?=
export FORCE DRY

.PHONY: toolchain build link install uninstall status trust-local trust-global start stop enable disable
.DEFAULT_GOAL := status

toolchain:
	@case "$(DRY)" in 1) echo "  [dry-run] on-deploy toolchain --bun"; exit 0;; esac; \
	[ -x "$(SYSBIN)/on-deploy" ] || { echo "herbstutil: $(SYSBIN)/on-deploy missing — run 'make bootstrap' first" >&2; exit 2; }; \
	$(SYSBIN)/on-deploy toolchain --bun

# build/link — a registry package has no bundled artifact
build link:
	@echo "herbstutil: no build — the artifact is the npm/bun global install (make install)"

install: toolchain
	@set -e; \
	if command -v herbstutil >/dev/null 2>&1 && [ -z "$(FORCE)" ]; then \
		printf '  %-11s %s\n' herbstutil "global install present already"; \
		exit 0; \
	fi; \
	case "$(DRY)" in 1) echo "  [dry-run] bun add -g herbstutil (npm fallback)"; exit 0;; esac; \
	if command -v bun >/dev/null 2>&1; then bun add -g herbstutil; else npm install --global herbstutil; fi

trust-local:
	@set -e; \
	if [ "$(DRY)" = 1 ]; then echo "  [dry-run] bun pm trust per bun submodule"; exit 0; fi; \
	if ! command -v bun >/dev/null 2>&1; then \
		echo "herbstutil: bun absent — nothing to trust locally"; exit 0; \
	fi; \
	pcount=0; \
	for p in $$(git config --file "$(DOTS)/.gitmodules" --get-regexp 'submodule[^ ]*\.path$$' 2>/dev/null | cut -d' ' -f2); do \
		dir="$(DOTS)/$$p"; \
		if [ ! -d "$$dir" ] || [ ! -f "$$dir/package.json" ]; then continue; fi; \
		pcount=$$((pcount + 1)); \
		untrusted="$$(cd "$$dir" && bun pm untrusted 2>/dev/null || true)"; \
		if [ -z "$$untrusted" ]; then continue; fi; \
		echo "  trust: $$p"; \
		for line in $$untrusted; do \
			case "$$line" in node_modules/*) pkg="$${line#node_modules/}"; pkg="$${pkg%%/*}" ;; *) continue ;; esac; \
			if (cd "$$dir" && bun pm trust "./node_modules/$$pkg" >/dev/null 2>&1); then \
				echo "    trusted $$pkg"; \
			else \
				echo "    $$pkg stays blocked (lifecycle scripts)"; \
			fi; \
		done; \
	done; \
	if [ "$$pcount" -gt 0 ]; then \
		echo "herbstutil: trust-local done on $$pcount bun submodule(s)"; \
	else \
		echo "herbstutil: no checked-out bun submodules to trust"; \
	fi

trust-global:
	@set -e; \
	if [ "$(DRY)" = 1 ]; then echo "  [dry-run] bun pm trust -g for the global untrusted set"; exit 0; fi; \
	if ! command -v bun >/dev/null 2>&1; then \
		echo "herbstutil: bun absent — nothing to trust globally"; exit 0; \
	fi; \
	untrusted="$$(bun pm untrusted -g 2>/dev/null || true)"; \
	for pkg in polyframes herbctl herbstutil @opencode/cli bun; do \
		if printf '%s' "$$untrusted" | grep -qF "node_modules/$$pkg"; then \
			if bun pm trust -g "$$pkg" >/dev/null 2>&1; then \
				echo "  trusted -g $$pkg"; \
			else \
				echo "  $$pkg stayed blocked"; \
			fi; \
		else \
			echo "  $$pkg — trusted already or no blocked scripts"; \
		fi; \
	done

uninstall:
	@set -e; \
	case "$(DRY)" in 1) echo "  [dry-run] remove the global herbstutil install (checkout stays)"; exit 0;; esac; \
	if command -v herbstutil >/dev/null 2>&1; then \
		if command -v bun >/dev/null 2>&1; then bun remove -g herbstutil; else npm uninstall --global herbstutil; fi; \
	fi; \
	echo "herbstutil: uninstalled (checkout left in place)"

status:
	@st=MISSING; command -v herbstutil >/dev/null 2>&1 && st=installed; \
	printf '  %-12s %s\n' herbstutil "$$st"

start stop enable disable:
	@echo "herbstutil: nothing to $@ — the deployed artifact is a global library"
