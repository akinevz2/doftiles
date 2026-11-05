# bat — the per-package depends Makefile of the 2026-11 scheme
# (dots/<pkg>/.local/state/depends/<pkg>.Makefile, driven by
# `on-deploy depends --build|--install`).
#
# Bat is an upstream Rust project (sharkdp/bat, submodule
# dots/bat/.local/share/bat-src) whose apt package ships the binary as
# `batcat` on Debian/Ubuntu. Every build/install/link step lives HERE
# (on-deploy hardcodes nothing per package):
#
#   toolchain   on-deploy toolchain --rustup (rustc/cargo via the
#               platform package manager; missing rustup fail-fasts)
#   build       checkout ensure + cargo build --release --locked
#   link        target/release/bat -> dots/bat/.local/bin/bat (the
#               package owns the artifact; stow ships it)
#   install     source (default) = toolchain + build + link + stow;
#               PKG=true = the deploy target's platform package
#               manager (`on-deploy pkg install bat`; the apt binary
#               lands as `batcat`, the source build keeps the name);
#               the legacy release-download method stays reachable
#               via M=release (recorded in doftiles.conf BAT_METHOD)
#   uninstall   remove the binary + links, reset the method record
#   status      binary / method / checkout / toolchain report
#
# Standard rules (on-deploy packages ... reaches them):
#   install start stop enable disable uninstall status
#   + start/stop/enable/disable — deliberate no-ops (plain binaries)
#
# Knobs (make variables):
#   make install            ensure — build/deploy only when missing
#   make install FORCE=1    rebuild/redeploy even when bat exists
#   make install PKG=true   deploy target package manager (apt/pacman)
#   make install DRY=1      print what would run, change nothing
#   make install M=X        explicit source|release (overrides conf;
#                           also recorded)
#   make build|link         the individual scheme steps
#
# Exit codes: 2 env/precondition, 1 operational failure, 0 ok/no-op.

DOTS     := $(abspath $(CURDIR)/..)
SUB_DIR  := $(DOTS)/bat/.local/share/bat-src
LINK     := $(CURDIR)/.local/bin
ARTIFACT := $(LINK)/bat
SYSBIN   := $(HOME)/.local/bin
BIN      := $(SYSBIN)/bat
CONF     := $(HOME)/.config/doftiles.conf
REPO     := https://github.com/sharkdp/bat
ASSET_ARCH := x86_64-unknown-linux-gnu

FORCE ?=
DRY   ?=
PKG   ?=
M     ?=

# the knobs flow into sub-make calls (env), so nested rules see them
export FORCE DRY PKG M

.PHONY: toolchain build link install install-source install-release \
        conf-get conf-set stow-bat uninstall status start stop enable disable
.DEFAULT_GOAL := status

# ── conf (the BAT_METHOD record, through the stow symlink) ────────────
conf-get:
	@[ -f "$(CONF)" ] || { printf 'none'; exit 0; }; \
	. "$(CONF)" 2>/dev/null || true; \
	printf '%s' "$${BAT_METHOD:-}"

conf-set:
	@mkdir -p "$$(dirname "$(CONF)")"; \
	touch "$(CONF)"; \
	if grep -q '^BAT_METHOD=' "$(CONF)"; then \
		sed -i --follow-symlinks "s/^BAT_METHOD=.*/BAT_METHOD=$(value M)/" "$(CONF)"; \
	else \
		printf 'BAT_METHOD=%s\n' "$(value M)" >> "$(CONF)"; \
	fi

# ── toolchain (rustup; the fail-fasts are on-deploy's --check contract) ──
toolchain:
	@case "$(DRY)" in 1) echo "  [dry-run] on-deploy toolchain --rustup"; exit 0;; esac; \
	if [ ! -x "$(SYSBIN)/on-deploy" ]; then \
		echo "bat: $(SYSBIN)/on-deploy missing — run 'make bootstrap' first" >&2; exit 2; \
	fi; \
	$(SYSBIN)/on-deploy toolchain --rustup || { \
		echo "bat: rust toolchain missing (on-deploy toolchain --rustup failed)" >&2; exit 2; \
	}

