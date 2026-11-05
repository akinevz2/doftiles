# depends — the per-package depends Makefile of the 2026-11 scheme
# (dots/<pkg>/.local/state/depends/<pkg>.Makefile, driven by
# `on-deploy depends --build|--install` and by the dots Makefile).
#
# This package hosts FOUR bun submodules; every build/install/link
# step lives HERE (on-deploy hardcodes nothing per package):
#
#   on-deploy   rebuilt UNCONDITIONALLY every run — a submodule pull
#               must always land a fresh binary. (The bootstrap build
#               itself stays in the dots Makefile: on-deploy cannot
#               delegate to itself until it exists.)
#   herbctl     bunli build -> dots/depends/.local/bin/herbctl — the
#               built binary is LINKED into the package's .local/bin
#               and stow ships it into ~/.local/bin.
#   polyframes  bun install + the checkout's own `make build` ->
#               dots/depends/.local/bin/polyframes (same link flow).
#               Method record: ~.config/doftiles.conf (source | npm |
#               none; written through the stow symlink).
#   herbstutil  GLOBALLY installed through the npm/bun registry (an
#               npm package, not a bundled binary).
#
# Standard rules (on-deploy packages ... reaches them):
#   toolchain build link install uninstall status
#   + start/stop/enable/disable — deliberate no-ops (plain binaries)
#
# Knobs (make variables):
#   make install            ensure — install only when missing
#   make install FORCE=1    rebuild/redeploy even when present
#   make install PKG=true   the platform/rider package manager instead
#                           of source (npm specs for the JS artifacts);
#                           PKG is per-package flavored (see bat)
#   make install DRY=1      print what would run, change nothing
#   make install M=source   explicit polyframes method (also recorded)
#   make toolchain          this package's language toolchains via
#                           `on-deploy toolchain --bun`
#   make link               link the built binaries into
#                           dots/depends/.local/bin
#   make trust-local        bun trust for every checked-out bun
#                           submodule of the dots repo
#   make trust-global       bun pm trust -g (the global untrusted set)
#
# Exit codes: 2 env/precondition, 1 operational failure, 0 ok/no-op.

DOTS         := $(abspath $(CURDIR)/..)
ONDEPLOY_DIR := $(DOTS)/depends/.local/share/on-deploy
HERBCTL_DIR  := $(DOTS)/depends/.local/share/herbctl
POLY_DIR     := $(DOTS)/depends/.local/share/polyframes
HSU_DIR      := $(DOTS)/depends/.local/share/herbstutil

LINK   := $(CURDIR)/.local/bin
SYSBIN := $(HOME)/.local/bin
ONDEPLOY := $(SYSBIN)/on-deploy
CONF   := $(HOME)/.config/doftiles.conf

FORCE ?=
DRY   ?=
PKG   ?=
M     ?=

# the knobs flow into sub-make calls (env), so nested rules see them
export FORCE DRY PKG M

.PHONY: toolchain build link install on-deploy-build on-deploy \
        herbctl-build herbctl polyframes-build polyframes \
        install-polyframes-source install-polyframes-npm \
        install-herbstutil-npm herbstutil \
        trust-local trust-global conf-get conf-set \
        stow-depends uninstall status start stop enable disable
.DEFAULT_GOAL := status

# ── conf (the POLYFRAMES_METHOD record, through the stow symlink) ─────
conf-get:
	@[ -f "$(CONF)" ] || { printf 'none'; exit 0; }; \
	. "$(CONF)" 2>/dev/null || true; \
	printf '%s' "$${POLYFRAMES_METHOD:-}"

conf-set:
	@mkdir -p "$$(dirname "$(CONF)")"; \
	touch "$(CONF)"; \
	if grep -q '^POLYFRAMES_METHOD=' "$(CONF)"; then \
		sed -i --follow-symlinks "s/^POLYFRAMES_METHOD=.*/POLYFRAMES_METHOD=$(value M)/" "$(CONF)"; \
	else \
		printf 'POLYFRAMES_METHOD=%s\n' "$(value M)" >> "$(CONF)"; \
	fi

