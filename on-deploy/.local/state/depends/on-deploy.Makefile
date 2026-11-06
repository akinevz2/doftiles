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
#   make install                 ensure — build+link+stow when missing
#   make install FORCE=1         rebuild even when present
#   make install M=source|npm    explicit method (also recorded); the
#                                npm route is reserved for the day the
#                                binary is published to the registry —
#                                selecting it today fails cleanly
#   make install DRY=1           print what would run, change nothing
#
# Method knob: doftiles.conf <ON_DEPLOY>=<method> (source|npm).

DOTS     := $(abspath $(CURDIR)/..)
SUB_DIR  := $(DOTS)/on-deploy/.local/share/on-deploy
LINK     := $(CURDIR)/.local/bin
SYSBIN   := $(HOME)/.local/bin
ARTIFACT := $(LINK)/on-deploy
CONF     := $(HOME)/.config/doftiles.conf

FORCE ?=
DRY   ?=
M     ?=
export FORCE DRY M

.PHONY: toolchain build link install install-npm conf-get conf-set uninstall status stow-on-deploy start stop enable disable
.DEFAULT_GOAL := status

toolchain:
	@case "$(DRY)" in 1) echo "  [dry-run] on-deploy toolchain --bun"; exit 0;; esac; \
	[ -x "$(SYSBIN)/on-deploy" ] || { echo "on-deploy: $(SYSBIN)/on-deploy missing — bun must be assured by the dots bootstrap (no self-delegation)" >&2; exit 2; }; \
	$(SYSBIN)/on-deploy toolchain --bun

# ── conf (the <ON_DEPLOY>=<method> record, through the stow symlink) ───
conf-get:
	@[ -f "$(CONF)" ] || { printf ''; exit 0; }; \
	. "$(CONF)" 2>/dev/null || true; \
	printf '%s' "$${ON_DEPLOY:-}"

conf-set:
	@mkdir -p "$$(dirname "$(CONF)")"; \
	touch "$(CONF)"; \
	if grep -q '^ON_DEPLOY=' "$(CONF)"; then \
		sed -i --follow-symlinks "s/^ON_DEPLOY=.*/ON_DEPLOY=$(value M)/" "$(CONF)"; \
	else \
		printf 'ON_DEPLOY=%s\n' "$(value M)" >> "$(CONF)"; \
	fi

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
install-npm:
	@set -e; \
	case "$(DRY)" in 1) echo "  [dry-run] bun add -g on-deploy (npm fallback)"; exit 0;; esac; \
	if ! (command -v bun >/dev/null 2>&1 && bun pm view on-deploy version >/dev/null 2>&1) && \
	   ! (command -v npm >/dev/null 2>&1 && npm view on-deploy version >/dev/null 2>&1); then \
		echo "on-deploy: not published in the npm registry — the npm route is reserved for when the binary ships to the registry" >&2; \
		exit 2; \
	fi; \
	command -v bun >/dev/null 2>&1 && bun add -g on-deploy || npm install --global on-deploy; \
	$(MAKE) -C "$(CURDIR)" --no-print-directory -f .local/state/depends/on-deploy.Makefile conf-set M=npm; \
	printf '  %-11s %s\n' on-deploy "installed from the npm registry (make install FORCE=1 redeploys)"

# method resolution: M > conf > source.
install:
	@set -e; \
	if [ -x "$(SYSBIN)/on-deploy" ] && [ -e "$(ARTIFACT)" ] && [ -z "$(FORCE)" ] && [ -z "$(M)" ]; then \
		printf '  %-11s %s\n' on-deploy "ok ($(SYSBIN)/on-deploy deployed already — skipping (--force redeploys))"; \
		exit 0; \
	fi; \
	RESOLVED="$(M)"; \
	if [ -z "$$RESOLVED" ]; then \
		RESOLVED="$$(make -C "$(CURDIR)" --no-print-directory -f .local/state/depends/on-deploy.Makefile conf-get)"; \
	fi; \
	case "$$RESOLVED" in none) RESOLVED="";; esac; \
	if [ -z "$$RESOLVED" ]; then RESOLVED=source; fi; \
	case "$$RESOLVED" in \
		source) exec $(MAKE) -C "$(CURDIR)" --no-print-directory -f .local/state/depends/on-deploy.Makefile build link stow-on-deploy;; \
		npm) exec $(MAKE) -C "$(CURDIR)" --no-print-directory -f .local/state/depends/on-deploy.Makefile install-npm;; \
		*) echo "on-deploy: unknown method '$$RESOLVED' (source|npm)" >&2; exit 2;; \
	esac

uninstall:
	@set -e; \
	case "$(DRY)" in 1) echo "  [dry-run] remove the on-deploy artifact + links (checkout stays)"; exit 0;; esac; \
	rm -f "$(ARTIFACT)"; \
	[ -L "$(SYSBIN)/on-deploy" ] && rm -f "$(SYSBIN)/on-deploy"; \
	$(MAKE) -C "$(CURDIR)" --no-print-directory -f .local/state/depends/on-deploy.Makefile conf-set M=none; \
	echo "on-deploy: uninstalled (checkout left in place)"

status:
	@for bin in on-deploy; do \
		st=MISSING; [ -x "$(SYSBIN)/$$bin" ] && st=installed; \
		printf '  %-12s %s\n' "$$bin" "$$st"; \
	done
	@printf '  %-12s %s\n' link "$$([ -f "$(ARTIFACT)" ] && echo present || echo none)"; \
	printf '  %-12s %s\n' method "$$(make -C "$(CURDIR)" --no-print-directory -f .local/state/depends/on-deploy.Makefile conf-get)"

start stop enable disable:
	@echo "on-deploy: nothing to $@ — the deployed artifact is a plain binary"
