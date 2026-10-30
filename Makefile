# dots — make targets for shell configuration.
# `make bash` stows shell/ (symlinking .bashrcx into place) then runs the
# install/bashrc hook so the user's distributed ~/.bashrc is preserved
# rather than overwritten.
SHELL  := /bin/bash
STOW   := stow
MAKE   := make

SERVICES_FILE := service.order
WM_PACKAGES := wm.packages
WM_BINARIES := wm.requires

# Load configuration from external files
SERVICE_ORDER := $(shell grep -vi '^#' $(SERVICES_FILE))
WM_PACKAGES := $(shell grep -vi '^#' $(WM_PACKAGES))
WM_BINARIES := $(shell head -1 $(WM_BINARIES) | grep -vi '^#')

# (not named MAKEFILES — that variable is special to make: a sub-make
# inheriting it re-reads those files and every target ends up defined
# twice, spamming "overriding recipe" warnings)
MF_FILES := $(wildcard Makefile*)
ALL_TARGETS := $(foreach mf,$(MF_FILES),$(shell grep -hE '^[a-zA-Z_-]+:' $(mf) | sed 's/://'))
PHONY_LIST := $(sort $(ALL_TARGETS))

.PHONY: $(PHONY_LIST) system depends install sync update push

install: stow system 

deps: wm
	@if ! ls -al *.packages *.requires *.order; then \
		exit 1; \
	fi
	@$(MAKE) sync

# bash metapackage
bash: shell agents

# wm:
status: services-available services-installed

shell:
	$(STOW) -R -t $$HOME shell
	@chmod +x shell/.local/bin/install/bashrc
	~/.local/bin/install/bashrc

	~/.local/bin/load-credentials

agents:
	$(STOW) -R -t $$HOME agents


wm: herbstluftwm herbst_theme herbst_focus herbst_titles polybar depends

herbstluftwm: dunst

herbstluftwm:
	$(STOW) -R -t $$HOME herbstluftwm
	@herbstclient reload



dunst:
	$(STOW) -R -t $$HOME dunst

herbst_theme:
	$(STOW) -R -t $$HOME herbst_theme

herbst_focus:
	$(STOW) -R -t $$HOME herbst_focus

herbst_titles:
	$(STOW) -R -t $$HOME herbst_titles

polybar:
	$(STOW) -R -t $$HOME polybar

depends:
	$(STOW) -R -t $$HOME depends

stow-wm: status  
	@for pkg in $(WM_PACKAGES); do \
		echo "stowing $$pkg"; \
		$(STOW) -R -t $$HOME "$$pkg"; \
	done

stow: bash wm

# sync — perform update followed by push only if update succeeded.
sync: push

# update — safely pull the latest changes from origin. Prefers a fast-forward
# merge; falls back to a normal merge. If real conflicts occur, launch $EDITOR
# with each conflicting file. If the merge is blocked by local uncommitted
# changes, stage everything and launch $EDITOR with the files to be committed.
# update — delegated to depends (the dependency/deployment manager),
# which owns the safe pull (-ff, fallback --rebase --autostash) plus the
# submodule and per-method artifact refreshes.
update:
	@$(MAKE) --no-print-directory -C depends update

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

add-packages: shell
	@~/.local/bin/on.deploy 
	@missing=""; \
	for bin in $(WM_BINARIES); do \
		command -v "$$bin" >/dev/null 2>&1 || missing="$$missing $$bin"; \
	done; \
	if [ -n "$$missing" ]; then \
		echo "packages: missing required binaries:$$missing" >&2; \
		echo "packages: install the corresponding packages and re-run" >&2; \
		exit 1; \
	fi

add-packages-system: services-start
	@if [ -z "$(SYSTEM_PACKAGES)" ]; then \
		echo "packages: no system-* packages found; skipping"; \
		exit 0; \
	fi; \
	echo "packages: packages to be installed:"; \
	for pkg in $(SYSTEM_PACKAGES); do \
		echo "  $$pkg"; \
	done; \
	echo ""; \
	echo "Pending updates to /"; \
	for pkg in $(SYSTEM_PACKAGES); do \
		stow -n -v -R -t/ "$$pkg" 2>&1 | grep -E "^(UN)?LINK:" | awk -F' ' '{sub(/:/, "", $$1); print "/" $$2 " " $$1}'; \
		echo ""; \
	done; \
	read -p "Continue with system installation? [y/N] " confirm; \
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
	@for package in $(shell find . -name "*.service" | awk -F'[\\.]?/' '{print ($$1  != "" ? $$1 : $$2) "/" $$NF}'); do \
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

services-start: reload-systemd
	@echo ""
	@for service in $(SERVICE_ORDER); do \
		echo "preparing start for $$service"; \
	done
	@systemctl --user daemon-reload 2>/dev/null || \
		echo "services: systemctl --user daemon-reload failed (systemd not running?)" >&2
	@if [ -z "$(SERVICE_ORDER)" ]; then \
		echo ""; \
		echo -e "\033[31mERROR: Service order defined by $(SERVICES_FILE) file is empty.\033[0m"; \
		exit 1; \
	fi
	@echo -n "Continue with starting wm? [y/N] "
	@read -r line; \
	if [ "$$line" != "y" ] && [ "$$line" != "Y" ]; then \
		echo "services: cancelled"; \
		echo ""; \
		exit 0; \
	fi; \
	for service in $(SERVICE_ORDER); do \
		systemctl --user start "$$service" || systemctl --user status "$$service"; \
	done; \
	echo "services: started"

services-stop: reload-systemd
	@echo ""
	@for service in $(SERVICE_ORDER); do \
		echo "preparing stop for $$service"; \
	done
	@systemctl --user daemon-reload 2>/dev/null || \
		echo "services: systemctl --user daemon-reload failed (systemd not running?)" >&2
	@if [ -z "$(SERVICE_ORDER)" ]; then \
		echo ""; \
		echo -e "\033[31mERROR: Service order defined by $(SERVICES_FILE) file is empty.\033[0m"; \
		exit 1; \
	fi
	@echo -n "Continue with stopping wm? [y/N] "
	@read -r line; \
	if [ "$$line" != "y" ] && [ "$$line" != "Y" ]; then \
		echo "services: cancelled"; \
		echo ""; \
		exit 0; \
	fi; \
	for service in $(SERVICE_ORDER); do \
		systemctl --user stop "$$service" || systemctl --user status "$$service"; \
	done; \
	echo "services: stopped"

restart: reload-systemd
	@echo ""
	@for service in $(SERVICE_ORDER); do \
		echo "preparing restart for $$service"; \
	done
	@systemctl --user daemon-reload 2>/dev/null || \
		echo "services: systemctl --user daemon-reload failed (systemd not running?)" >&2
	@if [ -z "$(SERVICE_ORDER)" ]; then \
		echo ""; \
		echo -e "\033[31mERROR: Service order defined by $(SERVICES_FILE) file is empty.\033[0m"; \
		exit 1; \
	fi
	@echo -n "Continue with restarting wm? [y/N] "
	@read -r line; \
	if [ "$$line" != "y" ] && [ "$$line" != "Y" ]; then \
		echo "services: cancelled"; \
		echo ""; \
		exit 0; \
	fi; \
	for service in $(SERVICE_ORDER); do \
		systemctl --user restart "$$service" || systemctl --user status "$$service"; \
	done; \
	echo "services: restarted"


system: status add-packages-system add-packages
	@echo -e "system: \033[1;33mfresh\033[0m"