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

MAKEFILES := $(wildcard Makefile*)
ALL_TARGETS := $(foreach mf,$(MAKEFILES),$(shell grep -hE '^[a-zA-Z_-]+:' $(mf) | sed 's/://'))
PHONY_LIST := $(sort $(ALL_TARGETS))

.PHONY: $(PHONY_LIST) system depends install status

install: status system 

status: sync services-status

depends: bash wm
	@$(STOW) -R -t $$HOME depends
	@if ! ls -al *.packages *.requires *.order; then \
		exit 1; \
	fi

# bash metapackage
bash: shell git opencode task

shell:
	@$(STOW) -R -t $$HOME shell
	@chmod +x shell/.local/bin/install/bashrc
	~/.local/bin/install/bashrc

git:
	@$(STOW) -R -t $$HOME git
	@chmod +x git/.local/bin/load-credentials
	~/.local/bin/load-credentials

opencode:
	@$(STOW) -R -t $$HOME opencode

task:
	@$(STOW) -R -t $$HOME task

wm: herbstluftwm alacritty dunst compton

herbstluftwm:
	@$(STOW) -R -t $$HOME herbst
	@herbstclient reload

alacritty:
	@$(STOW) -R -t $$HOME alacritty

compton:
	@$(STOW) -R -t $$HOME compton

dunst:
	@$(STOW) -R -t $$HOME dunst

# sync — perform update followed by upload only if update succeeded.
sync: update upload

# update — safely pull the latest changes from origin. Prefers a fast-forward
# merge; falls back to a normal merge. If real conflicts occur, launch $EDITOR
# with each conflicting file. If the merge is blocked by local uncommitted
# changes, stage everything and launch $EDITOR with the files to be committed.
# NOTE: the whole recipe is one shell (backslash continuations) so that
# `exit` actually stops the target.
update:
	@git fetch origin; \
	if git merge --ff-only origin/main 2>/dev/null; then \
		echo "update: fast-forwarded to origin/main"; \
	elif git merge --no-edit origin/main 2>/dev/null; then \
		echo "update: merged origin/main"; \
	else \
		conflicts=$$(git ls-files -u | cut -f2 | sort -u); \
		if [ -n "$$conflicts" ]; then \
			exec $$EDITOR "$$PWD" $$conflicts; \
		fi; \
		echo "update: merge blocked by local changes; staging for commit" >&2; \
		git add -A; \
		modified=$$(git diff --staged --name-only); \
		exec $$EDITOR "$$PWD" $$modified; \
	fi

# upload — push commits if the worktree is clean; otherwise stage everything
# and launch $EDITOR with the current directory plus each modified file.
# If there are staged changes but nothing unstaged/untracked, commit them
# directly without opening an editor.
upload:
	@untracked=$$(git ls-files --others --exclude-standard); \
	if git diff --quiet && git diff --staged --quiet && [ -z "$$untracked" ]; then \
		if git rev-list --count '@{u}..HEAD' >/dev/null 2>&1 && \
			[ "$$(git rev-list --count '@{u}..HEAD')" -gt 0 ]; then \
			echo "upload: pushing $(shell git branch --show-current)"; \
			git push; \
		else \
			echo "upload: nothing to push"; \
		fi; \
		exit 0; \
	fi; \
	if git diff --quiet && [ -z "$$untracked" ] && ! git diff --staged --quiet; then \
		echo "upload: committing staged changes"; \
		git commit --no-edit && git push; \
		exit 0; \
	fi; \
	git add -A; \
	modified=$$(git diff --staged --name-only); \
	exec $$EDITOR "$$PWD" $$modified

# wm:
services-status: services-available services-installed
 
# packages:
SYSTEM_PACKAGES := $(shell ls -d system-* 2>/dev/null)

wm-packages: shell
	@~/.local/bin/on.deploy wm
	@missing=""; \
	for bin in $(WM_BINARIES); do \
		command -v "$$bin" >/dev/null 2>&1 || missing="$$missing $$bin"; \
	done; \
	if [ -n "$$missing" ]; then \
		echo "packages: missing required binaries:$$missing" >&2; \
		echo "packages: install the corresponding packages and re-run" >&2; \
		exit 1; \
	fi

system-packages: wm-packages restart-services
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

check-services: services-available
	@echo ""
	@$(STOW) -R -t $$HOME services
	@systemctl --user daemon-reload 2>/dev/null || \
		echo "services: systemctl --user daemon-reload failed (systemd not running?)" >&2
	@if [ ! -f "$(SERVICES_FILE)" ]; then \
		echo ""; \
		echo -e "\033[31mERROR: $(SERVICES_FILE) file not found.\033[0m"; \
		exit 1; \
	fi
	@for service in $(SERVICE_ORDER); do \
		systemctl --user enable --now "$$service" || echo "check-services: failed to enable and start $$service"; \
	done && echo "Enabled services: $(SERVICE_ORDER)"

restart-services: services-status
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


deploy-services: check-services  
	@for pkg in $(WM_PACKAGES); do \
		echo "stowing $$pkg"; \
		$(STOW) -R -t $$HOME "$$pkg"; \
	done

system: system-packages deploy-services depends 
	@echo -e "system: \033[1;33mfresh\033[0m"