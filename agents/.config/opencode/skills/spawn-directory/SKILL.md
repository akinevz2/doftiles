---
name: spawn-directory
description: Spawns an interactive, urgent terminal window in a project directory via launch_alacritty for hands-on work (npm publish, debugging, manual edits).
---

# Spawn Directory

## Purpose

Open an interactive bash login shell in a project directory inside a
spawned alacritty window, without stealing focus from the chat. Use
this whenever the user needs to run interactive commands (e.g.
`npm publish`, manual debugging, authentication prompts) in a specific
directory while the agent session continues.

## Usage

    launch_alacritty --urgent --no-distract "cd <dir> && exec bash -l"

The command string **must end with `exec bash -l`** — without it, the
eval'd command exits immediately and the window closes with the
"press any key" prompt instead of staying open as an interactive
shell. This is the single most common mistake with this tool.

## Switches

- `--urgent` — raises the WM urgent hint (tag marker; the user can
  find the window among their tags).
- `--no-distract` — no focus steal on attach, default position (no
  centering). Omit it (or use `--floating`) when the window should
  come to the front centered.

## Spawn loop for several directories

Spawn windows for multiple modules in one backgrounded loop, waiting
for the WM rule machinery between spawns:

    for m in polyframes herbstutil herbctl; do
        launch_alacritty --urgent --no-distract \
            "cd ~/dots/$m/.local/share/$m && exec bash -l" &
    done; wait

## Gotchas

- The command runs via `eval` under an interactive bash; quote it as a
  single argument.
- A bare `cd <dir>` (no trailing shell) produces a window that closes
  on its own — always finish with `exec bash -l`.
- The tool spawns through `herbstclient spawn` (WM-managed, detached);
  nothing lingers after the user closes the shell.
