# dots — make targets for shell configuration.
# `make bash` stows shell/ (symlinking .bashrcx into place) then runs the
# install/bashrc hook so the user's distributed ~/.bashrc is preserved
# rather than overwritten.
SHELL  := /bin/bash
STOW   := stow

.PHONY: bash git install services wm update upload sync

install: bash opencode


bash: git
	@$(STOW) -R -t $$HOME shell
	@chmod +x shell/.local/bin/install/bashrc
	~/.local/bin/install/bashrc

git:
	@$(STOW) -R -t $$HOME git
	@chmod +x git/.local/bin/load-credentials
	~/.local/bin/load-credentials

opencode:
	@$(STOW) -R -t $$HOME opencode

# services — stow the systemd user units (herbst, compton). After editing
# anything under services/, restow and run `systemctl --user daemon-reload`.
services:
	@$(STOW) -R -t $$HOME services
	@systemctl --user daemon-reload 2>/dev/null || \
		echo "services: systemctl --user daemon-reload failed (systemd not running?)" >&2

# update — safely pull the latest changes from origin. If merge errors occur,
# launch $EDITOR with the current directory plus each conflicting file.
update:
	@git fetch origin
	@git merge --no-edit origin/main 2>/dev/null && exit 0
	@conflicts=$$(git ls-files -u | cut -f2 | sort -u); \
		exec $$EDITOR "$$PWD" $$conflicts

# upload — push commits only if the directory is clean. Otherwise, stage
# everything and launch $EDITR with the current directory plus each modified file.
upload:
	@if git diff --quiet && git diff --staged --quiet; then \
		echo "upload: nothing to push"; \
		exit 0; \
	fi
	@git add -A
	@modified=$$(git diff --name-only); \
		$$EDITOR "$$PWD" $$modified

# sync — perform update followed by upload only if update succeeded.
sync: update
	@$(MAKE) upload

# wm — install the window-manager stack (herbstluftwm session, status bar,
# launcher, compositor, notifications, terminal, systemd user units).
# Fails early if any required system binary is missing.
WM_PACKAGES := herbst services polybar rofi compton dunst alacritty
WM_BINARIES := herbstluftwm herbstclient compton polybar rofi hsetroot xset dunst

wm: services
	@missing=""; \
	for bin in $(WM_BINARIES); do \
		command -v "$$bin" >/dev/null 2>&1 || missing="$$missing $$bin"; \
	done; \
	if [ -n "$$missing" ]; then \
		echo "wm: missing required binaries:$$missing" >&2; \
		echo "wm: install the corresponding packages and re-run" >&2; \
		exit 1; \
	fi; \
	for pkg in $(WM_PACKAGES); do \
		echo "stowing $$pkg"; \
		$(STOW) -R -t $$HOME "$$pkg"; \
	done
	@systemctl --user daemon-reload 2>/dev/null || \
		echo "wm: systemctl --user daemon-reload failed (systemd not running?)" >&2