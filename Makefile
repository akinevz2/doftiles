# dots — make targets for shell configuration.
# `make bash` stows shell/ (symlinking .bashrcx into place) then runs the
# install/bashrc hook so the user's distributed ~/.bashrc is preserved
# rather than overwritten.
SHELL  := /bin/bash
STOW   := stow
MAKE   := make
SCRIPT := scripts/deploy-menu.sh

SERVICES_FILE := service.order
WM_PACKAGES := wm.packages
WM_BINARIES := wm.requires

# Load configuration from external files
SERVICE_ORDER := $(shell grep -vi '^#' $(SERVICES_FILE))
WM_PACKAGES := $(shell grep -vi '^#' $(WM_PACKAGES))
WM_BINARIES := $(shell head -1 $(WM_BINARIES) | grep -vi '^#')

# Every top-level directory with .config/.local content is a stow
# package; system-* packages stow to / instead (add-packages-system
# handles those), helper dirs (scripts/) are not packages at all.
STOW_PKGS := $(foreach d,$(filter-out system-%,$(patsubst %/,%,$(wildcard */))),$(if $(wildcard $(d)/.config $(d)/.local),$(d)))

# (not named MAKEFILES — that variable is special to make: a sub-make
# inheriting it re-reads those files and every target ends up defined
# twice, spamming "overriding recipe" warnings)
MF_FILES := $(wildcard Makefile*)
ALL_TARGETS := $(foreach mf,$(MF_FILES),$(shell grep -hE '^[a-zA-Z_-]+:' $(mf) | sed 's/://'))
PHONY_LIST := $(sort $(ALL_TARGETS))

.PHONY: $(PHONY_LIST) $(STOW_PKGS) system install sync update push

# --- remembered deployment state -----------------------------------------
# Bare `make` restows exactly the subset recorded in the state file
# (one package per line); every stow action records itself. The state
# is machine-local (XDG state dir) and deliberately NOT in the repo —
# the stowed set differs per machine (WSL host vs devcontainer).
STATE_DIR := $(HOME)/.local/state/doftiles
STATE_FILE := $(STATE_DIR)/stowed

.DEFAULT_GOAL := restow

# --- selective deployment ------------------------------------------------
# Any package target stows it, records it as remembered, and runs its
# post-stow hook (see scripts/deploy-menu.sh — hooks needing a running
# WM/X are guarded and no-op with a note on headless targets).
$(STOW_PKGS):
	$(STOW) -R -t $$HOME $@
	@mkdir -p $(STATE_DIR); \
	if ! grep -qxF "$@" $(STATE_FILE) 2>/dev/null; then \
		echo "$@" >> $(STATE_FILE); \
	fi
	@$(SCRIPT) --hook $@

# deploy — selective deployment, TUI-driven when interactive:
#   make deploy               profile TUI first, then a whiptail
#                             checklist (plain menu fallback)
#   make deploy P="a b"       fine-grained, no TUI, works non-interactive
#   make deploy PROFILE=skip  bypass the deploy.profile TUI
# The profile TUI (scripts/deploy-menu.sh --profile) selects and
# configures deploy.profile (session model, features, units, env),
# writes it, and runs provision (make provision) — guarded: skipped
# non-interactive without PROFILE=, and provision itself is skipped
# when on-deploy is not installed. Each package selection is then
# stowed, remembered, and hooked.
deploy:
	@if [ ! -t 0 ] || [ "$(PROFILE)" = "skip" ]; then \
		echo "deploy: profile TUI skipped"; \
	else \
		$(SCRIPT) --profile || exit 1; \
		if [ -x "$$HOME/.local/bin/on-deploy" ]; then \
			$(MAKE) --no-print-directory provision || \
				echo "deploy: provision FAILED — profile saved; run 'make provision' to retry" >&2; \
		else \
			echo "deploy: on-deploy not installed — provision skipped (run 'make install')"; \
		fi; \
	fi
	@for pkg in $$($(SCRIPT) "$(P)"); do \
		$(MAKE) --no-print-directory $$pkg; \
	done

