# depends — the BOOTSTRAP deployable (the 2026-11 router-Makefile).
# Builds and deploys the on-deploy binary itself: nothing here may
# delegate to on-deploy (the bootstrap runs BEFORE the binary exists;
# the bun toolchain assurance goes through npm, not through on-deploy
# toolchain). It is NOT an on-deploy-managed deployable: it stays OUT
# of the configured system.required walk — on-deploy never operates it;
# the MASTER Makefile drives it directly with the operational verbs.
#
# NOTE the submodule path is inferred: depends/.local/share/on-deploy.

TOOLCHAIN_BINDIR := $(HOME)/.bun/bin
export PATH := $(TOOLCHAIN_BINDIR):$(PATH)

SUB_DIR  := $(CURDIR)/.local/share/on-deploy
LINK     := $(CURDIR)/.local/bin
ARTIFACT := $(LINK)/on-deploy
DOTS     := $(abspath $(CURDIR)/..)

.DEFAULT_GOAL := all
.PHONY: all bun-ensure deps-dir deps-install compile rename-artifact \
        link stow install-source install uninstall status

# ── the default: build + link ("make; make install" cadence) ───────────
all: build link

# ── the operational verbs (no routing, no metadata) ───────────────────
install: install-source

install-source: bun-ensure build link stow

status:
	@if [ -x "$(ARTIFACT)" ]; then echo "depends: installed ($(ARTIFACT))"; else echo "depends: MISSING — run 'make -C depends -f .local/state/depends/depends.Makefile install'" >&2; exit 1; fi

# uninstall: the plain reversal (no conf records; no router flows)
uninstall:
	@stow -d "$(DOTS)" -D -t "$(HOME)" depends
	@rm -f "$(ARTIFACT)"

# one logical operation: the bun toolchain assurance (bun or its npm
# bootstrap; GOVERNED checks: bun -> npm -> a loud error naming both)
bun-ensure:
	@if command -v bun >/dev/null 2>&1; then \
		echo "depends: bun present already"; \
	elif command -v npm >/dev/null 2>&1; then \
		echo "depends: bun missing — installing through npm"; \
		npm install --global bun; \
	else \
		echo "depends: neither bun nor npm found — install node/npm first (arch: pacman -S npm / apt install npm)" >&2; \
		exit 2; \
	fi

build: deps-install compile rename-artifact

deps-dir:
	@mkdir -p "$(SUB_DIR)/node_modules/.tmp"

deps-install: deps-dir
	@env TMPDIR="$(SUB_DIR)/node_modules/.tmp" bun install --cwd "$(SUB_DIR)"

compile:
	@cd "$(SUB_DIR)" && bun x bunli build --targets linux-x64 --minify

rename-artifact:
	@mv -f "$(SUB_DIR)/dist/index" "$(SUB_DIR)/dist/on-deploy"
	@rm -f "$(SUB_DIR)/dist/index.js.map"

link:
	@mkdir -p "$(LINK)"
	@ln -f "$(SUB_DIR)/dist/on-deploy" "$(ARTIFACT)"
	@echo "depends: linked $(ARTIFACT)"

stow:
	@stow -d "$(DOTS)" -R -t "$(HOME)" depends

sh_print:
	@echo "stow -d $(DOTS) -R -t $(HOME) depends"
