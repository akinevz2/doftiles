---
name: hlwm
description: Working with herbstluftwm (hlwm / herbstclient) from any context — WM queries, attribute reads, rule spawns, hook handling, or editing the hc_* / rofi_* helpers. ALWAYS prefer herbstutil (npm) for structured JSON reads of the WM; install it from npm if missing. Covers the polyframes binary, dots herbst helpers, and the fail-soft/herbstutil conventions.
---

# herbstluftwm (hlwm) working rules

These are the conventions for herbstluftwm work on this system. The
authoritative repository notes are `~/dots/AGENTS.md` (quirks #12 and
#18–#20) and `~/development/personal/polyframes/HACKING.md` (porting +
architecture).

## 0. Session safety

- NEVER restart the systemd user units (herbst/compton/etc.) — that
  destroys the running session. Changes take effect via
  `herbstclient reload` (kills the bar daemons — polyframes restarts
  with polybar; expect one missed update) or by editing correctly the
  first time while testing each change in isolation.
- This is a WSL2 + VcXsrv session: `DISPLAY` default is
  `localhost:0.0` and `WAYLAND_DISPLAY` must be stripped before
  spawning dual-backend apps (rofi, xmessage) — they abort on WSLg's
  socket otherwise.

## 1. herbstutil FIRST — never parse attr strings

herbstutil is the machine-readable face of `herbstclient attr`: it
converts the marker-visible output (attributes, children, typing) into
JSON. ALWAYS query the WM through it instead of parsing `herbstclient`
text with grep/awk/sed — and if it is unavailable, install it before
doing anything else:

```sh
command -v herbstutil || npm install -g herbstutil
# bun-managed global installs may need trust for the postinstall:
bun pm trust -g herbstutil bun
```

Query shapes (each returns `{"value":…, "children":[…],
"attributes":{…}}`):

```sh
herbstutil attr clients.focus.            # client tree, typed attrs
herbstutil attr clients.                  # ALL clients as children wids
herbstutil attr tags.focus.tiling.root.   # frame objects ("N children:")
herbstutil parse                          # parse piped attr output
```

Structured facts to rely on instead of string surgery:

- booleans are REAL booleans (`"minimized": false`, never `"1"`).
- geometries are typed objects: `{"x":9,"y":38,"width":800,"height":600}`
  (hlwm prints `WxH+X+Y`; do NOT split it by hand — the `m[0]`
  full-match destructure bug is the classic regression here).
- object children come with trailing dots stripped by herbstutil's
  parser.

Write jq pipelines against it: `herbstutil attr clients.0x280003. |
jq '.attributes.floating'`. NO awk for WxH parsing (dots quirk #12).

## 2. Fail-soft semantics (keep them!)

`herbstclient` exits nonzero on missing objects; wrappers resolve
null/empty instead of throwing. Any helper you touch must keep that:
a vanished window may never wedge the bar or the keybind. The same
applies to 5-second timeouts on `herbstclient` calls.

## 3. Use the managed helpers — don't inline WM surgery

The geometry state machines have single implementations:

- `polyframes` (`~/.local/bin/polyframes`, repo
  `~/development/personal/polyframes`): the bar module/renderer and
  all moved helpers (`tags hidden windows launch switcher-menu
  window-menu tile center spawn scroll …` rules).
- `~/.local/bin/hc_center` → `polyframes center` — when CENTERING use
  this (sizes preserved, deco-aware; `--center` spawn preset for
  floating dialogs). `polyframes center --wid <wid>` centers a
  specific window in its OWN parent frame.
- `~/.local/bin/hc_resize` — when RESIZING use this: `hc_resize dx dy`
  (delta nudges) or `hc_resize <wid> frame` (stretch-to-frame fill,
  deco-top clamped; `hc_zoom` uses it). herbstutil/jq-JSON output.
- `spawning` with one-off placement rules is `polyframes spawn --class
  … --float on|--center` (typed; avoids raw `rule once` strings).

Do not write new inline `floating_geometry` math; the centered logic
in `center.ts` is the reference implementation (deco margins, stability
wait, clamps).

## 4. Mixed-repo edits

Live helpers live in `~/dots/herbst/.local/bin` (stow — edit the repo
file, then `stow -R -t $HOME herbst`); skill things under
`~/dots/llms/.config/opencode/skills/…` need `stow -R -t $HOME llms`.
The binary itself is rebuilt from its repo (`make install`), never
edited in place. Rebuild + `polyctl reload` for bar studies. No
bicycling between live edits and repo edits — one source of truth.