# ── toolchain: the language(s) of this package's submodules ───────────
toolchain:
	@case "$(DRY)" in 1) echo "  [dry-run] on-deploy toolchain --bun"; exit 0;; esac; \
	[ -x "$(SYSBIN)/on-deploy" ] || { echo "depends: $(SYSBIN)/on-deploy missing — run 'make bootstrap' first" >&2; exit 2; }; \
	$(SYSBIN)/on-deploy toolchain --bun || { echo "depends: bun toolchain missing (on-deploy toolchain --bun failed)" >&2; exit 2; }

# ── build: compile WITHOUT placing anything (bun install + bunli) ─────
build: on-deploy-build herbctl-build

on-deploy-build:
	@if [ ! -f "$(ONDEPLOY_DIR)/src/index.ts" ]; then \
		echo "depends: submodule checkout missing — $(ONDEPLOY_DIR)" >&2; \
		echo "  run 'make submodules' first" >&2; exit 2; \
	fi; \
	if [ "$(DRY)" = 1 ]; then echo "  [dry-run] bun install + bunli build in $(ONDEPLOY_DIR) + install"; exit 0; fi; \
	$(MAKE) -C "$(DOTS)" --no-print-directory _build-on-deploy

herbctl-build:
	@if [ ! -f "$(HERBCTL_DIR)/src/index.ts" ]; then \
		echo "depends: submodule checkout missing — $(HERBCTL_DIR)" >&2; \
		echo "  run 'make submodules' first" >&2; exit 2; \
	fi; \
	if [ "$(DRY)" = 1 ]; then echo "  [dry-run] bun install + bunli build in $(HERBCTL_DIR) -> dist/herbctl"; exit 0; fi; \
	cd "$(HERBCTL_DIR)" && mkdir -p node_modules/.tmp && \
		TMPDIR="$$(pwd)/node_modules/.tmp" bun install; \
	cd "$(HERBCTL_DIR)" && bun x bunli build --targets linux-x64 --minify; \
	[ -f "$(HERBCTL_DIR)/dist/index" ] || { echo "depends: herbctl build produced no dist/index" >&2; exit 1; }; \
	mv -f "$(HERBCTL_DIR)/dist/index" "$(HERBCTL_DIR)/dist/herbctl"; \
	rm -f "$(HERBCTL_DIR)/dist/index.js.map"; \
	echo "depends: herbctl built ($(HERBCTL_DIR)/dist/herbctl)"

polyframes-build:
	@if [ ! -f "$(POLY_DIR)/Makefile" ]; then \
		echo "depends: submodule checkout missing — $(POLY_DIR)" >&2; \
		echo "  run 'make submodules' first" >&2; exit 2; \
	fi; \
	if [ "$(DRY)" = 1 ]; then echo "  [dry-run] bun install + make build in $(POLY_DIR) -> dist/polyframes"; exit 0; fi; \
	cd "$(POLY_DIR)" && mkdir -p node_modules/.tmp && \
		TMPDIR="$$(pwd)/node_modules/.tmp" bun install; \
	$(MAKE) -C "$(POLY_DIR)" --no-print-directory build

# ── link: place the built binaries into dots/depends/.local/bin (stow
#    then ships them; the package owns its artifacts) ──────────────────
link:
	@set -e; \
	case "$(DRY)" in 1) echo "  [dry-run] link the built binaries -> $(LINK)"; exit 0;; esac; \
	mkdir -p "$(LINK)"; \
	if [ -f "$(HERBCTL_DIR)/dist/herbctl" ]; then \
		install -m 755 "$(HERBCTL_DIR)/dist/herbctl" "$(LINK)/herbctl"; \
		echo "  linked $(LINK)/herbctl"; \
	else \
		echo "depends: herbctl not built — make build first" >&2; exit 2; \
	fi; \
	if [ -f "$(POLY_DIR)/dist/polyframes" ]; then \
		install -m 755 "$(POLY_DIR)/dist/polyframes" "$(LINK)/polyframes"; \
		echo "  linked $(LINK)/polyframes"; \
	fi

