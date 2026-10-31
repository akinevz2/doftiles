# dots — make targets for shell configuration.
# `make bash` stows shell/ (symlinking .bashrcx into place) then runs the
# install/bashrc hook so the user's distributed ~/.bashrc is preserved
# rather than overwritten.
SHELL  := /bin/bash
STOW   := stow
MAKE   := make
SCRIPT := $(CURDIR)/depends/.local/bin/install/deploy-menu

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
# post-stow hook (see depends/.local/bin/install/deploy-menu — hooks
# WM/X are guarded and no-op with a note on headless targets).
$(STOW_PKGS):
	$(STOW) -R -t $$HOME $@
	@mkdir -p $(STATE_DIR); \
	if ! grep -qxF "$@" $(STATE_FILE) 2>/dev/null; then \
		echo "$@" >> $(STATE_FILE); \
	fi
	@$(SCRIPT) --hook $@

# deploy — selective deployment: the deploy target apply, then a
#   whiptail checklist (plain menu fallback) of packages to stow.
#   P="a b" is the fine-grained non-interactive form.
#   The configuration (target, binaries, session, credentials) is the
#   configure wizard (`on-deploy configure`; also the bootstrap step).
deploy:
	@if [ -x "$(HOME)/.local/bin/on-deploy" ]; then \
		"$(HOME)/.local/bin/on-deploy" apply || \
			echo "deploy: apply FAILED" >&2; \
	else \
		echo "deploy: on-deploy missing — apply skipped (make bootstrap)"; \
	fi
	@for pkg in $$($(SCRIPT) "$(P)"); do \
		$(MAKE) --no-print-directory $$pkg; \
	done

# all — stow + hook every package (and remember them all)
all: $(WM_PACKAGES)

# restow — the remembered subset (the default goal of bare `make`);
# if nothing has ever been deployed, show the overview instead.
# restow — the default goal: synchronise the stowed set to the one
# specified in wm.packages — unstow everything stowed that is NOT in
# the active set, then stow exactly the needed set (and run each
# package's post-stow hook). The remembered state file ends up
# holding precisely the wm.packages set.
restow:
	@if [ -s $(STATE_FILE) ]; then \
		current=$$(sort -u $(STATE_FILE)); \
	else \
		current=; \
	fi; \
	for pkg in $$current; do \
		case " $(WM_PACKAGES) " in \
			*" $$pkg "*) ;; \
			*) echo "restow: unstow $$pkg"; \
				$(STOW) -D -t $$HOME "$$pkg" 2>/dev/null || true ;; \
		esac; \
	done; \
	: > $(STATE_FILE).tmp; \
	for pkg in $(WM_PACKAGES); do \
		echo "restow: stow $$pkg"; \
		$(STOW) -R -t $$HOME "$$pkg" || exit 1; \
		echo "$$pkg" >> $(STATE_FILE).tmp; \
		$(SCRIPT) --hook $$pkg; \
	done; \
	mv $(STATE_FILE).tmp $(STATE_FILE); \
	echo "restow: stowed set = $(WM_PACKAGES)"

