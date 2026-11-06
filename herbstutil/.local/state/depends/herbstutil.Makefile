# herbstutil — per-package depends Makefile (the 2026-11 scheme). The
# submodule checkout is a REGISTRY package: the artifact is the
# npm/bun GLOBAL install. Method knob:
#   source (default) — global install straight from the checkout
#   npm              — the published registry build (bun add -g herbstutil)
# Also hosts the bun trust steps (the dots bootstrap's `make trust`
# delegates here).
#
#   make install                 ensure — method conf > source
#   make install FORCE=1         reinstall even when present
#   make install M=source|npm    explicit method (also recorded)
#   make install DRY=1           print what would run, change nothing
#   make trust-local             bun trust for every checked-out bun
#                                submodule of the dots repo
#   make trust-global            bun pm trust -g (global untrusted set)

DOTS    := $(abspath $(CURDIR)/..)
SUB_DIR := $(DOTS)/herbstutil/.local/share/herbstutil
SYSBIN  := $(HOME)/.local/bin
CONF    := $(HOME)/.config/doftiles.conf

FORCE ?=
DRY   ?=
M     ?=
export FORCE DRY M

.PHONY: toolchain build link install uninstall status trust-local trust-global start stop enable disable
.DEFAULT_GOAL := status

toolchain:
	@case "$(DRY)" in 1) echo "  [dry-run] on-deploy toolchain --bun"; exit 0;; esac; \
	[ -x "$(SYSBIN)/on-deploy" ] || { echo "herbstutil: $(SYSBIN)/on-deploy missing — run 'make bootstrap' first" >&2; exit 2; }; \
	$(SYSBIN)/on-deploy toolchain --bun

# ── conf (the <HERBSTUTIL>=<method> record, through the stow symlink) ──
conf-get:
	@[ -f "$(CONF)" ] || { printf ''; exit 0; }; \
	. "$(CONF)" 2>/dev/null || true; \
	printf '%s' "$${HERBSTUTIL:-}"

conf-set:
	@mkdir -p "$$(dirname "$(CONF)")"; \
	touch "$(CONF)"; \
	if grep -q '^HERBSTUTIL=' "$(CONF)"; then \
		sed -i --follow-symlinks "s/^HERBSTUTIL=.*/HERBSTUTIL=$(value M)/" "$(CONF)"; \
	else \
		printf 'HERBSTUTIL=%s\n' "$(value M)" >> "$(CONF)"; \
	fi

# build/link — a registry package has no bundled artifact
build link:
	@echo "herbstutil: no build — the artifact is the npm/bun global install (make install)"

# ── npm: the published registry build ─────────────────────────────────
install-npm:
	@set -e; \
	case "$(DRY)" in 1) echo "  [dry-run] bun add -g herbstutil (npm fallback)"; exit 0;; esac; \
	if command -v bun >/dev/null 2>&1; then bun add -g herbstutil; else npm install --global herbstutil; fi; \
	$(MAKE) -C "$(CURDIR)" --no-print-directory -f .local/state/depends/herbstutil.Makefile conf-set M=npm; \
	printf '  %-11s %s\n' herbstutil "installed from the npm registry (make install FORCE=1 redeploys)"

# ── source: global install straight from the checkout ─────────────────
install-source:
	@set -e; \
	[ -f "$(SUB_DIR)/package.json" ] || { echo "herbstutil: submodule checkout missing — run 'make submodules' first" >&2; exit 2; }; \
	case "$(DRY)" in 1) echo "  [dry-run] bun add -g $(SUB_DIR) (npm fallback)"; exit 0;; esac; \
	if command -v bun >/dev/null 2>&1; then bun add -g "$(SUB_DIR)"; else npm install --global "$(SUB_DIR)"; fi; \
	$(MAKE) -C "$(CURDIR)" --no-print-directory -f .local/state/depends/herbstutil.Makefile conf-set M=source; \
	printf '  %-11s %s\n' herbstutil "installed from the checkout ($(SUB_DIR); --force redeploys)"

# method resolution: M > conf > source
install:
	@set -e; \
	if command -v herbstutil >/dev/null 2>&1 && [ -z "$(FORCE)" ] && [ -z "$(M)" ]; then \
		printf '  %-11s %s\n' herbstutil "global install present already"; \
		exit 0; \
	fi; \
	RESOLVED="$(M)"; \
	if [ -z "$$RESOLVED" ]; then \
		RESOLVED="$$(make -C "$(CURDIR)" --no-print-directory -f .local/state/depends/herbstutil.Makefile conf-get)"; \
	fi; \
	case "$$RESOLVED" in none) RESOLVED="";; esac; \
	if [ -z "$$RESOLVED" ]; then RESOLVED=source; fi; \
	case "$$RESOLVED" in \
		source) exec $(MAKE) -C "$(CURDIR)" --no-print-directory -f .local/state/depends/herbstutil.Makefile install-source;; \
		npm) exec $(MAKE) -C "$(CURDIR)" --no-print-directory -f .local/state/depends/herbstutil.Makefile install-npm;; \
		*) echo "herbstutil: unknown method '$$RESOLVED' (source|npm)" >&2; exit 2;; \
	esac

uninstall:
	@set -e; \
	case "$(DRY)" in 1) echo "  [dry-run] remove the global herbstutil; conf reset (checkout stays)"; exit 0;; esac; \
	if command -v bun >/dev/null 2>&1; then \
		bun remove -g herbstutil 2>/dev/null || true; \
	else \
		npm uninstall --global herbstutil 2>/dev/null || true; \
	fi; \
	$(MAKE) -C "$(CURDIR)" --no-print-directory -f .local/state/depends/herbstutil.Makefile conf-set M=none; \
	echo "herbstutil: uninstalled (checkout left in place)"

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

status:
	@st=MISSING; command -v herbstutil >/dev/null 2>&1 && st=installed; \
	printf '  %-12s %s\n' herbstutil "$$st"; \
	printf '  %-12s %s\n' method "$$(make -C "$(CURDIR)" --no-print-directory -f .local/state/depends/herbstutil.Makefile conf-get)"

start stop enable disable:
	@echo "herbstutil: nothing to $@ — the deployed artifact is a global library"
