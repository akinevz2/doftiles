# x11vnc — package dependency Makefile (the dots/<pkg>/.local/share/<pkg>
# pattern). This package owns the VNC server that exposes the X
# display: the stowed user unit (x11vnc.service, localhost:5900 — the
# framebuffer noVNC and the xrdp Xvnc module both attach to) and the
# x11vnc binary. Deployable independently; xvfb and novnc are their
# own packages.

UNIT   := x11vnc.service
BIN    := x11vnc
ONDEPLOY ?= $(HOME)/.local/bin/on-deploy

install:
	@$(ONDEPLOY) pkg install $(BIN)
	@if [ ! -f $$HOME/.config/systemd/user/$(UNIT) ]; then \
		echo "x11vnc: user unit missing — stow the x11vnc package"; exit 1; fi
	@systemctl --user daemon-reload; \
	systemctl --user enable --now $(UNIT) && echo "x11vnc: $(UNIT) enabled (:5900)"

start:
	@systemctl --user start $(UNIT)

stop:
	@systemctl --user stop $(UNIT)

enable:
	@systemctl --user enable $(UNIT)

disable:
	@systemctl --user disable $(UNIT) 2>/dev/null || \
		echo "x11vnc: disable was a no-op (linked unit: drop the .wants symlink by hand)"

uninstall:
	@systemctl --user disable --now $(UNIT) 2>/dev/null; \
	$(ONDEPLOY) pkg remove $(BIN) && echo "x11vnc: package removed (config stays stowed — unstow the x11vnc package for that)"

status:
	@$(ONDEPLOY) pkg installed $(BIN) || true
	@printf '  %-12s %s/%s\n' unit "$$(systemctl --user is-active $(UNIT) 2>/dev/null)" "$$(systemctl --user is-enabled $(UNIT) 2>/dev/null)"

.PHONY: install start stop enable disable uninstall status
