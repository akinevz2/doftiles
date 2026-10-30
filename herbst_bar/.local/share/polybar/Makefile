# polybar deployment orchestration (herbst_bar).
#
# Owns: running polyctl, and deploying polyframes — either from
# SOURCE (a git submodule of this repo, checked out here) or from
# NPM. Both recipes end at the same invariant:
#   ~/.local/bin/polyframes exists and [module/polyframes] execs it.
#
# The default source is the submodule; switch with
#   make polyframes POLYFRAMES_SOURCE=npm

POLYFRAMES_DIR ?= $(HOME)/.local/share/polyframes
POLYFRAMES_REPO ?= https://github.com/akinevz2/polyframes
POLYFRAMES_SOURCE ?= submodule

# --- polyframes: from source (git submodule) ---------------------------
polyframes-submodule:
	@test -d $(POLYFRAMES_DIR)/.git || \
	    git clone --recurse-submodules $(POLYFRAMES_REPO) $(POLYFRAMES_DIR)
	git -C $(POLYFRAMES_DIR) pull --ff-only
	cd $(POLYFRAMES_DIR) && git submodule update --init --remote
	cd $(POLYFRAMES_DIR) && bun install
	cd $(POLYFRAMES_DIR) && make install

# --- polyframes: from npm ----------------------------------------------
# Requires the package to be published; pre-publish, the git URL
# installs the source tree (the bin entry runs through bun).
polyframes-npm:
	npm install -g polyframes

# --- theme --------------------------------------------------------------
# The hlwm theme lives in herbst_theme (doftiles); applying it is part
# of both install and reload.

theme:
	$(HOME)/.local/bin/reload_theme -f

# --- polyframes: the binary deploy (both sources end here) -------------
install: polyframes-$(POLYFRAMES_SOURCE) theme-binary
theme-binary:
	install -m 755 $(HOME)/.local/share/polyframes/dist/polyframes \
	    $(HOME)/.local/bin/polyframes

# "make reload" = the theme + the bar restart (a full refresh).
reload: theme
	~/.local/bin/polyctl reload

# --- bar control -------------------------------------------------------
up:
	~/.local/bin/polyctl up

down:
	~/.local/bin/polyctl down

.PHONY: polyframes polyframes-submodule polyframes-npm theme install reload up down
