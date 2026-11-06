# bat — PACKAGE ADAPTER (the 2026-11 router-Makefile): one file per
# dots submodule package declaring what is genuinely bat-specific and
# owning only its concrete step recipes.
#
# on-deploy consumes the `metadata` contract below (one bare-value
# recipe per item, chained) and runs ALL routing/branching itself:
#   on-deploy managed bat install|uninstall|status|<metadata item>|...
# The make verbs stay the interface (the depends walk calls them).
#
# Method format: PACKAGE=source|pkg (doftiles.conf). The submodule:
# bat-src -> dots/bat/.local/share/bat-src.
# NOTE: install-release's curl||wget fetcher fallback is a single
# package-specific idiom, not router branching.

DOTS     := $(abspath $(CURDIR)/..)
SUB_DIR  := $(DOTS)/bat/.local/share/bat-src
RELEASE  := $(SUB_DIR)/.on-deploy-release
LINK     := $(CURDIR)/.local/bin
ARTIFACT := $(LINK)/bat
SYSBIN   := $(HOME)/.local/bin
REPO_URL := https://github.com/sharkdp/bat
ASSET_ARCH := x86_64-unknown-linux-gnu
ONDEPLOY := $(SYSBIN)/on-deploy

TOOLCHAIN_BINDIR := $(HOME)/.cargo/bin
export PATH := $(TOOLCHAIN_BINDIR):$(PATH)

FORCE ?=
DRY   ?=
M     ?=
export FORCE DRY M

.DEFAULT_GOAL := all
.PHONY: toolchain build sync checkout pull compile link \
        install-source install-release install uninstall status

# ── the deploy contract (one echo per key; on-deploy consults it) ──────
	@echo key=BAT
	@echo sub_dir=bat/.local/share/bat-src
	@echo artifact=bat/.local/bin/bat
	@echo install_name=bat
	@echo lang=rust
	@echo transports=apt,pacman
	@echo methods=source,release
	@echo source_default=source
	@echo fallback=release
	@echo src_target=install-source

# ── the default: build + link ("make; make install" cadence) ───────────
all: build link

# ── install/uninstall/status: deferrals (no branching here) ────────────
install:
	@$(ONDEPLOY) managed bat install --method=$(M) --force=$(FORCE) --dry-run=$(DRY)

status:
	@$(ONDEPLOY) managed bat status

uninstall:
	@rm -f "$(ARTIFACT)"

# ── the source route composed through steps (GNU make: deps chain) ─────
# ── the source route composed through steps (the toolchain includes
# ── itself: install-source brings the rust toolchain via on-deploy) ────
install-source: toolchain build link

build: sync checkout pull compile

sync:
	@git -C "$(DOTS)" submodule sync -- bat/.local/share/bat-src

checkout:
	@git -C "$(DOTS)" submodule update --init --recursive -- bat/.local/share/bat-src

pull:
	@git -C "$(SUB_DIR)" checkout -q -B main origin/main 2>/dev/null \
		|| git -C "$(SUB_DIR)" checkout -q -B master origin/master

compile:
	@cd "$(SUB_DIR)" && cargo build --release --locked --quiet

link:
	@mkdir -p "$(LINK)"
	@ln -f "$(SUB_DIR)/target/release/bat" "$(ARTIFACT)"
	@echo "bat: linked $(ARTIFACT)"

# ── toolchain (defer) ───────────────────────────────────────────────────
toolchain:
	@$(ONDEPLOY) toolchain --rustup

# ── the upstream release route (package-specific steps) ────────────────
install-release: release-tag release-fetch release-extract release-link

# one logical operation: resolve the tag (curl, else wget)
release-tag:
	@mkdir -p "$(RELEASE)"; \
	url="$(REPO_URL)/releases/latest"; \
	tag=$$(curl -fsSL --retry 3 "$$url" 2>/dev/null \
		| grep '"tag_name"' | head -n1 \
		| sed 's/.*"tag_name": *"\([^"]*\)".*/\1/' \
		|| wget -qO- --tries=3 "$$url" 2>/dev/null \
			| grep '"tag_name"' | head -n1 \
			| sed 's/.*"tag_name": *"\([^"]*\)".*/\1/'); \
	[ -n "$$tag" ] || { echo "bat: release tag UNRESOLVED (neither curl nor wget)" >&2; exit 2; }; \
	echo "bat: resolved release tag: $$tag"; \
	echo "$$tag" > "$(RELEASE)/tag"

# one logical operation: fetch the release asset (curl, else wget)
release-fetch:
	@tag=$$(cat "$(RELEASE)/tag"); \
	asset="bat-$$tag-$(ASSET_ARCH).tar.gz"; \
	curl -fSL --retry 3 -o "$(RELEASE)/bat.tar.gz" \
		"$(REPO_URL)/releases/download/$$tag/$$asset" 2>/dev/null \
		|| wget -qO "$(RELEASE)/bat.tar.gz" --tries=3 \
			"$(REPO_URL)/releases/download/$$tag/$$asset"; \
	echo "bat: fetched $$asset"

release-extract:
	@cd "$(RELEASE)" && rm -rf bat-v* && tar -xzf bat.tar.gz && rm -f bat.tar.gz

release-link:
	@ln -f "$(RELEASE)/bat-v*/bat" "$(ARTIFACT)"; \
	echo "bat: linked $(ARTIFACT)"

# ── the package metadata: one config item per recipe (value only!), ────
# ── chained; the ORDER is the contract (see lib/adapters.ts) ───────────
metadata: git_repo pkg_name methods_supported repos_pkg repos_pkg_name

git_repo:
	@echo https://github.com/sharkdp/bat

pkg_name:
	@echo bat-src

methods_supported:
	@echo source,pkg

repos_pkg:
	@echo apt

repos_pkg_name:
	@echo bat