# ── stow helper: the package carries its own artifacts; a legacy
#    REGULAR file at the system path would conflict — the guard swaps
#    it for the stow link (the repo now owns the artifact) ─────────────
stow-depends:
	@set -e; \
	case "$(DRY)" in 1) echo "  [dry-run] restow the depends package (stow -R -t HOME depends)"; exit 0;; esac; \
	# legacy REGULAR-FILE builds at the system paths: swapped for the \
	# package links (only artifacts the package now carries as files; \
	# shared tree dirs like ~/.local/bin/install fold per-file in stow) \
	for f in $$(find "$(LINK)" -maxdepth 1 -type f 2>/dev/null -printf '%f\n'); do \
		if [ -f "$(SYSBIN)/$$f" ] && [ ! -L "$(SYSBIN)/$$f" ]; then \
			echo "depends: $(SYSBIN)/$$f is a legacy regular file — swapping for the package link"; \
			rm -f "$(SYSBIN)/$$f"; \
		fi; \
	done; \
	cd "$(DOTS)" && stow -R -t "$(HOME)" depends

# ── artifact deploys ──────────────────────────────────────────────────
on-deploy: on-deploy-build
	@case "$(DRY)" in 1) printf '  %-11s %s\n' on-deploy "[dry-run] rebuild + install"; exit 0;; esac; \
	printf '  %-11s %s\n' on-deploy "rebuilt + installed ($(SYSBIN)/on-deploy)"

herbctl: herbctl-build link stow-depends
	@case "$(DRY)" in 1) printf '  %-11s %s\n' herbctl "[dry-run] build + link + stow"; exit 0;; esac; \
	printf '  %-11s %s\n' herbctl "installed ($(SYSBIN)/herbctl <- $(LINK)/herbctl)"

# polyframes — method resolution: M > conf > source (PKG=true -> npm)
polyframes:
	@if [ "$(PKG)" = "true" ]; then exec $(MAKE) --no-print-directory -f .local/state/depends/depends.Makefile install-polyframes-npm; fi; \
	set -e; \
	TMP="$$(make -C "$(CURDIR)" --no-print-directory -f .local/state/depends/depends.Makefile conf-get)"; \
	METHOD="$(M)"; \
	if [ -z "$$METHOD" ]; then METHOD="$$TMP"; fi; \
	if [ -z "$$METHOD" ]; then \
		if command -v bun >/dev/null 2>&1; then METHOD=source; else METHOD=release; fi; \
	fi; \
	if [ -e "$(LINK)/polyframes" ] && [ -L "$(SYSBIN)/polyframes" ] && [ "$(FORCE)" != 1 ] && [ -z "$(M)" ]; then \
		printf '  %-11s %s\n' polyframes "deployed already (method=$$METHOD) — skipping (--force redeploys)"; \
		exit 0; \
	fi; \
	case "$$METHOD" in \
		source) $(MAKE) --no-print-directory -f .local/state/depends/depends.Makefile install-polyframes-source;; \
		release|npm) $(MAKE) --no-print-directory -f .local/state/depends/depends.Makefile install-polyframes-npm M=$$METHOD;; \
		*) echo "depends: unknown polyframes method '$$METHOD' (source|npm)" >&2; exit 2;; \
	esac

install-polyframes-source: polyframes-build link stow-depends
	@set -e; \
	case "$(DRY)" in 1) printf '  %-11s %s\n' polyframes "[dry-run] source build + link + stow"; exit 0;; esac; \
	$(MAKE) -C "$(CURDIR)" --no-print-directory -f .local/state/depends/depends.Makefile conf-set M=source; \
	printf '  %-11s %s\n' polyframes "built from source -> $(LINK)/polyframes"

install-polyframes-npm:
	@set -e; \
	case "$(DRY)" in 1) echo "  [dry-run] npm install --global github:akinevz2/polyframes"; exit 0;; esac; \
	command -v npm >/dev/null 2>&1 || { echo "depends: npm not found (install node/npm first)" >&2; exit 2; }; \
	echo "depends: polyframes via the npm rider ('release' fetches the same published artifact)"; \
	npm install --global github:akinevz2/polyframes; \
	$(MAKE) -C "$(CURDIR)" --no-print-directory -f .local/state/depends/depends.Makefile conf-set M=npm; \
	printf '  %-11s %s\n' polyframes "installed via npm"

