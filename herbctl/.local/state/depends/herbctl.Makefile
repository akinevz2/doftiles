# herbctl — per-package depends Makefile (the 2026-11 scheme). The
# submodule checkout (dots/herbctl/.local/share/herbctl) builds with
# bun/bunli; the artifact lands in dots/herbctl/.local/bin and stow
# ships it. Split out of the old depends package (each submodule owns
# its artifact, like bat).
#
#   make install                 ensure — method conf > source
#   make install FORCE=1         rebuild even when present
#   make install M=source|npm    explicit method (also recorded)
#   make install DRY=1           print what would run, change nothing
#
# Method knob: doftiles.conf <HERBCTL>=<method> (source build from the
# checkout, or the npm-registry global install — herbctl is published).

DOTS     := $(abspath $(CURDIR)/..)
SUB_DIR  := $(DOTS)/herbctl/.local/share/herbctl
LINK     := $(CURDIR)/.local/bin
SYSBIN   := $(HOME)/.local/bin
ARTIFACT := $(LINK)/herbctl
CONF     := $(HOME)/.config/doftiles.conf

FORCE ?=
DRY   ?=
M     ?=
export FORCE DRY M

.PHONY: toolchain build link install install-npm conf-get conf-set uninstall status stow-herbctl start stop enable disable
.DEFAULT_GOAL := status

toolchain:
	@case "$(DRY)" in 1) echo "  [dry-run] on-deploy toolchain --bun"; exit 0;; esac; \
	[ -x "$(SYSBIN)/on-deploy" ] || { echo "herbctl: $(SYSBIN)/on-deploy missing — run 'make bootstrap' first" >&2; exit 2; }; \
	$(SYSBIN)/on-deploy toolchain --bun

# ── conf (the <HERBCTL>=<method> record, through the stow symlink) ─────
conf-get:
	@[ -f "$(CONF)" ] || { printf ''; exit 0; }; \
	. "$(CONF)" 2>/dev/null || true; \
	printf '%s' "$${HERBCTL:-}"

conf-set:
	@mkdir -p "$$(dirname "$(CONF)")"; \
	touch "$(CONF)"; \
	if grep -q '^HERBCTL=' "$(CONF)"; then \
		sed -i --follow-symlinks "s/^HERBCTL=.*/HERBCTL=$(value M)/" "$(CONF)"; \
	else \
		printf 'HERBCTL=%s\n' "$(value M)" >> "$(CONF)"; \
	fi

build:
	@if [ ! -f "$(SUB_DIR)/src/index.ts" ]; then \
		echo "herbctl: submodule checkout missing — run 'make submodules' first" >&2; exit 2; \
	fi; \
	case "$(DRY)" in 1) echo "  [dry-run] bun install + bunli build -> dist/herbctl"; exit 0;; esac; \
	cd "$(SUB_DIR)" && mkdir -p node_modules/.tmp && \
		TMPDIR="$$(pwd)/node_modules/.tmp" bun install; \
	cd "$(SUB_DIR)" && bun x bunli build --targets linux-x64 --minify; \
	[ -f "$(SUB_DIR)/dist/index" ] || { echo "herbctl: build produced no dist/index" >&2; exit 1; }; \
	mv -f "$(SUB_DIR)/dist/index" "$(SUB_DIR)/dist/herbctl"; \
	rm -f "$(SUB_DIR)/dist/index.js.map"; \
	echo "herbctl: built ($(SUB_DIR)/dist/herbctl)"

link:
	@set -e; \
	case "$(DRY)" in 1) echo "  [dry-run] install the built binary -> $(ARTIFACT)"; exit 0;; esac; \
	mkdir -p "$(LINK)"; \
	[ -f "$(SUB_DIR)/dist/herbctl" ] || { echo "herbctl: not built — make build first" >&2; exit 2; }; \
	install -m 755 "$(SUB_DIR)/dist/herbctl" "$(ARTIFACT)"; \
	echo "herbctl: linked $(ARTIFACT)"

