# novnc — package dependency Makefile (the dots/<pkg>/.local/share/<pkg>
# pattern). This package owns the browser VNC surface: the stowed user
# unit (novnc.service, :6080 -> the x11vnc framebuffer on :5900) and
# the novnc package. There is no single binary on PATH — presence is
# checked via the shipped proxy script. Deployable independently;
# x11vnc (its backend) is its own package.

UNIT      := novnc.service
BIN       := novnc
PROXY     := /usr/share/novnc/utils/novnc_proxy
ONDEPLOY  ?= $(HOME)/.local/bin/on-deploy

install:
	@$(ONDEPLOY) pkg install $(BIN)
	@if [ ! -f $$HOME/.config/systemd/user/$(UNIT) ]; then \
		echo "novnc: user unit missing — stow the novnc package"; exit 1; fi
	@systemctl --user daemon-reload; \
	systemctl --user enable --now $(UNIT) && echo "novnc: $(UNIT) enabled (:6080)"

start:
	@systemctl --user start $(UNIT)

stop:
	@systemctl --user stop $(UNIT)

enable:
	@systemctl --user enable $(UNIT)

disable:
	@systemctl --user disable $(UNIT) 2>/dev/null || \
		echo "novnc: disable was a no-op (linked unit: drop the .wants symlink by hand)"

uninstall:
	@systemctl --user disable --now $(UNIT) 2>/dev/null; \
	$(ONDEPLOY) pkg remove $(BIN) && echo "novnc: package removed (config stays stowed — unstow the novnc package for that)"

status:
	@$(ONDEPLOY) pkg installed $(BIN) || true
	@if [ -f $(PROXY) ]; then echo "  proxy        present"; else echo "  proxy        MISSING"; fi
	@printf '  %-12s %s/%s\n' unit "$$(systemctl --user is-active $(UNIT) 2>/dev/null)" "$$(systemctl --user is-enabled $(UNIT) 2>/dev/null)"

.PHONY: install start stop enable disable uninstall status