# all — stow + hook every package (and remember them all)
all: $(STOW_PKGS)

# restow — the remembered subset (the default goal of bare `make`);
# if nothing has ever been deployed, show the overview instead.
restow:
	@if [ -s $(STATE_FILE) ]; then \
		for pkg in $$(sort -u $(STATE_FILE)); do \
			case " $(STOW_PKGS) " in \
				*" $$pkg "*) $(MAKE) --no-print-directory $$pkg ;; \
				*) echo "restow: skipping stale entry '$$pkg'" ;; \
			esac; \
		done; \
	else \
		$(MAKE) --no-print-directory help; \
	fi

# help — the overview (also what bare `make` shows before the first
# deployment). Favor descriptive entries over a strict column budget —
# long entries wrap onto continuation lines, packages print one per
# line (greppable, not folded across a wrap width).
help:
	@echo "doftiles — stow-based dotfiles"
	@echo ""
	@echo "Deployment:"
	@echo "  make            restow the remembered packages (the"
	@echo "                  recorded stowed set; the default goal)"
	@echo "  make all        stow + hook every package"
	@echo "  make deploy     selective deploy: an interactive run"
	@echo "                  first walks the deploy.profile TUI"
	@echo "                  (distro target, session model, features,"
	@echo "                  units, env) and runs provision BEFORE any"
	@echo "                  package is stowed; then a whiptail"
	@echo "                  checklist picks the packages."
	@echo "                  P=\"a b\" is the fine-grained non-interactive"
	@echo "                  form; PROFILE=skip bypasses the profile TUI"
	@echo "  make <package>  stow + remember + post-stow hook one pkg"
	@echo "  make bootstrap  full one-call deploy: ensures the toolchain"
	@echo "                  assurances (bun via npm if missing, bun"
	@echo "                  postinstall trust, the on-deploy + herbctl"
	@echo "                  binaries — formerly the bun-toolchain/"
	@echo "                  bun-trust/on-deploy-ensure/herbctl-ensure"
	@echo "                  recipes, now steps of on-deploy toolchain),"
	@echo "                  then stow everything, verify wm.requires,"
	@echo "                  enable services per service.order,"
	@echo "                  credentials last"
	@echo "  make credentials  git name/email setup (gated final step)"
	@echo "  make session-link  print the noVNC session URL"
	@echo "  make clean      unstow every package (system-* packages"
	@echo "                  and deployed binaries are NOT touched)"
	@echo "  make forget P=..  drop packages from the remembered set"
	@echo "                  (without unstowing them)"
	@echo ""
	@echo "Inspection:"
	@echo "  make status     packages / services / git state"
	@echo "  make provision  platform provisioning via on-deploy, per"
	@echo "                  deploy.profile (xserver, xinitrc, greeter,"
	@echo "                  nested stack, xrdp)"
	@echo "  make update     safe pull + submodule sync/refresh"
	@echo "  make push, sync   commit/push flow (see AGENTS.md)"
	@echo ""
	@echo "Services (YES=1 skips prompts; non-interactive requires it):"
	@echo "  make services-start | services-stop | restart"
	@echo "  make reload-systemd  daemon-reload, enable --now all"
	@echo ""
	@echo "Dependencies (install method state: doftiles.conf):"
	@echo "  make -C ~/.local/share/doftiles deploy-fromsource"
	@echo "  make -C ~/.local/share/doftiles deploy-fromnpm"
	@echo "  make -C ~/.local/share/doftiles uninstall"
	@echo ""
	@echo "Packages (one per line):"
	@for pkg in $(STOW_PKGS); do echo "  $$pkg"; done

# clean — undeploy every package from $HOME. System-* packages (stowed
# to /) and deployed binaries (e.g. ~/.local/bin/polyframes) are NOT
# touched; the remembered set is reset.
clean:
	@for pkg in $(STOW_PKGS); do \
		echo "clean: unstowing $$pkg"; \
		$(STOW) -D -t $$HOME "$$pkg" 2>/dev/null || true; \
	done
	@rm -f $(STATE_FILE)
	@echo "clean: all packages unstowed; system binaries untouched"