herbstutil: install-herbstutil-npm

install-herbstutil-npm:
	@set -e; \
	if command -v herbstutil >/dev/null 2>&1; then \
		printf '  %-11s %s\n' herbstutil "global install present already"; \
		exit 0; \
	fi; \
	case "$(DRY)" in 1) echo "  [dry-run] npm install --global herbstutil"; exit 0;; esac; \
	if command -v bun >/dev/null 2>&1; then \
		bun add -g herbstutil; \
	else \
		npm install --global herbstutil; \
	fi

# ── aggregates (the rules `on-deploy depends` drives) ─────────────────
install: toolchain on-deploy herbctl polyframes herbstutil
	@echo "depends: install done (driven per artifact)"

# ── bun trust (the dots bootstrap's trust step delegates here) ────────
# trust-local — every checked-out BUN submodule of the dots repo
# (.gitmodules paths with a package.json) gets its locally blocked
# postinstall scripts trusted. trust-global — bun's GLOBAL untrusted
# set (bun's default policy keeps postinstall blocked — quirk 17).
trust-local:
	@set -e; \
	if [ "$(DRY)" = 1 ]; then echo "  [dry-run] bun pm trust per bun submodule"; exit 0; fi; \
	if ! command -v bun >/dev/null 2>&1; then \
		echo "depends: bun absent — nothing to trust locally"; exit 0; \
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
		echo "depends: trust-local done on $$pcount bun submodule(s)"; \
	else \
		echo "depends: no checked-out bun submodules to trust"; \
	fi

trust-global:
	@set -e; \
	if [ "$(DRY)" = 1 ]; then echo "  [dry-run] bun pm trust -g for the global untrusted set"; exit 0; fi; \
	if ! command -v bun >/dev/null 2>&1; then \
		echo "depends: bun absent — nothing to trust globally"; exit 0; \
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

# ── uninstall (the recorded method, conf reset; the checkout stays) ───
uninstall:
	@set -e; \
	case "$(DRY)" in 1) echo "  [dry-run] remove the depends artifacts per the recorded method"; exit 0;; esac; \
	rm -f "$(LINK)/herbctl" "$(LINK)/polyframes"; \
	if [ -L "$(SYSBIN)/herbctl" ]; then rm -f "$(SYSBIN)/herbctl"; fi; \
	if command -v polyframes >/dev/null 2>&1 && [ ! -L "$(SYSBIN)/polyframes" ]; then \
		npm uninstall --global polyframes 2>/dev/null || true; \
	fi; \
	if command -v herbstutil >/dev/null 2>&1; then \
		if command -v bun >/dev/null 2>&1; then bun remove -g herbstutil; else npm uninstall --global herbstutil; fi; \
	fi; \
	if grep -q '^POLYFRAMES_METHOD=' "$(CONF)"; then \
		sed -i --follow-symlinks "s/^POLYFRAMES_METHOD=.*/POLYFRAMES_METHOD=none/" "$(CONF)"; \
	fi; \
	cd "$(DOTS)" && stow -R -t "$(HOME)" depends; \
	echo "depends: uninstalled (submodule checkouts left in place)"

# ── status ────────────────────────────────────────────────────────────
status:
	@for bin in on-deploy herbctl polyframes herbstutil; do \
		st=MISSING; \
		if [ -x "$(SYSBIN)/$$bin" ]; then st=installed; fi; \
		printf '  %-12s %s\n' "$$bin" "$$st"; \
	done; \
	printf '  %-12s %s\n' method "$$(make -C "$(CURDIR)" --no-print-directory -f .local/state/depends/depends.Makefile conf-get)"; \
	if [ -f "$(LINK)/herbctl" ]; then pstate=linked; else pstate=none; fi; \
	printf '  %-12s %s\n' package-link "$$pstate"

start stop enable disable:
	@echo "depends: nothing to $@ — the deployed artifacts are plain binaries"
