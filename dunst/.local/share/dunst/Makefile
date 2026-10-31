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
		echo "dunst: user unit missing — stow the dunst package"; exit 1; fi
	@systemctl --user daemon-reload; \
	systemctl --user enable --now $(UNIT) && echo "dunst: $(UNIT) enabled"

start:
	@systemctl --user start $(UNIT)

stop:
	@systemctl --user stop $(UNIT)

enable:
	@systemctl --user enable $(UNIT)

disable:
	@systemctl --user disable $(UNIT) 2>/dev/null || \
		echo "dunst: disable was a no-op (linked unit: drop the .wants symlink by hand)"

uninstall:
	@systemctl --user disable --now $(UNIT) 2>/dev/null; \
	$(ONDEPLOY) pkg remove $(BIN) && echo "dunst: package removed (config stays stowed — unstow the dunst package for that)"

status:
	@$(ONDEPLOY) pkg installed $(BIN) || true
	@printf '  %-12s %s/%s\n' unit "$$(systemctl --user is-active $(UNIT) 2>/dev/null)" "$$(systemctl --user is-enabled $(UNIT) 2>/dev/null)"

.PHONY: install start stop enable disable uninstall status
