# herbctl — per-package depends Makefile (the 2026-11 scheme). The
# submodule checkout (dots/herbctl/.local/share/herbctl) builds with
# bun/bunli; the artifact lands in dots/herbctl/.local/bin and stow
# ships it. Split out of the old depends package (each submodule owns
# its artifact, like bat).
#
#   make install            ensure — build+link+stow when missing
#   make install FORCE=1    rebuild even when present
#   make install DRY=1      print what would run, change nothing

DOTS     := $(abspath $(CURDIR)/..)
SUB_DIR  := $(DOTS)/herbctl/.local/share/herbctl
LINK     := $(CURDIR)/.local/bin
SYSBIN   := $(HOME)/.local/bin
ARTIFACT := $(LINK)/herbctl

FORCE ?=
DRY   ?=
export FORCE DRY

.PHONY: toolchain build link install uninstall status stow-herbctl start stop enable disable
.DEFAULT_GOAL := status

toolchain:
	@case "$(DRY)" in 1) echo "  [dry-run] on-deploy toolchain --bun"; exit 0;; esac; \
	[ -x "$(SYSBIN)/on-deploy" ] || { echo "herbctl: $(SYSBIN)/on-deploy missing — run 'make bootstrap' first" >&2; exit 2; }; \
	$(SYSBIN)/on-deploy toolchain --bun

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

stow-herbctl:
	@set -e; \
	case "$(DRY)" in 1) echo "  [dry-run] swap a legacy REGULAR ~/.local/bin/herbctl for the package link, then stow -R herbctl"; exit 0;; esac; \
	if [ -f "$(SYSBIN)/herbctl" ] && [ ! -L "$(SYSBIN)/herbctl" ]; then \
		echo "herbctl: legacy regular file at $(SYSBIN)/herbctl — swapping for the package link"; \
		rm -f "$(SYSBIN)/herbctl"; \
	fi; \
	cd "$(DOTS)" && stow -R -t "$(HOME)" herbctl

install: toolchain build link stow-herbctl
	@case "$(DRY)" in 1) printf '  %-11s %s\n' herbctl "[dry-run] build + link + stow"; exit 0;; esac; \
	printf '  %-11s %s\n' herbctl "installed ($(SYSBIN)/herbctl <- $(ARTIFACT))"

uninstall:
	@set -e; \
	case "$(DRY)" in 1) echo "  [dry-run] remove the herbctl artifact + links (checkout stays)"; exit 0;; esac; \
	rm -f "$(ARTIFACT)"; \
	[ -L "$(SYSBIN)/herbctl" ] && rm -f "$(SYSBIN)/herbctl"; \
	echo "herbctl: uninstalled (checkout left in place)"

status:
	@for bin in herbctl; do \
		st=MISSING; [ -x "$(SYSBIN)/$$bin" ] && st=installed; \
		printf '  %-12s %s\n' "$$bin" "$$st"; \
	done
	@printf '  %-12s %s\n' link "$$([ -f "$(ARTIFACT)" ] && echo present || echo none)"

start stop enable disable:
	@echo "herbctl: nothing to $@ — the deployed artifact is a plain binary"
