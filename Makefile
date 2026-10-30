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
#   make deploy               whiptail checklist (plain menu fallback)
#   make deploy P="a b"       fine-grained, no TUI, works non-interactive
# Each selection is stowed, remembered, and hooked.
deploy:
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
# deployment).
help:
	@echo "doftiles — stow-based dotfiles deployment"
	@echo ""
	@echo "Deployment:"
	@echo "  make              restow the remembered subset (help if never deployed)"
	@echo "  make all          stow + hook every package"
	@echo "  make deploy       selective: whiptail TUI (interactive) or P=\"a b\""
	@echo "  make <package>    stow + hook one package (e.g. make polybar)"
	@echo "  make bootstrap    full single-call deployment (headless-safe)"
	@echo "  make clean        unstow every package (system binaries untouched)"
	@echo "  make uninstall    full undeploy: disable units + unstow + clear state"
	@echo "  make restore-defaults  stow the snapshotted pre-dots config back"
	@echo "  make forget P=... drop packages from the remembered set"
	@echo ""
	@echo "Inspection:"
	@echo "  make status       binaries, packages, services, git state"
	@echo "  make provision    platform services for the picked profile"
	@echo "                    (PROFILE=<wsl|nested|xinit|greetd> overrides)"
	@echo "  make update       safe pull (-ff / --rebase) + submodule/npm refresh"
	@echo "  make push, sync   commit/push flow (see AGENTS.md)"
	@echo ""
	@echo "Services (order from service.order; YES=1 bypasses prompts):"
	@echo "  make services-start | services-stop | restart"
	@echo "  make reload-systemd  daemon-reload + enable --now"
	@echo ""
	@echo "Dependencies (depends package; state in ~/.config/doftiles.conf):"
	@echo "  make -C ~/.local/share/doftiles deploy-fromsource | deploy-fromnpm"
	@echo "  make -C ~/.local/share/doftiles uninstall"
	@echo ""
	@echo "Packages: $(STOW_PKGS)"

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
		printf '  %-24s %s\n' "$$bin" "$$st"; \
	done
	@echo "== packages =="
	@for pkg in $(STOW_PKGS); do \
		if $(SCRIPT) --stowed "$$pkg" 2>/dev/null; then st=stowed; else st="not stowed"; fi; \
		printf '  %-24s %s\n' "$$pkg" "$$st"; \
	done
	@echo "== services (available in the repo) =="
	@for f in $$(find . -name '*.service' -not -path './.git/*' | sort); do \
		unit=$$(basename $$f); \
		act=$$(systemctl --user is-active $$unit 2>/dev/null); \
		[ -n "$$act" ] || act=unknown; \
		ena=$$(systemctl --user is-enabled $$unit 2>/dev/null); \
		[ -n "$$ena" ] || ena=unknown; \
		printf '  %-24s %-10s %s\n' "$$unit" "$$act" "$$ena"; \
	done
	@echo "== git =="
	@branch=$$(git branch --show-current); \
	up=$$(git rev-parse --abbrev-ref '@{u}' 2>/dev/null || echo none); \
	if [ "$$up" != "none" ]; then \
		ahead=$$(git rev-list --count '@{u}..HEAD'); \
		behind=$$(git rev-list --count 'HEAD..@{u}'); \
		echo "  branch $$branch (ahead $$ahead, behind $$behind of $$up)"; \
	else \
		echo "  branch $$branch (no upstream)"; \
	fi; \
	dirty=$$(git status --short | wc -l); \
	if [ "$$dirty" -eq 0 ]; then \
		echo "  worktree clean"; \
	else \
		echo "  worktree dirty ($$dirty entries):"; \
		git status --short | head -10 | sed 's/^/    /'; \
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

# profile — the deployment profile selection. Prompted on interactive
# install (whiptail radiolist, plain menu fallback); overridable with
# PROFILE=<name>; persisted to ~/.local/state/doftiles/profile so
# repeat runs and profile switches remember the choice.
PROFILES := wsl nested xinit greetd
PROFILE_STATE := $(STATE_DIR)/profile

profile-pick:
	@if [ -n "$(PROFILE)" ]; then \
		CHOICE="$(PROFILE)"; echo "profile: $$CHOICE (explicit)"; \
	elif [ -t 0 ] && [ -t 1 ] && command -v whiptail >/dev/null 2>&1; then \
		CHOICE=$$(whiptail --title "doftiles — deployment profile" \
			--radiolist "How does the graphical session start?" \
			0 70 0 \
			wsl    "WSL2: hlwm as the systemd user unit; Windows VcXsrv is the X server" ON \
			nested "Nested: hlwm inside Xvfb :1, browser access via noVNC :6081 (co-installable)" OFF \
			xinit  "Native: startx ~/.xinitrc execs herbstluftwm, no display manager" OFF \
			greetd "Greeter: greetd + tuigreet own the console" OFF \
			3>&1 1>&2 2>&3) && [ -n "$$CHOICE" ] \
			&& echo "profile: $$CHOICE (picked)" \
			|| echo "profile: whiptail unavailable — falling back"; \
		case " $(PROFILES) " in *" $$CHOICE "*) ;; *) CHOICE="";; esac; \
	fi; \
	if [ -z "$$CHOICE" ] && [ -t 0 ]; then \
		echo "profiles: $(PROFILES)"; \
		read -r -p "profile [wsl]: " CHOICE || true; \
		CHOICE=$${CHOICE:-wsl}; \
		echo "profile: $$CHOICE (typed)"; \
	fi; \
	if [ -z "$$CHOICE" ]; then \
		CHOICE=$$(cat $(PROFILE_STATE) 2>/dev/null || true); \
		case " $(PROFILES) " in *" $$CHOICE "*) ;; *) CHOICE=wsl ;; esac; \
		echo "profile: $$CHOICE (remembered)"; \
	fi; \
	mkdir -p $(STATE_DIR); \
	echo "$$CHOICE" > $(PROFILE_STATE)

