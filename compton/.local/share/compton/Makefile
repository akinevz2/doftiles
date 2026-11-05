# compton — package dependency Makefile (the dots/<pkg>/.local/share/<pkg>
# pattern). This package owns the compositor: its stowed user unit
# (compton.service, BindsTo the WM session) and the compton binary.
# Deployable independently of the WM; the platform package-manager
# work defers to on-deploy pkg.

UNIT   := compton.service
BIN    := compton
ONDEPLOY ?= $(HOME)/.local/bin/on-deploy

install:
	@$(ONDEPLOY) pkg install $(BIN)
	@if [ ! -f $$HOME/.config/systemd/user/$(UNIT) ]; then \
		echo "compton: WARNING user unit missing — stow the compton package (units not restarted here)"; exit 0; fi
	@systemctl --user daemon-reload 2>/dev/null || true; \
	if ! systemctl --user enable --now $(UNIT) 2>/dev/null; then \
		echo "compton: WARNING could not enable $(UNIT) (its Requires= chain — check-x-server? — is missing; stow the shell package)"; \
	else \
		echo "compton: $(UNIT) enabled"; \
	fi

# the compositor rides the WM session (BindsTo herbst in the unit):
# a plain restart of the WM session restarts it with the unit's own
# lifecycle — no special start/stop semantics
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
	echo "compton: disabled (.wants symlink dropped)"

uninstall:
	@systemctl --user stop $(UNIT) 2>/dev/null; \
	for d in $$HOME/.config/systemd/user/*.wants; do \
		[ -e "$$d/$(UNIT)" ] && rm -f "$$d/$(UNIT)"; \
	done; \
	$(ONDEPLOY) pkg remove $(BIN) && echo "compton: package removed (config stays stowed — unstow the compton package for that)"

status:
	@$(ONDEPLOY) pkg installed $(BIN) || true
	@printf '  %-12s %s/%s\n' unit "$$(systemctl --user is-active $(UNIT) 2>/dev/null)" "$$(systemctl --user is-enabled $(UNIT) 2>/dev/null)"

.PHONY: install start stop enable disable uninstall status
