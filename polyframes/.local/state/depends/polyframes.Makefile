# polyframes — per-package depends Makefile (the 2026-11 scheme). The
# submodule checkout builds with bun + the checkout's own make; the
# artifact lands in dots/polyframes/.local/bin and stow ships it.
# Method record: ~/.config/doftiles.conf POLYFRAMES_METHOD
# (source | npm | none; written through the stow symlink).
#
#   make install            ensure — method conf > source
#   make install FORCE=1    rebuild/redeploy even when present
#   make install PKG=true   the npm rider instead of source
#   make install M=npm      explicit method (also recorded)
#   make install DRY=1      print what would run, change nothing

DOTS     := $(abspath $(CURDIR)/..)
SUB_DIR  := $(DOTS)/polyframes/.local/share/polyframes
LINK     := $(CURDIR)/.local/bin
SYSBIN   := $(HOME)/.local/bin
ARTIFACT := $(LINK)/polyframes
CONF     := $(HOME)/.config/doftiles.conf

FORCE ?=
DRY   ?=
M     ?=
export FORCE DRY M

.PHONY: toolchain build link install install-polyframes-source \
        install-polyframes-npm conf-get conf-set stow-polyframes \
        uninstall status start stop enable disable
.DEFAULT_GOAL := status

toolchain:
	@case "$(DRY)" in 1) echo "  [dry-run] on-deploy toolchain --bun"; exit 0;; esac; \
	[ -x "$(SYSBIN)/on-deploy" ] || { echo "polyframes: $(SYSBIN)/on-deploy missing — run 'make bootstrap' first" >&2; exit 2; }; \
	$(SYSBIN)/on-deploy toolchain --bun

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

build:
	@if [ ! -f "$(SUB_DIR)/Makefile" ]; then \
		echo "polyframes: submodule checkout missing — run 'make submodules' first" >&2; exit 2; \
	fi; \
	case "$(DRY)" in 1) echo "  [dry-run] bun install + make build -> dist/polyframes"; exit 0;; esac; \
	cd "$(SUB_DIR)" && mkdir -p node_modules/.tmp && \
		TMPDIR="$$(pwd)/node_modules/.tmp" bun install; \
	$(MAKE) -C "$(SUB_DIR)" --no-print-directory build

link:
	@set -e; \
	case "$(DRY)" in 1) echo "  [dry-run] install the built binary -> $(ARTIFACT)"; exit 0;; esac; \
	mkdir -p "$(LINK)"; \
	[ -f "$(SUB_DIR)/dist/polyframes" ] || { echo "polyframes: not built — make build first" >&2; exit 2; }; \
	install -m 755 "$(SUB_DIR)/dist/polyframes" "$(ARTIFACT)"; \
	echo "polyframes: linked $(ARTIFACT)"

stow-polyframes:
	@set -e; \
	case "$(DRY)" in 1) echo "  [dry-run] swap a legacy REGULAR ~/.local/bin/polyframes for the package link, then stow -R polyframes"; exit 0;; esac; \
	if [ -f "$(SYSBIN)/polyframes" ] && [ ! -L "$(SYSBIN)/polyframes" ]; then \
		echo "polyframes: legacy regular file at $(SYSBIN)/polyframes — swapping for the package link"; \
		rm -f "$(SYSBIN)/polyframes"; \
	fi; \
	cd "$(DOTS)" && stow -R -t "$(HOME)" polyframes

install-polyframes-source: toolchain build link stow-polyframes
	@set -e; \
	case "$(DRY)" in 1) printf '  %-11s %s\n' polyframes "[dry-run] source build + link + stow"; exit 0;; esac; \
	$(MAKE) -C "$(CURDIR)" --no-print-directory -f .local/state/depends/polyframes.Makefile conf-set M=source; \
	printf '  %-11s %s\n' polyframes "built from source -> $(ARTIFACT)"

install-polyframes-npm:
	@set -e; \
	case "$(DRY)" in 1) echo "  [dry-run] npm install --global github:akinevz2/polyframes"; exit 0;; esac; \
	command -v npm >/dev/null 2>&1 || { echo "polyframes: npm not found (install node/npm first)" >&2; exit 2; }; \
	echo "polyframes: via the npm rider ('release' fetches the same published artifact)"; \
	npm install --global github:akinevz2/polyframes; \
	$(MAKE) -C "$(CURDIR)" --no-print-directory -f .local/state/depends/polyframes.Makefile conf-set M=npm; \
	printf '  %-11s %s\n' polyframes "installed via npm"

# method resolution: M > conf > source (PKG=true -> npm)
install:
	@if [ "$(PKG)" = "true" ]; then exec $(MAKE) --no-print-directory -f .local/state/depends/polyframes.Makefile install-polyframes-npm; fi; \
	set -e; \
	TMP="$$(make -C "$(CURDIR)" --no-print-directory -f .local/state/depends/polyframes.Makefile conf-get)"; \
	METHOD="$(M)"; \
	if [ -z "$$METHOD" ]; then METHOD="$$TMP"; fi; \
	if [ -z "$$METHOD" ]; then \
		if command -v bun >/dev/null 2>&1; then METHOD=source; else METHOD=release; fi; \
	fi; \
	if [ -e "$(ARTIFACT)" ] && [ -L "$(SYSBIN)/polyframes" ] && [ "$(FORCE)" != 1 ] && [ -z "$(M)" ]; then \
		printf '  %-11s %s\n' polyframes "deployed already (method=$$METHOD) — skipping (--force redeploys)"; \
		exit 0; \
	fi; \
	case "$$METHOD" in \
		source) $(MAKE) --no-print-directory -f .local/state/depends/polyframes.Makefile install-polyframes-source;; \
		release|npm) $(MAKE) --no-print-directory -f .local/state/depends/polyframes.Makefile install-polyframes-npm M=$$METHOD;; \
		*) echo "polyframes: unknown method '$$METHOD' (source|npm)" >&2; exit 2;; \
	esac

uninstall:
	@set -e; \
	case "$(DRY)" in 1) echo "  [dry-run] remove the polyframes artifact + links; conf reset (checkout stays)"; exit 0;; esac; \
	rm -f "$(ARTIFACT)"; \
	if [ -L "$(SYSBIN)/polyframes" ]; then rm -f "$(SYSBIN)/polyframes"; fi; \
	if command -v polyframes >/dev/null 2>&1 && [ ! -L "$(SYSBIN)/polyframes" ]; then \
		npm uninstall --global polyframes 2>/dev/null || true; \
	fi; \
	if grep -q '^POLYFRAMES_METHOD=' "$(CONF)"; then \
		sed -i --follow-symlinks "s/^POLYFRAMES_METHOD=.*/POLYFRAMES_METHOD=none/" "$(CONF)"; \
	fi; \
	echo "polyframes: uninstalled (checkout left in place)"

status:
	@st=MISSING; [ -x "$(SYSBIN)/polyframes" ] && st=installed; \
	printf '  %-12s %s\n' polyframes "$$st"; \
	printf '  %-12s %s\n' method "$$([ -f "$(ARTIFACT)" ] && echo linked || echo none) ($$(make -C "$(CURDIR)" --no-print-directory -f .local/state/depends/polyframes.Makefile conf-get))"

start stop enable disable:
	@echo "polyframes: nothing to $@ — the deployed artifact is a plain binary"