# status — binaries, packages, services, git state.
# provision — platform provisioning via on-deploy (deploy.profile):
# xserver packages, the xinitrc session line, the greeter (or the
# WSL verify-only bypass). See on-deploy's README for the contract.
# Runs from ~/dots — on-deploy's cwd contract.
provision:
	@cd $(CURDIR) && ~/.local/bin/on-deploy provision

status:
	@echo "== binaries (wm.requires) =="
	@for bin in $(WM_BINARIES); do \
		if command -v "$$bin" >/dev/null 2>&1; then st=installed; else st=MISSING; fi; \
		printf '  %-14s %s\n' "$$bin" "$$st"; \
	done
	@echo "== packages =="
	@for pkg in $(STOW_PKGS); do \
		if $(SCRIPT) --stowed "$$pkg" 2>/dev/null; then st=stowed; else st="not stowed"; fi; \
		printf '  %-14s %s\n' "$$pkg" "$$st"; \
	done
	@echo "== services (repo units) =="
	@for f in $$(find . -name '*.service' -not -path './.git/*' | sort); do \
		unit=$$(basename $$f .service); \
		act=$$(systemctl --user is-active "$$unit.service" 2>/dev/null); \
		[ -n "$$act" ] || act=unknown; \
		ena=$$(systemctl --user is-enabled "$$unit.service" 2>/dev/null); \
		[ -n "$$ena" ] || ena=unknown; \
		printf '  %-21s %-9s %s\n' "$$unit" "$$act" "$$ena"; \
	done
	@echo "== git =="
	@branch=$$(git branch --show-current); \
	up=$$(git rev-parse --abbrev-ref '@{u}' 2>/dev/null || echo none); \
	if [ "$$up" != "none" ]; then \
		ahead=$$(git rev-list --count '@{u}..HEAD'); \
		behind=$$(git rev-list --count 'HEAD..@{u}'); \
		printf '  %-14s %s <- %s (+%s -%s)\n' branch "$$branch" "$$up" "$$ahead" "$$behind"; \
	else \
		printf '  %-14s %s (no upstream)\n' branch "$$branch"; \
	fi; \
	dirty=$$(git status --short | wc -l); \
	if [ "$$dirty" -eq 0 ]; then \
		printf '  %-14s clean\n' worktree; \
	else \
		printf '  %-14s dirty (%s entries)\n' worktree "$$dirty"; \
		git status --short | head -20 | sed 's/^/  /'; \
	fi

# forget — drop P="pkg ..." from the remembered set (does not unstow)
forget:
	@if [ -z "$(P)" ]; then \
		echo "forget: usage: make forget P=\"pkg ...\"" >&2; \
		exit 1; \
	fi; \
	for pkg in $(P); do \
		if [ -f $(STATE_FILE) ] && grep -qxF "$$pkg" $(STATE_FILE); then \
			grep -vxF "$$pkg" $(STATE_FILE) > $(STATE_FILE).tmp || true; \
			mv $(STATE_FILE).tmp $(STATE_FILE); \
			echo "forget: $$pkg"; \
		fi; \
	done

# bootstrap — full deployment in ONE call, safe on a systemd target
# with no running window manager: stow everything (hooks no-op
# headless), verify required binaries, daemon-reload + enable --now
# the service stack (units needing X stay enabled-but-failed until X
# exists), deploy the depends artifact, then report status.
# submodules — ensure every dependency subrepo is initialized AND at
# its remote tip (--remote): the depends deployers build from these
# checkouts, so they must be fresh before anything stows or builds.
submodules:
	git submodule update --init --recursive --remote

