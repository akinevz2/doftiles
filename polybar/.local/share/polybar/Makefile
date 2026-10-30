# polybar deployment orchestration.
#
# Owns: running polyctl, and the theme apply. The polyframes deploy
# recipes (deploy-fromsource / deploy-fromnpm / update / uninstall)
# live in the depends package — run them as
#   make -C ~/dots/depends deploy-fromsource
# this Makefile keeps thin aliases so bar-side workflows keep working.

POLYFRAMES_DEPS := $(HOME)/dots/depends

theme:
	$(HOME)/.local/bin/reload_theme -f

install: theme
	$(MAKE) --no-print-directory -C $(POLYFRAMES_DEPS) deploy-fromsource

deploy-fromnpm:
	$(MAKE) --no-print-directory -C $(POLYFRAMES_DEPS) deploy-fromnpm

# "make reload" = the theme + the bar restart (a full refresh).
reload: theme
	~/.local/bin/polyctl reload

up:
	~/.local/bin/polyctl up

down:
	~/.local/bin/polyctl down

.PHONY: theme install deploy-fromnpm reload up down