install-npm:
	@set -e; \
	case "$(DRY)" in 1) echo "  [dry-run] bun add -g herbctl (npm fallback)"; exit 0;; esac; \
	if command -v bun >/dev/null 2>&1; then bun add -g herbctl; else npm install --global herbctl; fi; \
	$(MAKE) -C "$(CURDIR)" --no-print-directory -f .local/state/depends/herbctl.Makefile conf-set M=npm; \
	printf '  %-11s %s\n' herbctl "installed from the npm registry (make install FORCE=1 redeploys)"

stow-herbctl:
	@set -e; \
	case "$(DRY)" in 1) echo "  [dry-run] swap a legacy REGULAR ~/.local/bin/herbctl for the package link, then stow -R herbctl"; exit 0;; esac; \
	if [ -f "$(SYSBIN)/herbctl" ] && [ ! -L "$(SYSBIN)/herbctl" ]; then \
		echo "herbctl: legacy regular file at $(SYSBIN)/herbctl — swapping for the package link"; \
		rm -f "$(SYSBIN)/herbctl"; \
	fi; \
	cd "$(DOTS)" && stow -R -t "$(HOME)" herbctl

# method resolution: M > conf > source
install:
	@set -e; \
	if [ -x "$(SYSBIN)/herbctl" ] && [ -e "$(ARTIFACT)" ] && [ -z "$(FORCE)" ] && [ -z "$(M)" ]; then \
		printf '  %-11s %s\n' herbctl "ok ($(SYSBIN)/herbctl deployed already (method=$$(make -C "$(CURDIR)" --no-print-directory -f .local/state/depends/herbctl.Makefile conf-get)) — skipping (--force redeploys))"; \
		exit 0; \
	fi; \
	RESOLVED="$(M)"; \
	if [ -z "$$RESOLVED" ]; then \
		RESOLVED="$$(make -C "$(CURDIR)" --no-print-directory -f .local/state/depends/herbctl.Makefile conf-get)"; \
	fi; \
	case "$$RESOLVED" in none) RESOLVED="";; esac; \
	if [ -z "$$RESOLVED" ]; then RESOLVED=source; fi; \
	case "$$RESOLVED" in \
		source) exec $(MAKE) -C "$(CURDIR)" --no-print-directory -f .local/state/depends/herbctl.Makefile toolchain build link stow-herbctl;; \
		npm) exec $(MAKE) -C "$(CURDIR)" --no-print-directory -f .local/state/depends/herbctl.Makefile install-npm;; \
		*) echo "herbctl: unknown method '$$RESOLVED' (source|npm)" >&2; exit 2;; \
	esac

uninstall:
	@set -e; \
	case "$(DRY)" in 1) echo "  [dry-run] remove the herbctl artifact + links (checkout stays)"; exit 0;; esac; \
	rm -f "$(ARTIFACT)"; \
	[ -L "$(SYSBIN)/herbctl" ] && rm -f "$(SYSBIN)/herbctl"; \
	if command -v bun >/dev/null 2>&1; then \
		bun remove -g herbctl 2>/dev/null || true; \
	else \
		npm uninstall --global herbctl 2>/dev/null || true; \
	fi; \
	$(MAKE) -C "$(CURDIR)" --no-print-directory -f .local/state/depends/herbctl.Makefile conf-set M=none; \
	echo "herbctl: uninstalled (checkout left in place)"

status:
	@for bin in herbctl; do \
		st=MISSING; [ -x "$(SYSBIN)/$$bin" ] && st=installed; \
		printf '  %-12s %s\n' "$$bin" "$$st"; \
	done
	@printf '  %-12s %s\n' link "$$([ -f "$(ARTIFACT)" ] && echo present || echo none)"; \
	printf '  %-12s %s\n' method "$$(make -C "$(CURDIR)" --no-print-directory -f .local/state/depends/herbctl.Makefile conf-get)"

start stop enable disable:
	@echo "herbctl: nothing to $@ — the deployed artifact is a plain binary"