# bun toolchain + trust + the *-ensure binaries USED to be four
# separate recipes (bun-toolchain, bun-trust, on-deploy-ensure,
# herbctl-ensure). They are not user choices — they are ASSURANCES the
# user gets when calling `make install`, so they live inside
# on-deploy (`on-deploy toolchain`) and the bootstrap just execs it.
#
# _bootstrap-on-deploy is the one exception that must stay here: it
# builds the on-deploy binary itself when missing (the toolchain
# command cannot run before its own binary exists), including the
# bun-through-npm fallback. Everything after that delegates to it.
_bootstrap-on-deploy:
	@if [ -x "$(ONDEPLOY_BIN)" ]; then \
		echo "on-deploy: $(ONDEPLOY_BIN) deployed already — skipping"; \
		exit 0; \
	fi; \
	if [ ! -f "$(ONDEPLOY_SUBMOD)/src/index.ts" ]; then \
		echo "on-deploy: submodule checkout missing — run 'make submodules' first" >&2; \
		exit 1; \
	fi; \
	if ! command -v bun >/dev/null 2>&1; then \
		if ! command -v npm >/dev/null 2>&1; then \
			echo "on-deploy: neither bun nor npm found — install node/npm first (arch: pacman -S npm)" >&2; \
			exit 1; \
		fi; \
		echo "on-deploy: bun missing — installing through npm"; \
		npm install --global bun; \
	fi; \
	cd "$(ONDEPLOY_SUBMOD)" && bun install; \
	cd "$(ONDEPLOY_SUBMOD)" && bun x bunli build --targets linux-x64 --minify; \
	mv -f "$(ONDEPLOY_SUBMOD)/dist/index" "$(ONDEPLOY_SUBMOD)/dist/on-deploy"; \
	rm -f "$(ONDEPLOY_SUBMOD)/dist/index.map"; \
	mkdir -p "$(HOME)/.local/bin"; \
	install -m 755 "$(ONDEPLOY_SUBMOD)/dist/on-deploy" "$(ONDEPLOY_BIN)"; \
	echo "on-deploy: installed $(ONDEPLOY_BIN)"

# credentials — install git user.name/user.email from ~/.my-credentials.
# MOVED here from the shell post-stow hook (deploy-menu.sh): mid-deploy
# it used to hard-error on machines that never created the file. It now
# runs as the LAST bootstrap step, and a missing file is a REMINDER, not
# a failure — the first run finishes cleanly and is shown how to finish:
# line 1 = full name (three words), line 2 = email.
CREDENTIALS_BIN := $(if $(wildcard $(HOME)/.local/bin/load-credentials),$(HOME)/.local/bin/load-credentials,$(CURDIR)/shell/.local/bin/load-credentials)

credentials:
	@if [ -f "$(HOME)/.my-credentials" ]; then \
		if "$(CREDENTIALS_BIN)"; then \
			echo "credentials: git user.name/user.email configured"; \
		else \
			echo "credentials: load-credentials FAILED — fix $(HOME)/.my-credentials and re-run 'make credentials'" >&2; \
		fi; \
	else \
		echo "credentials: reminder — $(HOME)/.my-credentials is not set up; git user.name/user.email were NOT installed"; \
		echo "  to finish git config, write your name/email for git, one per line (name, then email):"; \
		echo "    printf 'First Middle Last\nyou@example.com\n' > $(HOME)/.my-credentials"; \
		echo "  then re-run 'make credentials'"; \
	fi

