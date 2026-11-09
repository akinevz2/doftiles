# xrdp — package dependency Makefile (the dots/<pkg>/.local/share/<pkg>
# pattern). This package owns the RDP layer ONLY: the static user-level
# config (~/.config/xrdp/xrdp.ini, stowed — nothing edits /etc) and the
# stowed USER service unit (~/.config/systemd/user/xrdp.service, port
# 3390; the Xvnc module attaches to the shared x11vnc framebuffer on
# :5900). It does NOT own x11vnc/xvfb/novnc (the nested stack lives in
# the herbstluftwm package) — only the attach point.
#
# If a SYSTEM xrdp is running it would clash on the ports: reported,
# never touched.

UNIT   := xrdp.service
ONDEPLOY ?= $(HOME)/.local/bin/on-deploy

install:
	@$(ONDEPLOY) pkg install xrdp
	@if [ ! -f $$HOME/.config/xrdp/xrdp.ini ]; then \
		echo "xrdp: ~/.config/xrdp/xrdp.ini missing — stow the xrdp package"; exit 1; fi
	@if [ ! -f $$HOME/.config/systemd/user/$(UNIT) ]; then \
		echo "xrdp: user unit missing — stow the xrdp package"; exit 1; fi
	@if systemctl is-active xrdp >/dev/null 2>&1; then \
		echo "xrdp: WARNING — a SYSTEM xrdp is active (port clash); disable it to use the user service"; \
	fi
	@systemctl --user daemon-reload; \
	systemctl --user enable --now $(UNIT) && \
	echo "xrdp: user service up on :3390 (log: ~/.local/state/xrdp.log)"

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
	echo "xrdp: disabled (.wants symlink dropped)"

uninstall:
	@systemctl --user stop $(UNIT) 2>/dev/null; \
	for d in $$HOME/.config/systemd/user/*.wants; do \
		[ -e "$$d/$(UNIT)" ] && rm -f "$$d/$(UNIT)"; \
	done; \
	$(ONDEPLOY) pkg remove xrdp && echo "xrdp: package removed (config stays stowed — unstow the xrdp package for that)"

status:
	@if [ -f "$$HOME/.config/xrdp/xrdp.ini" ]; then st=stowed; else st=MISSING; fi; \
	printf '  %-12s %s\n' xrdp.ini "$$st"
	@printf '  %-12s %s\n' unit "$$(systemctl --user is-active $(UNIT) 2>/dev/null)/$$(systemctl --user is-enabled $(UNIT) 2>/dev/null)"

.PHONY: install start stop enable disable uninstall status
