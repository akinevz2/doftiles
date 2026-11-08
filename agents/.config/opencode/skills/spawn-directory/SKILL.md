---
name: spawn-directory
description: Spawns an interactive, urgent terminal window in a project directory via launch_alacritty for hands-on work (npm publish, debugging, manual edits).
---

# Skill: spawn-directory

## Purpose

Open an interactive bash login shell in a project directory inside a
spawned alacritty window, without stealing focus from the chat. Use
this whenever the user needs to run interactive commands (e.g.
`npm publish`, manual debugging, authentication prompts) in a specific
directory while the agent session continues.

## Usage

    launch_alacritty -d <dir>

or with a command string:

    launch_alacritty --urgent --no-distract -d <dir> "<command>"

The `cd` is part of the tool's interface: `-d <dir>` (a leading ~ is
expanded) cds into the directory first. With no command string, the
default command is an interactive login shell (`bash -il`) in that
directory — it stays open until the user exits, then the wrapper's
park phase ("press any key to close") runs.

## NEVER write `exec bash -l` in the command string

launch_alacritty wraps the command as `bash -ic "paused-for-dismiss_idle
<cmd>"`. `exec bash -l` replaces the wrapper with a NON-interactive
login bash — it runs ~/.bash_profile and exits, and the terminal closes
with it immediately (no park, no key press). That pattern was for plain
`-e bash -c` spawns; it is wrong for this wrapper. If you want a shell
in the directory, just omit the command string.

## Spawn loop for several directories

Spawn windows for multiple modules in one backgrounded loop, waiting
for the WM rule machinery between spawns:

    for m in polyframes herbstutil herbctl; do
        launch_alacritty --urgent --no-distract -d ~/dots/$m/.local/share/$m &
    done; wait

## Gotchas

- The command runs via `eval` under an interactive bash; quote it as a
  single argument.
- `-d <dir>` is verified to exist before spawning; the path is
  %q-quoted so it survives spaces.
- A command string that exits immediately (like a lone `exec bash -l`)
  closes the window after the park phase — the wrapper parks for one
  key press ("press any key to close"), then exits.
- The tool spawns through `herbstclient spawn` (WM-managed, detached);
  nothing lingers after the user closes the shell.

Base directory for this skill: /home/kine/.config/opencode/skills/spawn-directory
Relative paths in the skill (e.g. scripts/, reference/) are relative to this base
directory.
