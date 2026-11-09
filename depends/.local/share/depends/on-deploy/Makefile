# depends — the BOOTSTRAP deployable (the 2026-11 router-Makefile).
# Builds and deploys the on-deploy binary itself: nothing here may
# delegate to on-deploy (the bootstrap runs BEFORE the binary exists;
# the bun toolchain assurance goes through npm, not through on-deploy
# toolchain). It is NOT an on-deploy-managed deployable: it stays OUT
# of the configured system.required walk — on-deploy never operates it;
# the MASTER Makefile drives it directly with the operational verbs.
#
# NOTE the submodule path is 2026-11-resplit: the checkout lives with its
# own stow package — dots/on-deploy/.local/share/on-deploy — and the
# ARTIFACT is owned by that package too: dots/on-deploy/.local/bin/on-deploy
# is a TRACKED RELATIVE SYMLINK into the build output
# (../share/on-deploy/dist/on-deploy) — committed repo content, created
# once, NEVER by a recipe: no hardcoded ln/cp placement; the build writes
# only the checkout's dist/ and the deployment to $HOME is stow-managed
# exclusively (the stow recipe below -R-restows the on-deploy package).
# The depends package itself is REMNANTS ONLY (install/ + conf; the
# on.deploy shim was removed 2026-11 — nothing called it).

TOOLCHAIN_BINDIR := $(HOME)/.bun/bin
export PATH := $(TOOLCHAIN_BINDIR):$(PATH)

DOTS     := $(abspath $(CURDIR)/..)
SUB_DIR  := $(DOTS)/on-deploy/.local/share/on-deploy
ARTIFACT := $(DOTS)/on-deploy/.local/bin/on-deploy

.DEFAULT_GOAL := all
.PHONY: all bun-ensure deps-dir deps-install compile rename-artifact \
        stow install-source install uninstall status heal clean

# ── the default: build + stow (the artifact symlink is committed) ──────
all: build stow

# ── the operational verbs (no routing, no metadata) ───────────────────
install: install-source

install-source: bun-ensure build stow

status:
	@if [ -x "$(ARTIFACT)" ]; then echo "depends: installed"; else echo "depends: MISSING; make install-src" >&2; exit 1; fi

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
		echo "depends: bun missing; npm install"; \
		npm install --global bun; \
	else \
		echo "depends: BUN REQUIRED; npm i -g bun" >&2; \
		exit 2; \
	fi

build: deps-install compile rename-artifact

deps-dir:
	@mkdir -p "$(SUB_DIR)/node_modules/.tmp"

# STALE — the freshness test, ONE definition shared by deps-install and
# compile (the guarded set is compile's: src/ + package.json +
# bunli.config.ts; bun.lock deliberately excluded — bun install touches
# its mtime on no-change runs). TRUE = a rebuild is needed. Skipping
# deps-install along with compile matters: bun install is ~1-6s and
# runs on EVERY deployment flow that pulls in the on-deploy target.
#
# The mtime REFERENCE is the build output (dist/on-deploy), NOT the
# ARTIFACT symlink: find's -newer lstats its reference (find -P), so
# comparing against $(ARTIFACT) compared every source against the
# SYMLINK's own fold-time mtime — the guard could never fire and every
# on-deploy pull-in rebuilt the 121M bundle. The -x $(ARTIFACT) test
# stays: the stowed symlink must exist and resolve (deploy presence).
STALE := [ ! -x "$(ARTIFACT)" ] || [ ! -f "$(SUB_DIR)/dist/on-deploy" ] || [ -n "$$(find "$(SUB_DIR)/src" "$(SUB_DIR)/package.json" "$(SUB_DIR)/bunli.config.ts" -newer "$(SUB_DIR)/dist/on-deploy" 2>/dev/null)" ]

deps-install: deps-dir
	@if [ "$(FORCE)" = "1" ] || $(STALE); then \
		env TMPDIR="$(SUB_DIR)/node_modules/.tmp" bun install --cwd "$(SUB_DIR)"; \
	else \
		echo "on-deploy: deps up to date (bun install skipped)"; \
	fi

