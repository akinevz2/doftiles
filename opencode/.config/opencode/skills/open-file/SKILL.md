---
name: open-file
description: Instructs how to use $EDITOR for viewing files alongside chat. Uses $VIEW (code -r) for single files and $NEW_WINDOW ($VIEW --new-window or similar) for directories.
---

# Open File

## Purpose

This skill documents the correct way to open files for inspection while chatting with opencode. Your environment has these variables configured:

- `$EDITOR=code --wait` - Pauses chat while file is open (default edit mode)
- `$VIEW=code -r` - Opens file in replace tab (non-blocking view mode)  
- `$NEW_WINDOW=code --wait --new-window` - Opens directory or project in new window

## Usage for Single Files

To view a single file without blocking the chat:

    # first check if $VIEW is set
    [ -z "$VIEW" ] && echo "view <file-path>" || $VIEW <file-path>
    # e.g. code -r src/index.js

This opens VS Code in "replace" mode on an existing tab or creates a new one if needed, but continues execution immediately. If the variable specifying user's editor is not set, just display the file-path to the user to ctrl-click or copy paste.

## Usage for Directories/Projects

To inspect a directory (opens in new window):

    $NEW_WINDOW <directory-path>
    # e.g. code --wait --new-window src/components/

This opens the folder in a new VS Code instance and waits until closed before continuing.