# provision — platform provisioning for the PICKED profile: passes
# profiles/<name>.profile to on-deploy (cwd contract: runs from ~/dots).
# Headless shells get --yes (confirm prompts would block forever); the
# sudo password still requires a real terminal, so run profile installs
# interactively when packages must be installed.
provision: profile-pick
	@prof=$$(cat $(PROFILE_STATE)); \
	echo "provision: profiles/$$prof.profile"; \
	if [ -t 0 ]; then \
		~/.local/bin/on-deploy provision --profile profiles/$$prof.profile; \
	else \
		~/.local/bin/on-deploy provision --yes --profile profiles/$$prof.profile; \
	fi

# profile-snapshot — the bootstrap guard: collect the machine's
# pre-existing user config into defaults/ BEFORE stow overwrites it
# (on-deploy snapshot; idempotent — already-dots files are skipped, so
# repeat installs are no-ops). Never fatal: a snapshot failure must not
# block deployment.
profile-snapshot:
	@~/.local/bin/on-deploy snapshot || \
		echo "bootstrap: snapshot FAILED (continuing — existing configs may be overwritten; re-run 'on-deploy snapshot')" >&2

# uninstall — maximum undeploy: disable + stop every user unit the
# repo ships, unstow every package, clear the remembered state.
# Installed PACKAGES (binaries, artifacts) are deliberately untouched,
# as are files outside the stow universe.
UNINSTALL_UNITS := herbst herbst-nested xvfb xvfb-nested x11vnc x11vnc-nested novnc novnc-nested compton dunst hc_send-error-daemon

uninstall:
	@echo "uninstall: disabling user units: $(UNINSTALL_UNITS)"; \
	for u in $(UNINSTALL_UNITS); do \
		systemctl --user disable --now "$$u.service" 2>/dev/null || true; \
	done; \
	systemctl --user daemon-reload 2>/dev/null || true; \
	echo "uninstall: unstowing every package"; \
	for pkg in $(STOW_PKGS); do \
		$(STOW) -D -t $$HOME "$$pkg" 2>/dev/null && echo "  unstowed $$pkg" || true; \
	done; \
	rm -f $(STATE_FILE) $(PROFILE_STATE); \
	echo "uninstall: dots fully undeployed (binaries/packages untouched; restore with 'make install')"

# restore-defaults — put a snapshotted machine's original config back:
# stow the defaults package (its links replace the dots links 1:1).
restore-defaults:
	@if [ ! -d defaults ]; then \
		echo "restore-defaults: no defaults/ package (run 'on-deploy snapshot' on the machine first)"; \
		exit 1; \
	fi; \
	$(STOW) -R -t $$HOME defaults && echo "restore-defaults: defaults stowed (the machine's pre-dots config is back)"

bootstrap: submodules stow profile-snapshot
	@echo "bootstrap: ensuring polyframes artifact (palette/launchers/bar exec it directly)"
	@$(MAKE) --no-print-directory polyframes-ensure || \
		echo "bootstrap: polyframes deploy FAILED — launchers/bar will degrade; install bun (arch: pacman -S bun) or npm, then run 'make polyframes-ensure'" >&2
	@echo "bootstrap: verifying required binaries (continues on missing ones)"
	@$(MAKE) --no-print-directory add-packages || \
		echo "bootstrap: missing packages listed below — install them and re-run when ready" >&2
	@$(MAKE) --no-print-directory provision
	@$(MAKE) --no-print-directory reload-systemd
	@$(MAKE) --no-print-directory status
	@echo "bootstrap: complete — units enabled; the WM stack comes up when X is available"

install: bootstrap

depends-deploy:
	@$(MAKE) --no-print-directory -C $(DEPLOY_MK) deploy

# polyframes-ensure — the bootstrap hook: deploy only when missing
# (idempotent). Delegated to the deployed depends Makefile so the same
# file powers repo-side fall-back runs and installed copies.
polyframes-ensure:
	@$(MAKE) --no-print-directory -C $(DEPLOY_MK) ensure

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
# prompts per missing binary) runs only on an interactive terminal.
add-packages:
	@if [ -t 0 ]; then ~/.local/bin/on.deploy || true; fi
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