compile:
	@if [ "$(FORCE)" = "1" ] || $(STALE); then \
		cd "$(SUB_DIR)" && bun x bunli build --targets linux-x64 --minify; \
	else \
		echo "on-deploy: up to date (FORCE=1 to rebuild)"; \
	fi

rename-artifact:
	@if [ -f "$(SUB_DIR)/dist/index" ]; then \
		mv -f "$(SUB_DIR)/dist/index" "$(SUB_DIR)/dist/on-deploy"; \
		rm -f "$(SUB_DIR)/dist/index.js.map"; \
	fi

# stow — THE deployment verb: -R-restow the on-deploy package (the
# artifact symlink's owner); the fresh build reaches ~/.local/bin
# through this stow fold and nothing else
stow:
	@stow -d "$(DOTS)" -R -t "$(HOME)" on-deploy

# clean — the 2026-11 healing recipe (run after a resplit/migration or a
# system upgrade to heal the layout): the resplit moved each bun submodule
# into its OWN stow package (dots/<pkg>/.local/share/<pkg>), while the
# depends package may still hold LEGACY artifacts + fold-stowed copies in
# the old layout (dots/depends/.local/{bin,share}/<pkg>). Stowing depends
# then folds ~/.local/... paths that the owning packages also claim, and
# stow aborts: "existing target is stowed to a different package". This
# recipe is the ORDERED undo:
#   1. unstow the depends package (drops its folds — incl. dangling ones)
#   2. remove the legacy artifact copies from package dirs EXCEPT the
#      remnants (install/ — ../.. never touched)
#   3. restow the remains: depends (remnants) + every owning package
# (stow -D refuses nothing here: the folds it drops are its own links)
LEGACY_DEPS_BINS := herbctl polyframes on-deploy
clean:
	@-stow -d "$(DOTS)" -D -t "$(HOME)" depends; true
	@# 1b. the residue a plain stow -D CANNOT match: links into the OLD
	@#    layout (dots/depends/.local/share/<pkg> — per-file or folded)
	@#    that DANGGLE after the checkout moved to its owning package
	@for p in herbctl herbstutil polyframes on-deploy; do \
		tp="$(HOME)/.local/share/$$p"; \
		if [ -L "$$tp" ]; then \
			case "$$(readlink "$$tp")" in *dots/depends*) rm -f "$$tp";; esac; \
		elif [ -d "$$tp" ]; then \
			find "$$tp" -type l ! -exec test -e {} \; -delete; \
		fi; \
	done
	@for b in herbctl herbstutil polyframes on-deploy; do \
		for p in "$$b"; do \
			if [ -L "$(HOME)/.local/bin/$$b" ] && [ ! -e "$(HOME)/.local/bin/$$b" ]; then \
				rm -f "$(HOME)/.local/bin/$$b"; \
			fi; \
		done; \
	done
	@for b in $(LEGACY_DEPS_BINS); do \
		if [ -f "$(CURDIR)/.local/bin/$$b" ] && [ ! -e "$(DOTS)/$$b/.local/bin/$$b" ]; then \
			echo "deps-clean: kept .local/bin/$$b; no owner" >&2; \
		else \
			rm -f "$(CURDIR)/.local/bin/$$b"; \
		fi; \
	done
	@if [ -e "$(CURDIR)/.local/share" ]; then \
		if [ -e "$(CURDIR)/.local/share/on-deploy" ]; then \
			echo "deps-clean: old checkout here; kept" >&2; \
		else \
			rmdir "$(CURDIR)/.local/share" || true; \
		fi; \
	fi
	@stow -d "$(DOTS)" -R -t "$(HOME)" depends
	@for p in herbctl herbstutil polyframes on-deploy; do \
		if [ -d "$(DOTS)/$$p" ]; then \
			stow -d "$(DOTS)" -R -t "$(HOME)" "$$p"; \
		fi; \
	done

sh_print:
	@echo "stow -d $(DOTS) -R -t $(HOME) depends"