# ── build: checkout ensure + cargo build (nothing placed) ────────────
build: toolchain
	@set -e; \
	if [ ! -f "$(SUB_DIR)/Cargo.toml" ]; then \
		echo "bat: submodule checkout missing — $(SUB_DIR)" >&2; \
		echo "  run 'make submodules' first" >&2; exit 2; \
	fi; \
	case "$(DRY)" in 1) echo "  [dry-run] git sync $(SUB_DIR) + cargo build --release --locked"; exit 0;; esac; \
	git -C "$(DOTS)" submodule sync -- bat/.local/share/bat-src; \
	git -C "$(DOTS)" submodule update --init --recursive -- bat/.local/share/bat-src; \
	git -C "$(SUB_DIR)" checkout -q -B main origin/main 2>/dev/null || \
		git -C "$(SUB_DIR)" checkout -q -B master origin/master; \
	git -C "$(SUB_DIR)" pull --ff-only; \
	(cd "$(SUB_DIR)" && cargo build --release --locked --quiet) || { \
		echo "bat: cargo build failed (toolchain? run 'on-deploy toolchain --rustup')" >&2; exit 1; \
	}; \
	[ -x "$(SUB_DIR)/target/release/bat" ] || { \
		echo "bat: cargo build produced no target/release/bat" >&2; exit 1; \
	}; \
	echo "bat: built ($(SUB_DIR)/target/release/bat)"

# ── link: the package owns the artifact; stow ships it ────────────────
link:
	@set -e; \
	case "$(DRY)" in 1) echo "  [dry-run] install $(SUB_DIR)/target/release/bat -> $(ARTIFACT)"; exit 0;; esac; \
	[ -x "$(SUB_DIR)/target/release/bat" ] || { \
		echo "bat: not built — make build first" >&2; exit 2; \
	}; \
	mkdir -p "$(LINK)"; \
	install -m 755 "$(SUB_DIR)/target/release/bat" "$(ARTIFACT)"; \
	echo "bat: linked $(ARTIFACT)"

stow-bat:
	@set -e; \
	if [ -e "$(BIN)" ] && [ ! -L "$(BIN)" ]; then \
		echo "bat: $(BIN) is a legacy regular file — swapping for the package link"; \
		rm -f "$(BIN)"; \
	fi; \
	cd "$(DOTS)" && stow -R -t "$(HOME)" bat

# ── source install: toolchain + build + link + stow ───────────────────
install-source:
	@set -e; \
	if [ "$(DRY)" = 1 ]; then echo "  [dry-run] make build + link + stow (source)"; exit 0; fi; \
	$(MAKE) -C "$(CURDIR)" --no-print-directory -f .local/state/depends/bat.Makefile build FORCE='$(FORCE)' DRY='$(DRY)'; \
	$(MAKE) -C "$(CURDIR)" --no-print-directory -f .local/state/depends/bat.Makefile link DRY='$(DRY)'; \
	case "$(DRY)" in 1) exit 0;; esac; \
	$(MAKE) -C "$(CURDIR)" --no-print-directory -f .local/state/depends/bat.Makefile stow-bat; \
	[ -x "$(BIN)" ] || { echo "bat: stow did not place $(BIN) (stow conflict? see the output above)" >&2; exit 1; }; \
	$(MAKE) -C "$(CURDIR)" --no-print-directory -f .local/state/depends/bat.Makefile conf-set M=source; \
	printf '  %-11s %s\n' bat "installed ($(BIN) (method=source; --force rebuilds))"

# ── release: prebuilt artifact from upstream GitHub releases ──────────
install-release:
	@set -e; \
	case "$(DRY)" in 1) echo "  [dry-run] fetch $(REPO)/releases/latest ($(ASSET_ARCH)) -> $(ARTIFACT)"; exit 0;; esac; \
	fetcher=""; \
	command -v curl >/dev/null 2>&1 && fetcher=curl; \
	[ -z "$$fetcher" ] && command -v wget >/dev/null 2>&1 && fetcher=wget; \
	if [ -z "$$fetcher" ]; then \
		echo "bat: neither curl nor wget found (arch: pacman -S curl / apt install curl)" >&2; exit 2; \
	fi; \
	api_url=https://api.github.com/repos/sharkdp/bat/releases/latest; \
	if [ "$$fetcher" = curl ]; then \
		tag=$$(curl -fsSL --retry 3 "$$api_url" | grep '"tag_name"' | head -n1 | sed 's/.*"tag_name": *"\([^"]*\)".*/\1/'); \
	else \
		tag=$$(wget -qO- "$$api_url" | grep '"tag_name"' | head -n1 | sed 's/.*"tag_name": *"\([^"]*\)".*/\1/'); \
	fi; \
	[ -n "$$tag" ] || { echo "bat: could not resolve the latest release tag" >&2; exit 1; }; \
	url=$(REPO)/releases/download/$$tag/bat-$$tag-$(ASSET_ARCH).tar.gz; \
	tmp=/tmp/opencode/bat-install.$$$$.tar.gz; \
	dir=/tmp/opencode/bat-install.$$$$; \
	echo "    fetch: $$url"; \
	if [ "$$fetcher" = curl ]; then \
		curl -fsSL --retry 3 --user-agent doftiles-deploy "$$url" -o "$$tmp"; \
	else \
		wget -qO "$$tmp" "$$url"; \
	fi; \
	mkdir -p "$$dir" "$(LINK)"; \
	tar -xzf "$$tmp" -C "$$dir" --strip-components=1; \
	install -m 755 "$$dir/bat" "$(ARTIFACT)"; \
	rm -rf "$$tmp" "$$dir"; \
	$(MAKE) -C "$(CURDIR)" --no-print-directory -f .local/state/depends/bat.Makefile stow-bat; \
	$(MAKE) -C "$(CURDIR)" --no-print-directory -f .local/state/depends/bat.Makefile conf-set M=release; \
	printf '  %-11s %s\n' bat "installed ($(BIN) (method=release; --force redeploys))"