bootstrap: submodules
	@echo "bootstrap: ensuring the on-deploy binary (the toolchain steps + package walk + provision exec it)"
	@$(MAKE) --no-print-directory _bootstrap-on-deploy || \
		echo "bootstrap: on-deploy deploy FAILED — the toolchain steps and the package walk will be skipped; install bun (arch: pacman -S bun) or node/npm, then re-run 'make install'" >&2
	@if [ -x "$(HOME)/.local/bin/on-deploy" ]; then \
		echo "bootstrap: toolchain assurances (bun, postinstall trust, herbctl)"; \
		"$(HOME)/.local/bin/on-deploy" toolchain || \
			echo "bootstrap: toolchain FAILED — bun trust / herbctl may be missing; re-run 'make install'" >&2; \
	else \
		echo "bootstrap: on-deploy missing — toolchain assurances skipped" >&2; \
	fi
	@echo "bootstrap: stowing every package"
	@$(MAKE) --no-print-directory stow
	@echo "bootstrap: ensuring polyframes artifact (palette/launchers/bar exec it directly)"
	@$(MAKE) --no-print-directory polyframes-ensure || \
		echo "bootstrap: polyframes deploy FAILED — launchers/bar will degrade; install bun (arch: pacman -S bun) or npm, then run 'make polyframes-ensure'" >&2
	@echo "bootstrap: verifying required binaries (continues on missing ones)"
	@$(MAKE) --no-print-directory add-packages || \
		echo "bootstrap: missing packages listed below — install them and re-run when ready" >&2
	@$(MAKE) --no-print-directory reload-systemd
	@$(MAKE) --no-print-directory status
	@$(MAKE) --no-print-directory credentials
	@echo "bootstrap: complete — units enabled; the WM stack comes up when X is available"
	@$(MAKE) --no-print-directory session-link

# session-link — the nested-profile browser surface: AFTER install,
# print the noVNC URL the user can press (terminals hyperlink plain
# URLs; clicking opens the browser AT the WM session instead of
# hunting for the port). Prints ONLY when novnc.service is actually
# running — the wsl-systemd primary profile stays quiet. The
# listener hails from the live stowed unit, so the URL is the bound
# truth; a 0.0.0.0/:: bind is rewritten to a browser-usable host.
session-link:
	@if [ -f "$$HOME/.config/systemd/user/novnc.service" ] && \
		systemctl --user is-active novnc.service >/dev/null 2>&1; then \
		listen=$$(grep -oE -- '--listen[[:space:]]+[[:graph:]]+' \
			"$$HOME/.config/systemd/user/novnc.service" | head -1); \
		listen=$${listen#* }; \
		case "$$listen" in \
			0.0.0.0:*|'::'*) listen="localhost:$${listen#*:}" ;; \
		esac; \
		echo ""; \
		echo "session-link: noVNC session is up — press to open the browser session:"; \
		echo "  http://$${listen:-localhost:6080}/vnc.html?autoconnect=1"; \
	fi; \
	if systemctl is-active xrdp >/dev/null 2>&1; then \
		rdpport=$$(grep -oE '^[[:space:]]*port[[:space:]]*=[[:space:]]*[0-9]+' \
			/etc/xrdp/xrdp.ini 2>/dev/null | head -1 | sed 's/.*=//'); \
		rdpport=$${rdpport:-3389}; \
		echo ""; \
		echo "session-link: RDP surface is up — connect to this host:$${rdpport}"; \
		echo "  (xrdp Xvnc module -> the shared x11vnc framebuffer, same session as noVNC)"; \
	fi

install: bootstrap

depends-deploy:
	@$(MAKE) --no-print-directory -C $(DEPLOY_MK) deploy

# polyframes-ensure — the bootstrap hook: deploy only when missing
# (idempotent). Delegated to the deployed depends Makefile so the same
# file powers repo-side fall-back runs and installed copies.
polyframes-ensure:
	@$(MAKE) --no-print-directory -C $(DEPLOY_MK) ensure

# on-deploy binary variables — _bootstrap-on-deploy (above) builds it
# from the submodule checkout ONLY when missing (idempotent).
# `make add-packages` (the on.deploy walk), `make provision` and the
# `on-deploy toolchain` assurances all exec ~/.local/bin/on-deploy.
ONDEPLOY_SUBMOD := $(CURDIR)/depends/.local/share/on-deploy
ONDEPLOY_BIN    := $(HOME)/.local/bin/on-deploy


# herbctl — built by `on-deploy toolchain` now (was the herbctl-ensure
# recipe): the WM keybind state machines (autostart's get-* binds exec
# ~/.local/bin/herbctl). The herbstluftwm post-stow hook calls
# `on-deploy toolchain`, so make all/wm/herbstluftwm all land it.

