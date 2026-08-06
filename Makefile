# dots — make targets for shell configuration.
# `make bash` stows shell/ (symlinking .bashrcx into place) then runs the
# install/bashrc hook so the user's distributed ~/.bashrc is preserved
# rather than overwritten.
SHELL  := /bin/bash
STOW   := stow

.PHONY: bash git install

install: bash

bash: git
	@$(STOW) -R -t $$HOME shell
	@chmod +x shell/.local/bin/install/bashrc
	~/.local/bin/install/bashrc

git:
	@$(STOW) -R -t $$HOME git
	@chmod +x git/.local/bin/load-credentials
	~/.local/bin/load-credentials