# ── main rule: PKG/method resolution + ensure/force guard ─────────────
install:
	@set -e; \
	if [ "$(PKG)" = "true" ]; then \
		echo "bat: platform package manager (PKG=true)"; \
		if [ "$(DRY)" = 1 ]; then echo "  [dry-run] on-deploy pkg install bat"; exit 0; fi; \
		$(SYSBIN)/on-deploy pkg install bat; \
		printf '  %-11s %s\n' bat "installed via the platform package manager (the apt binary lands as batcat)"; \
		exit 0; \
	fi; \
	RECORDED="$$(make -C "$(CURDIR)" --no-print-directory -f .local/state/depends/bat.Makefile conf-get)"; \
	RESOLVED="$(M)"; \
	if [ -z "$$RESOLVED" ]; then RESOLVED="$$RECORDED"; fi; \
	if [ -z "$$RESOLVED" ]; then \
		if command -v cargo >/dev/null 2>&1; then RESOLVED=source; else RESOLVED=release; fi; \
	fi; \
	if [ ! -e "$(BIN)" ] || [ -n "$(FORCE)" ] || [ -n "$(M)" ]; then \
		if [ -e "$(BIN)" ] && [ -z "$(DRY)" ]; then \
			echo "bat: $(BIN) exists — redeploying (method=$$RESOLVED)"; \
		fi; \
		exec make -C "$(CURDIR)" --no-print-directory -f .local/state/depends/bat.Makefile "install-$$RESOLVED" \
			FORCE='$(FORCE)' DRY='$(DRY)'; \
	else \
		printf '  %-11s %s\n' bat "ok ($(BIN) deployed already (method=$$RECORDED) — skipping (--force redeploys))"; \
	fi

# ── uninstall: remove the artifact + links, reset the record ──────────
uninstall:
	@set -e; \
	RECORDED="$$(make -C "$(CURDIR)" --no-print-directory -f .local/state/depends/bat.Makefile conf-get)"; \
	case "$$RECORDED" in \
		none|'') echo "bat: nothing recorded in $(CONF) — nothing to uninstall"; exit 0;; \
	esac; \
	case "$(DRY)" in 1) echo "  [dry-run] remove the bat artifact + links per $$RECORDED"; exit 0;; esac; \
	rm -f "$(ARTIFACT)" "$(BIN)"; \
	make -C "$(CURDIR)" --no-print-directory -f .local/state/depends/bat.Makefile conf-set M=none; \
	echo "bat: uninstalled (was $$RECORDED); the submodule checkout is left in place"

# ── status: binary / method / checkout / toolchain report ─────────────
status:
	@st=MISSING; \
	if [ -x "$(BIN)" ]; then st=installed; fi; \
	printf '  %-11s %s\n' bat "$$st"; \
	printf '  %-11s %s\n' method "$$(make -C "$(CURDIR)" --no-print-directory -f .local/state/depends/bat.Makefile conf-get)"; \
	if [ -f "$(SUB_DIR)/Cargo.toml" ]; then cstate=present; else cstate=absent; fi; \
	printf '  %-11s %s\n' checkout "$$cstate"; \
	cst=MISSING; command -v cargo >/dev/null 2>&1 && cst="$$(command -v cargo)"; \
	printf '  %-11s %s\n' cargo "$$cst"; \
	rst=MISSING; command -v rustup >/dev/null 2>&1 && rst=installed; \
	printf '  %-11s %s\n' rustup "$$rst"

start stop enable disable:
	@echo "bat: nothing to $@ — the deployed artifacts are plain binaries"
