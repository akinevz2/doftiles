# Home directory Makefile for managing multiple git repositories
# Handles pull, push, and sync operations across dots and development repos

.PHONY: pull push sync status edit

# Make sure commands from subdirectories are found
PATH := $(PATH):./dots:./development

# Pull latest changes from all repositories
pull:
	@echo "Updating changes from dots repository..."
	@cd dots && $(MAKE) update || { echo "Error updating dots"; exit 1; }
	@echo "Pulling changes from development repository..."
	@cd development && $(MAKE) pull || { echo "Error pulling development"; exit 1; }
	@echo "Pull completed successfully"

# Show status of both repositories
status:
	@echo "=== Status of dots repository ==="
	@cd dots && git status --short
	@echo ""
	@echo "=== Status of development repository ==="
	@cd development && git status --short

# Push changes to all repositories
push:
	@echo "Pushing changes to dots repository..."
	@cd dots && $(MAKE) push || { echo "Error pushing dots"; exit 1; }
	@echo "Pushing changes to development repository..."
	@cd development && $(MAKE) push || { echo "Error pushing development"; exit 1; }
	@echo "Push completed successfully"

# Sync changes in both repositories (updates then uploads)
sync:
	@echo "Syncing dots repository..."
	@cd dots && $(MAKE) sync || { echo "Error syncing dots"; exit 1; }
	@echo "Syncing development repository..."
	@cd development && $(MAKE) sync || { echo "Error syncing development"; exit 1; }
	@echo "Sync completed successfully"

# Edit this Makefile
edit:
	${EDITOR} Makefile