# help — the overview (also what bare `make` shows before the first
# deployment). Favor descriptive entries over a strict column budget —
# long entries wrap onto continuation lines, packages print one per
# line (greppable, not folded across a wrap width).
help:
	@echo "doftiles — stow-based dotfiles (active set: wm.packages)"
	@echo ""
	@echo "Deployment:"
	@echo "  make              sync stowed set to wm.packages (default)"
	@echo "  make all          stow + hook the wm.packages set"
	@echo "  make install      all + each package's dependency Makefile"
	@echo "  make deploy       profile TUI + whiptail package picker"
	@echo "  make <package>    stow + remember + hook one package"
	@echo "  make bootstrap    fresh-system full deploy (config wizard,"
	@echo "                    binaries, stow, apply; services, credentials)"
	@echo "  make credentials  git name/email from ~/.my-credentials"
	@echo "  make submodules   init/update the dependency subrepos"
	@echo ""
	@echo "Services (YES=1 skips prompts):"
	@echo "  make services-start | services-stop | restart"
	@echo "  make services-check  daemon-reload + enable --now all"
	@echo "  make reload-systemd  daemon-reload only"
	@echo ""
	@echo "Inspection:"
	@echo "  make status       binaries / packages / services / git"
	@echo "  make deploy       deploy target apply (configure = the wizard)"
	@echo "  make session-link print the noVNC/RDP session URL"
	@echo "  make update       safe pull + submodule sync/refresh"
	@echo "  make push, sync   commit/push flow"
	@echo "  make clean        unstow everything; forget P=\"a b\""
	@echo ""
	@echo "Packages (active: $(WM_PACKAGES))"
	@for pkg in $(STOW_PKGS); do \
		case " $(WM_PACKAGES) " in \
			*" $$pkg "*) echo "  $$pkg" ;; \
			*) echo "  $$pkg (optional)" ;; \
		esac; \
	done

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
# user gets when calling `make bootstrap`, so they live inside
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
	@echo "bootstrap: on-deploy binary"
	@$(MAKE) --no-print-directory _bootstrap-on-deploy || \
		echo "bootstrap: on-deploy deploy FAILED — install bun, re-run make bootstrap" >&2
	@if [ -x "$(HOME)/.local/bin/on-deploy" ]; then \
		echo "bootstrap: toolchain assurances"; \
		"$(HOME)/.local/bin/on-deploy" toolchain || \
			echo "bootstrap: toolchain FAILED — re-run make bootstrap" >&2; \
	else \
		echo "bootstrap: on-deploy missing — toolchain skipped" >&2; \
	fi
	@if [ -t 0 ] && [ -x "$(HOME)/.local/bin/on-deploy" ]; then \
		echo "bootstrap: configuration wizard"; \
		if "$(HOME)/.local/bin/on-deploy" configure; then \
			wizard_done=1; \
		else \
			echo "bootstrap: wizard FAILED — falling back to defaults" >&2; \
		fi; \
	else \
		echo "bootstrap: non-interactive — wizard skipped (defaults)"; \
	fi; \
	if [ "$$wizard_done" != 1 ]; then \
		echo "bootstrap: stow all"; \
		$(MAKE) --no-print-directory stow; \
		echo "bootstrap: deps"; \
		if [ -x "$(HOME)/.local/bin/on-deploy" ]; then \
			"$(HOME)/.local/bin/on-deploy" deps || \
				echo "bootstrap: deps FAILED" >&2; \
		fi; \
		echo "bootstrap: apply"; \
		if [ -x "$(HOME)/.local/bin/on-deploy" ]; then \
			"$(HOME)/.local/bin/on-deploy" apply || \
				echo "bootstrap: apply FAILED" >&2; \
		fi; \
		echo "bootstrap: verify binaries"; \
		$(MAKE) --no-print-directory add-packages || \
			echo "bootstrap: missing packages listed above — install them and re-run when ready" >&2; \
	fi
	@$(MAKE) --no-print-directory services-check
	@$(MAKE) --no-print-directory status
	@$(MAKE) --no-print-directory credentials
	@echo "bootstrap: complete"
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

# install — stow every package, then run each package's dependency
# Makefile (dots/<pkg>/.local/share/<pkg>/Makefile) so binary
# dependencies get installed. Packages without that Makefile only get
# stowed. The dependency Makefiles DEFER to on-deploy for the actual
# binary management (the standard rule set there: install, start, stop,
# uninstall, status, disable, enable). Full one-call deployment
# (toolchain bootstrap + services + profile) stays in `make bootstrap`.
install: all
	@for pkg in $(WM_PACKAGES); do \
		mf="$(CURDIR)/$$pkg/.local/share/$$pkg/Makefile"; \
		if [ -f "$$mf" ]; then \
			echo "install: $$pkg deps"; \
			$(MAKE) --no-print-directory -C "$$pkg/.local/share/$$pkg" install || \
				echo "install: $$pkg deps FAILED" >&2; \
		fi; \
	done
	@$(MAKE) --no-print-directory status

# on-deploy binary variables — _bootstrap-on-deploy (above) builds it
# from the submodule checkout ONLY when missing (idempotent).
# `make add-packages` (the on.deploy walk), `make deploy` and the
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

