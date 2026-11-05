# on-deploy — per-package depends Makefile (the 2026-11 scheme). The
# submodule checkout builds with bunli; the compiled binary lands in
# dots/on-deploy/.local/bin and stow ships it to ~/.local/bin.
#
# NOTE the chicken-and-egg: this rule runs INSIDE on-deploy, so the
# bun toolchain assurance that may install bun CANNOT go through
# on-deploy itself — the dots_MAKEFILE_begins with the npm bootstrap
# (_build-on-deploy delegates here with FORCE=1) keeps that prelude and
# does NOT need a binary. This Makefile's toolchain rule therefore
# requires the SYSBIN binary to already exist.
#
#   make install            ensure — build+link+stow when missing
#   make install FORCE=1    rebuild even when present
#   make install DRY=1      print what would run, change nothing

DOTS     := $(abspath $(CURDIR)/..)
SUB_DIR  := $(DOTS)/on-deploy/.local/share/on-deploy
LINK     := $(CURDIR)/.local/bin
SYSBIN   := $(HOME)/.local/bin
ARTIFACT := $(LINK)/on-deploy

FORCE ?=
DRY   ?=
export FORCE DRY

.PHONY: toolchain build link install uninstall status stow-on-deploy start stop enable disable
.DEFAULT_GOAL := status

toolchain:
	@case "$(DRY)" in 1) echo "  [dry-run] on-deploy toolchain --bun"; exit 0;; esac; \
	[ -x "$(SYSBIN)/on-deploy" ] || { echo "on-deploy: $(SYSBIN)/on-deploy missing — bun must be assured by the dots bootstrap (no self-delegation)" >&2; exit 2; }; \
	$(SYSBIN)/on-deploy toolchain --bun

build:
	@if [ ! -f "$(SUB_DIR)/src/index.ts" ]; then \
		echo "on-deploy: submodule checkout missing — run 'make submodules' first" >&2; exit 2; \
	fi; \
	case "$(DRY)" in 1) echo "  [dry-run] bun install + bunli build -> dist/on-deploy"; exit 0;; esac; \
	cd "$(SUB_DIR)" && mkdir -p node_modules/.tmp && \
		TMPDIR="$$(pwd)/node_modules/.tmp" bun install; \
	cd "$(SUB_DIR)" && bun x bunli build --targets linux-x64 --minify; \
	[ -f "$(SUB_DIR)/dist/index" ] || { echo "on-deploy: build produced no dist/index" >&2; exit 1; }; \
	mv -f "$(SUB_DIR)/dist/index" "$(SUB_DIR)/dist/on-deploy"; \
	rm -f "$(SUB_DIR)/dist/index.js.map"; \
	echo "on-deploy: built ($(SUB_DIR)/dist/on-deploy)"

link:
	@set -e; \
	case "$(DRY)" in 1) echo "  [dry-run] install the built binary -> $(ARTIFACT)"; exit 0;; esac; \
	mkdir -p "$(LINK)"; \
	[ -f "$(SUB_DIR)/dist/on-deploy" ] || { echo "on-deploy: not built — make build first" >&2; exit 2; }; \
	install -m 755 "$(SUB_DIR)/dist/on-deploy" "$(ARTIFACT)"; \
	echo "on-deploy: linked $(ARTIFACT)"

stow-on-deploy:
	@set -e; \
	case "$(DRY)" in 1) echo "  [dry-run] swap a legacy REGULAR ~/.local/bin/on-deploy for the package link, then stow -R on-deploy"; exit 0;; esac; \
	if [ -f "$(SYSBIN)/on-deploy" ] && [ ! -L "$(SYSBIN)/on-deploy" ]; then \
		echo "on-deploy: legacy regular file at $(SYSBIN)/on-deploy — swapping for the package link"; \
		rm -f "$(SYSBIN)/on-deploy"; \
	fi; \
	cd "$(DOTS)" && stow -R -t "$(HOME)" on-deploy

# NOTE: no `toolchain` prerequisite here — this rule RUNS INSIDE
# on-deploy and must not require the binary it is building; the bun
# assurance lives in the dots `_build-on-deploy` prelude (npm path).
install: build link stow-on-deploy
	@case "$(DRY)" in 1) printf '  %-11s %s\n' on-deploy "[dry-run] build + link + stow"; exit 0;; esac; \
	printf '  %-11s %s\n' on-deploy "installed ($(SYSBIN)/on-deploy <- $(ARTIFACT))"

uninstall:
	@set -e; \
	case "$(DRY)" in 1) echo "  [dry-run] remove the on-deploy artifact + links (checkout stays)"; exit 0;; esac; \
	rm -f "$(ARTIFACT)"; \
	[ -L "$(SYSBIN)/on-deploy" ] && rm -f "$(SYSBIN)/on-deploy"; \
	echo "on-deploy: uninstalled (checkout left in place)"

status:
	@for bin in on-deploy; do \
		st=MISSING; [ -x "$(SYSBIN)/$$bin" ] && st=installed; \
		printf '  %-12s %s\n' "$$bin" "$$st"; \
	done
	@printf '  %-12s %s\n' link "$$([ -f "$(ARTIFACT)" ] && echo present || echo none)"

start stop enable disable:
	@echo "on-deploy: nothing to $@ — the deployed artifact is a plain binary"