deps: wm
	@if ! ls -al *.packages *.requires *.order; then \
		exit 1; \
	fi
	@$(MAKE) sync

# bash metapackage
bash: shell agents

# wm — the stack from the manifest (wm.packages)
wm: $(WM_PACKAGES)

stow: wm

# help/clean/status follow below

# sync — perform update followed by push only if update succeeded.
sync: push

# update — delegated to depends (the dependency/deployment manager),
# which owns the safe pull (-ff, fallback --rebase --autostash) plus the
# submodule and per-method artifact refreshes.
# The deployment Makefile: deployed at ~/.local/share/doftiles (stow
# link into the repo), with the repo-side copy as fallback for fresh
# clones that have not stowed depends yet.
DEPLOY_MK := $(if $(wildcard $(HOME)/.local/share/doftiles/Makefile),$(HOME)/.local/share/doftiles,depends/.local/share/doftiles)

update:
	@$(MAKE) --no-print-directory -C $(DEPLOY_MK) update

# push — push commits if the worktree is clean; otherwise stage everything
# and launch $EDITOR with the current directory plus each modified file.
# If there are staged changes but nothing unstaged/untracked, commit them
# directly without opening an editor.
push: update
	@untracked=$$(git ls-files --others --exclude-standard); \
	git add -A; \
	if git diff --quiet && git diff --staged --quiet && [ -z "$$untracked" ]; then \
		if git rev-list --count '@{u}..HEAD' >/dev/null 2>&1 && \
			[ "$$(git rev-list --count '@{u}..HEAD')" -gt 0 ]; then \
			echo "push: pushing $(shell git branch --show-current)"; \
			git push; \
		else \
			echo "push: nothing to push"; \
		fi; \
		exit 0; \
	fi; \
	if git diff --quiet && [ -z "$$untracked" ] && ! git diff --staged --quiet; then \
		echo "push: commit staged changes"; \
		git commit && git push origin; \
		exit 0; \
	fi; \
	modified=$$(git diff --staged --name-only); \
	exec $$EDITOR "$$PWD" $$modified

# packages:
SYSTEM_PACKAGES := $(shell ls -d system-* 2>/dev/null)

# add-packages — verify required binaries; the on-deploy walk (which
# prompts per missing binary) runs only on an interactive terminal,
# and only when the binary exists — otherwise the caller is pointed
# at 'make install' (which bootstraps on-deploy itself).
add-packages:
	@if [ -t 0 ]; then \
		if [ -x "$$HOME/.local/bin/on.deploy" ]; then \
			"$$HOME/.local/bin/on.deploy" || true; \
		else \
			echo "packages: on-deploy not deployed — the interactive package walk was skipped (run 'make install')" >&2; \
		fi; \
	fi
	@missing=""; \
	for bin in $(WM_BINARIES); do \
		command -v "$$bin" >/dev/null 2>&1 || missing="$$missing $$bin"; \
	done; \
	if [ -n "$$missing" ]; then \
		echo "packages: missing required binaries:$$missing" >&2; \
		echo "packages: install the corresponding packages and re-run" >&2; \
		exit 1; \
	fi

# add-packages-system — stow system-* packages to /. Interactive only
# (sudo needs a terminal); YES=1 bypasses the confirmation.
add-packages-system:
	@if [ -z "$(SYSTEM_PACKAGES)" ]; then \
		echo "packages: no system-* packages found; skipping"; \
		exit 0; \
	fi; \
	if [ ! -t 0 ] && [ -z "$$YES" ]; then \
		echo "packages: non-interactive — system packages skipped (sudo needs a terminal)"; \
		exit 0; \
	fi; \
	echo "packages: packages to be installed:"; \
	for pkg in $(SYSTEM_PACKAGES); do \
		echo "  $$pkg"; \
	done; \
	echo ""; \
	echo "Pending updates to /"; \
	for pkg in $(SYSTEM_PACKAGES); do \
		stow -n -v -R -t/ "$$pkg" 2>&1 | grep -E "^(UN)?LINK:" | sed 's/^\(UN\{0,1\}\)LINK: \([^ ]*\) .*/\/\2 \1LINK/'; \
		echo ""; \
	done; \
	if [ -n "$$YES" ]; then \
		confirm=y; \
	else \
		read -r -p "Continue with system installation? [y/N] " confirm; \
	fi; \
	if echo "$$confirm" | grep -iq "^y"; then \
		sudo stow -R -t / $(SYSTEM_PACKAGES); \
		echo "packages: stow completed"; \
	else \
		echo "packages: cancelled"; \
		exit 0; \
	fi