# update — the safe pull (-ff, fallback --rebase --autostash; local
# changes ride along, conflicts stop for manual resolution — nothing
# is ever silently discarded), the submodules, then the polyframes
# artifact refresh per the recorded method (`on-deploy deps --force`
# rebuilds/installs and re-records the method).
update:
	@git fetch origin; \
	if git merge --ff-only origin/main 2>/dev/null; then \
		echo "update: fast-forwarded to origin/main"; \
	elif git pull --rebase --autostash origin main; then \
		echo "update: rebased onto origin/main"; \
	fi
	@git submodule update --init --recursive
	@if [ -x "$(HOME)/.local/bin/on-deploy" ]; then \
		"$(HOME)/.local/bin/on-deploy" deps --force || \
			echo "update: polyframes refresh FAILED — run 'on-deploy deps --force' after fixing" >&2; \
	else \
		echo "update: on-deploy missing — polyframes artifact not refreshed" >&2; \
	fi

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
# at 'make install' (which bootstraps on-deploy itself — 'make bootstrap'; plain 'make install' only stows and runs the package dependency Makefiles).
add-packages:
	@if [ -t 0 ]; then \
		if [ -x "$$HOME/.local/bin/on.deploy" ]; then \
			"$$HOME/.local/bin/on.deploy" || true; \
		else \
			echo "packages: on-deploy missing — walk skipped (make bootstrap)" >&2; \
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

# reload-systemd — daemon-reload ONLY (no enabling: services-stop and
# restart depend on this and must never start the services they are
# about to stop). The enable pass lives in services-check.
reload-systemd:
	@echo ""
	@systemctl --user daemon-reload 2>/dev/null || \
		echo "services: systemctl --user daemon-reload failed (systemd not running?)" >&2

# services-check — daemon-reload, then enable (and start) every unit in
# service.order. --no-block keeps this from idling when a unit cannot
# come up yet (e.g. headless: herbst polls 30s for X per attempt).
services-check: reload-systemd
	@if [ ! -f "$(SERVICES_FILE)" ]; then \
		echo ""; \
		echo -e "\033[31mERROR: $(SERVICES_FILE) file not found.\033[0m"; \
		exit 1; \
	fi
	@for service in $(SERVICE_ORDER); do \
		systemctl --user enable --now --no-block "$$service" 2>/dev/null \
			|| echo "services-check: failed to enable and start $$service"; \
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
		if [ "$(ACTION)" = "stop" ]; then \
			# disable AND stop. `systemctl disable` on a stow-linked unit \
			# removes the unit symlink itself (it undoes `systemctl link`), \
			# so disable by hand: drop the .wants symlinks only. \
			for d in "$$HOME"/.config/systemd/user/*.wants; do \
				[ -e "$$d/$$service" ] && rm -f "$$d/$$service"; \
			done; \
			# A unit stuck in activating (e.g. herbst's ExecStartPre \
			# polling for X) makes a plain stop wait for the pending \
			# start job — cancel pending start/restart jobs first, and \
			# stop --no-block so nothing waits. \
			for job in $$(systemctl --user list-jobs --no-legend 2>/dev/null | \
				grep -F " $$service" | grep -E " (start|restart) " | \
				cut -d" " -f1); do \
				systemctl --user cancel "$$job" 2>/dev/null; \
			done; \
			systemctl --user stop --no-block "$$service" 2>/dev/null; \
		else \
			# --no-block: never wait on a start job — a headless herbst \
			# polls 30s for X per attempt and would idle the whole make. \
			systemctl --user reset-failed "$$service" 2>/dev/null; \
			systemctl --user $(ACTION) --no-block "$$service" 2>/dev/null || \
				echo "services: $(ACTION) job submitted for $$service"; \
		fi; \
	done; \
	sleep 1; \
	echo "services: $(ACTION) submitted; current state:"; \
	for service in $(SERVICE_ORDER); do \
		printf '  %-24s %s\n' "$$service" "$$(systemctl --user is-active "$$service" 2>/dev/null)"; \
	done

system: status add-packages-system add-packages
	@echo -e "system: \033[1;33mfresh\033[0m"
