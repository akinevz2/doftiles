---
name: open-file
description: Instructs how to use $EDITOR for viewing files alongside chat. Uses $VIEW (code -r) for single files and $EDITOR $NEW_WINDOW (code --new-window) for directories.
---

# Open File

## Purpose

This skill documents the correct way to open files for inspection while chatting with opencode. Your environment has these variables configured:

- `$EDITOR=code` - Editor command; on its own it does NOT pause chat
- `$VIEW=code -r` - Opens file in replace tab (non-blocking view mode)  
- `$NEW_WINDOW=--new-window` - A FLAG for `$EDITOR`, not a standalone command

## Usage for Single Files

To view a single file without blocking the chat:

    # first check if $VIEW is set
    [ -z "$VIEW" ] && echo "view <file-path>" || $VIEW <file-path>
    # e.g. code -r src/index.js

This opens VS Code in "replace" mode on an existing tab or creates a new one if needed, but continues execution immediately. If the variable specifying user's editor is not set, just display the file-path to the user to ctrl-click or copy paste.

## Usage for Directories/Projects

`$NEW_WINDOW` is only a flag — it must always be COMBINED with `$EDITOR`, never invoked on its own:

    $EDITOR $NEW_WINDOW <directory-path>
    # e.g. code --new-window src/components/

This opens the folder in a new VS Code window and returns immediately (no `--wait` is configured in this environment).

## Gotcha

Do NOT run `$NEW_WINDOW <dir>` as a standalone command: the value is only the `--new-window` flag, so the shell would try to execute `--new-window` as a command and fail. Always pair it with `$EDITOR` — this is exactly what the `odot` alias does.
