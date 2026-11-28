---
name: spawn-directory
description: Spawns an interactive, urgent terminal window in a project directory via launch_alacritty for hands-on work (npm publish, debugging, manual edits).
---

# Skill: spawn-directory

## Purpose

Open an interactive bash login shell in a project directory inside a
spawned alacritty window, WITH the user's focus bound to it
immediately. Use this whenever the user needs to run interactive
commands (e.g. `npm publish`, manual debugging, authentication
prompts, sudo grants) in a specific directory while the agent session
continues.

## Usage

    launch_alacritty -d <dir>

or with a command string — URGENT + BIND is the canonical shape: the
window carries the urgent hint AND `--bind` chains it with an
`hc bring` the moment it attaches, so the user's focus lands in the
terminal immediately (no hunting for the window, no relying on the
notification):

    launch_alacritty --urgent --bind -d <dir> "<command>"

Deferred-work sessions the user will visit LATER (npm version bumps,
batch publishes on a named workspace) are the exception — those stay
in the background on their tagspace:

    launch_alacritty --urgent --no-distract -t npm -d <dir>

`-t` creates the tagspace when missing (`herbctl add tagspace` — no
focus switch) and lands the window in the background there; the
urgent tag marker surfaces it. Sessions opened this way appear in
`hc_save-context`'s snapshot (`~/.cache/herbstluftwm/context.tsv`)
with their owning tag.

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
for the WM rule machinery between spawns. Bind focus on the LAST one
only (the one the user acts on first); earlier windows stay urgent:

    for m in polyframes herbstutil; do
        launch_alacritty --urgent --no-distract -d ~/dots/$m/.local/share/$m &
    done
    launch_alacritty --urgent --bind -d ~/dots/herbctl/.local/share/herbctl
    wait

## Gotchas

- The command runs via `eval` under an interactive bash; quote it as a
  single argument.
- `-d <dir>` is verified to exist before spawning; the path is
  %q-quoted so it survives spaces.
- `--bind` deliberately OVERRIDES the focus=off that `--urgent` arms:
  the window still floats with the urgent marker, but the post-attach
  watcher `herbstclient bring`s it (focus + raise + move to the viewed
  tag). The same machinery lives in the verb as
  `herbctl terminal --urgent --bind` — prefer launch_alacritty from
  skills (it adds the directory verification and the park contract).
- A command string that exits immediately (like a lone `exec bash -l`)
  closes the window after the park phase — the wrapper parks for one
  key press ("press any key to close"), then exits.
- The tool spawns through `herbstclient spawn` (WM-managed, detached);
  nothing lingers after the user closes the shell.

Base directory for this skill: /home/kine/.config/opencode/skills/spawn-directory
Relative paths in the skill (e.g. scripts/, reference/) are relative to this base
directory.