services-available:
	@echo ""
	@echo "Available service files: "
	@for package in $(shell find . -name "*.service" | cut -sd/ -f2-); do \
		echo -n "$$package: "; \
		systemctl --user is-active "$$(basename $$package)" --no-pager | sed 's/^\(active\)/\x1b[32m\1\x1b[0m/'; \
	done

services-installed:
	@echo ""
	@missing=""
	@echo "Installed services: "; \
	for service in $(SERVICE_ORDER); do \
		systemctl --user is-active "$$service" >/dev/null && (systemctl --user status "$$service" --no-pager | head -n1 | sed 's/^\(.*\) -/\x1b[32m\1\x1b[0m:/' ) || missing="$$missing $$service"; \
	done; \
	if [ -n "$$missing" ]; then \
		echo ""; \
		echo -e "Missing services:\033[33m$$missing\033[0m"; \
	fi

reload-systemd:
	@echo ""
	@systemctl --user daemon-reload 2>/dev/null || \
		echo "services: systemctl --user daemon-reload failed (systemd not running?)" >&2
	@if [ ! -f "$(SERVICES_FILE)" ]; then \
		echo ""; \
		echo -e "\033[31mERROR: $(SERVICES_FILE) file not found.\033[0m"; \
		exit 1; \
	fi
	@for service in $(SERVICE_ORDER); do \
		systemctl --user enable --now "$$service" || echo "services-check: failed to enable and start $$service"; \
	done && echo "Enabled services: $(SERVICE_ORDER)"

# services-start / services-stop / restart — confirm on an interactive
# terminal; non-interactive runs require YES=1 (nothing ever hangs on
# stdin).
services-start: reload-systemd
	@$(MAKE) --no-print-directory service-action ACTION=start VERB=starting

services-stop: reload-systemd
	@$(MAKE) --no-print-directory service-action ACTION=stop VERB=stopping

restart: reload-systemd
	@$(MAKE) --no-print-directory service-action ACTION=restart VERB=restarting

# service-action — the shared start/stop/restart body (one shell, so
# the confirmation read and the unit loop stay together).
service-action:
	@echo ""
	@for service in $(SERVICE_ORDER); do \
		echo "preparing $(VERB) for $$service"; \
	done
	@systemctl --user daemon-reload 2>/dev/null || \
		echo "services: systemctl --user daemon-reload failed (systemd not running?)" >&2
	@if [ -z "$(SERVICE_ORDER)" ]; then \
		echo ""; \
		echo -e "\033[31mERROR: Service order defined by $(SERVICES_FILE) file is empty.\033[0m"; \
		exit 1; \
	fi
	@if [ -n "$$YES" ]; then \
		line=y; \
	elif [ -t 0 ]; then \
		read -r -p "Continue with $(VERB) wm? [y/N] " line; \
	else \
		echo "services: non-interactive without YES=1 — aborting" >&2; \
		exit 1; \
	fi; \
	if [ "$$line" != "y" ] && [ "$$line" != "Y" ]; then \
		echo "services: cancelled"; \
		echo ""; \
		exit 0; \
	fi; \
	for service in $(SERVICE_ORDER); do \
		systemctl --user $(ACTION) "$$service" || systemctl --user status "$$service"; \
	done; \
	echo "services: $(ACTION) complete"

system: status add-packages-system add-packages
	@echo -e "system: \033[1;33mfresh\033[0m"
