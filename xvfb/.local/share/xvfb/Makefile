# xvfb — package dependency Makefile (the dots/<pkg>/.local/share/<pkg>
# pattern). This package owns the virtual framebuffer: the stowed user
# unit (xvfb.service, Xvfb on :0) and the xvfb package (the Xvfb
# binary). It is the headless display provider the nested stack hangs
# off; deployable independently — x11vnc and novnc are their own
# packages that merely attach to what this provides.

UNIT   := xvfb.service
BIN    := xvfb
ONDEPLOY ?= $(HOME)/.local/bin/on-deploy

install:
	@$(ONDEPLOY) pkg install $(BIN)
	@if [ ! -f $$HOME/.config/systemd/user/$(UNIT) ]; then \
		echo "xvfb: user unit missing — stow the xvfb package"; exit 1; fi
	@systemctl --user daemon-reload; \
	systemctl --user enable --now $(UNIT) && echo "xvfb: $(UNIT) enabled (Xvfb :0)"

start:
	@systemctl --user start $(UNIT)

stop:
	@systemctl --user stop $(UNIT)

enable:
	@systemctl --user enable $(UNIT)

disable:
	@systemctl --user disable $(UNIT) 2>/dev/null || \
		echo "xvfb: disable was a no-op (linked unit: drop the .wants symlink by hand)"

uninstall:
	@systemctl --user disable --now $(UNIT) 2>/dev/null; \
	$(ONDEPLOY) pkg remove $(BIN) && echo "xvfb: package removed (config stays stowed — unstow the xvfb package for that)"

status:
	@$(ONDEPLOY) pkg installed $(BIN) || true
	@printf '  %-12s %s/%s\n' unit "$$(systemctl --user is-active $(UNIT) 2>/dev/null)" "$$(systemctl --user is-enabled $(UNIT) 2>/dev/null)"

.PHONY: install start stop enable disable uninstall status
