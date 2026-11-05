# dunst — package dependency Makefile (the dots/<pkg>/.local/share/<pkg>
# pattern). This package owns the notification daemon: its config
# (~/.config/dunst, stowed) and the stowed user unit (dunst.service).
# Deployable independently; the platform package-manager work defers
# to on-deploy pkg.

UNIT   := dunst.service
BIN    := dunst
ONDEPLOY ?= $(HOME)/.local/bin/on-deploy

install:
	@$(ONDEPLOY) pkg install $(BIN)
	@if [ ! -f $$HOME/.config/systemd/user/$(UNIT) ]; then \
		echo "dunst: WARNING user unit missing — stow the dunst package (units not restarted here)"; exit 0; fi
	@systemctl --user daemon-reload 2>/dev/null || true; \
	if ! systemctl --user enable --now $(UNIT) 2>/dev/null; then \
		echo "dunst: WARNING could not enable $(UNIT) (its Requires= chain — check-x-server? — is missing; stow the shell package)"; \
	else \
		echo "dunst: $(UNIT) enabled"; \
	fi

start:
	@systemctl --user start $(UNIT)

stop:
	@systemctl --user stop $(UNIT)

enable:
	@systemctl --user enable $(UNIT)

disable:
	@for d in $$HOME/.config/systemd/user/*.wants; do \
		[ -e "$$d/$(UNIT)" ] && rm -f "$$d/$(UNIT)"; \
	done; \
	echo "dunst: disabled (.wants symlink dropped)"

uninstall:
	@systemctl --user stop $(UNIT) 2>/dev/null; \
	for d in $$HOME/.config/systemd/user/*.wants; do \
		[ -e "$$d/$(UNIT)" ] && rm -f "$$d/$(UNIT)"; \
	done; \
	$(ONDEPLOY) pkg remove $(BIN) && echo "dunst: package removed (config stays stowed — unstow the dunst package for that)"

status:
	@$(ONDEPLOY) pkg installed $(BIN) || true
	@printf '  %-12s %s/%s\n' unit "$$(systemctl --user is-active $(UNIT) 2>/dev/null)" "$$(systemctl --user is-enabled $(UNIT) 2>/dev/null)"

.PHONY: install start stop enable disable uninstall status
