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

polyframes: polyframes-$(POLYFRAMES_SOURCE)

# --- bar control -------------------------------------------------------
reload:
	~/.local/bin/polyctl reload

up:
	~/.local/bin/polyctl up

down:
	~/.local/bin/polyctl down

.PHONY: polyframes polyframes-submodule polyframes-npm reload up down
