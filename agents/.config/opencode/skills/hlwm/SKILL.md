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

### Listing objects: herbstutil children, not guesswork

hlwm 0.9.5 has **no `list_tags`** — that command does not exist
(`Command "list_tags" not found`). `list_clients`, `list_monitors`,
`list_keybinds` and `list_commands` DO exist, but emit human-format
text. For structured data prefer herbstutil over ALL list_* commands:
determine the object family you need (tags, clients, monitors,
settings), read its parent object, and walk children:

```sh
herbstutil attr tags.      | jq -r '.children | keys[]'          # tag indexes
herbstclient attr tags.1.name                                    # then read names
herbstutil attr clients.   | jq -r '.children | keys[]'          # winids
herbstutil attr monitors.  | jq -r '.children | keys[]'          # monitors
herbstutil attr settings.  | jq -r '.children | keys[]'          # settings
```

Rule of thumb: if a `list_*` command exists AND plain text suffices
(e.g. `list_commands` to discover command names), it is fine; the moment
you need to filter, join, or test values, switch to herbstutil's typed
JSON. Never guess a `list_tags`-style command into existence — enumerate
the object tree instead.

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
`~/dots/agents/.config/opencode/skills/…` need `stow -R -t $HOME agents`.
The binary itself is rebuilt from its repo (`make install`), never
edited in place. Rebuild + `polyctl reload` for bar studies. No
bicycling between live edits and repo edits — one source of truth.

## 5. Screencast: the performance travels WITH the camera

When orchestrating a screencast, the audience must never be left behind:

- **NEVER change tags with a bare `use <tag>` during a screencast.** The
  narration window (and the orchestrator's own TUI window) stay on the old
  tag, and the user cannot issue further commands without manually toggling
  tags back and forth.
- **ALWAYS use the screencast plugin's `stage` tool** (`stage {tag}`, creates
  the tag if missing): it moves the backstage windows — the floating
  narration window AND the OpenCode TUI window driving the session — to the
  destination tag and switches the view there in one call. Keeps the whole
  performance on one workspace; the narration window is display-only and is
  never focused.
- If `stage` is unavailable (non-screencast context or older plugin), the
  manual fallback is: `use <tag>` then immediately `jumpto <narration-winid>`
  (and `jumpto` the TUI window if it should follow too). Spawn the narration
  window first via the plugin's `spawn_window` if none exists.
- Grabbing a reference window before moving (e.g. the user's conversation
  window) is good practice: read `herbstclient attr clients.focus.winid`,
  keep it, and offer `jumpto <winid>` as the way back.
- **Reach + roll-call:** `screencast_whisper` sends a one-way
  notify-send desktop message — the channel to the user when working on a
  different tag than the conversation window, or for demo asides. Before
  (and mid-) presentation run `screencast_stranded`: it audits the
  orchestrator TUI window (captured at first call as the then-focused
  OpenCode window and persisted; `recapture: true` re-captures) and the
  narration window(s) for being on another tag, minimized, off-screen or
  missing, returns `stranded: true` with per-window reasons, and can
  whisper the summary itself (`notify: true`).
- **Whisper v2 + rescue callback machinery** (verified live, dunst/dunstify):
  - `screencast_whisper` with `replace: true` re-uses the previous
    notification's id (dunstify `-p` to capture it, `-r <id>` to replace)
    — one stable slot, no notification spam. Ids persist in
    `$XDG_RUNTIME_DIR/screencast/last-notif.id`.
  - `screencast_whisper` with `rescue: true` attaches a click action that
    yoinks the user back to the orchestrator's tag. Mechanics: dunstify
    takes actions as `-A "key,label"` (COMMA-separated, not `key=label`);
    it has NO `-w` — with `-A` it blocks by default, printing the id
    (via `-p`) immediately and the invoked action key when the user
    clicks or the notification expires. An action named `default` fires
    on plain click/dismiss-activation and can also be triggered
    programmatically with `dunstctl action [ID]`.
  - The tool runs the blocking dunstify in a DETACHED bash handler that,
    on seeing the `default`/`rescue` action, executes
    `herbstclient jumpto <orchestrator-winid>` — the rescue happens
    event-driven, the tool call returns immediately.
  - `screencast_rescue` does the same jump on demand (no notification).

## 6. Floating windows vs presentation: `disjoin_rects` placement

**Concept:** whenever there are floating windows, parts of the tiling layer
— and of other floats — may be obscured. During a presentation/screencast
that is unwanted: the audience must see every region the presenter refers
to. Treat float-over-float and float-over-tiling overlap as a layout bug,
not a cosmetic accident.

**The tool:** `herbstclient disjoin_rects <rect1> <rect2> [rect3…]`
(SPELLING: `disjoin_rects`, NOT `disjoint_rects` — the latter does not
exist and fails with `Command not found`). It prints a partition of the
union of the given rects into mutually disjoint rects:

```sh
herbstclient disjoin_rects 1114x663+33+724 2546x1361+7+7
# 1114x644+33+724   <- inside/adjacent to rect1
# 1114x19+33+1368
# 2546x717+7+7      <- full-width top strip
# 26x644+7+724      <- left sliver
# 1406x644+1147+724 <- clear region right of rect1
```

**Procedure for non-obscuring float placement:**

1. Read each float's **decoration_geometry** (the decorated frame is what
   the audience sees, not `floating_geometry`).
2. Feed all of them to `disjoin_rects`.
3. Any output rect that does not intersect the OTHER window's decoration
   rect is a safe slot. Prefer large, bar-respecting rects (watch the
   polybar strip: content starts ~y=43 on this monitor).
4. **Decorations bleed outward**: border ≈7px per side + ≈29px titlebar on
   top. A client placed exactly at the other window's edge still overlaps
   by the border after decoration. Inset the chosen rect by the deco
   margins before assigning `floating_geometry` (e.g. narration deco ends
   at x=1147 → client x must be ≥1154 for its deco to clear).
5. **Edge contact ≠ overlap**: rects sharing only an edge line intersect
   with zero area — strict inequalities decide; don't count a shared edge
   as obscuration (but DO count the deco bleed from step 4).

Worked example (2026-10-31, monitor 2560x1408, tag `term`): narration
`1114x663+33+724` + conversation `2546x1361+7+7` → rect `1406x644+1147+724`
chosen, conversation set to `1398x644+1155+724` (deco `1412x687+1148+688`)
— 1px clearance, no mutual obscuration.

**Automated (preferred):** the opencode-screencast plugin ships tools for
all of this — `screencast_window_rect`, `screencast_query_disjoint_rects`,
`screencast_largest_free_rect`, `screencast_float_into`,
`screencast_fit_on_screen` and `screencast_fit_floating_layer` (iterative
whole-layer fitting, visible nudges by default, `lock: true` to snap all
windows at once under `herbstclient lock`). Prefer them over manual
geometry math; the manual procedure above documents what they do and
remains the fallback when the plugin is unavailable.

## 7. Tiling layer: uncovering a tiled window obscured by floats

When a floating window covers a TILED window, the fix is frame surgery on
the tiling layer, not float shuffling. hlwm 0.9.5 facts (verified live):

- **`split <dir> <fraction>` keeps clients on the side OPPOSITE `<dir>`:**
  `split bottom F` -> clients in the TOP child (index 0), empty frame at
  bottom; `split top F` -> clients pushed to the BOTTOM child (index 1),
  empty frame on top. Same for left/right. `fraction` is ALWAYS the
  top/left child's share, regardless of direction.
- **Derive the fraction from the float's edge**, not a fixed value: for a
  float covering the bottom, fraction = (float_deco.y - frame.y)/frame.h;
  for a float at the top, (float_deco.y+float_deco.h - frame.y)/frame.h.
  Then the boundary runs along the float's decorated border and the client
  automatically lands on the free side — direction = toward the COVERED
  region (bottom split for a bottom float, top split for a top float).
- **Empty frames persist.** Closing a client leaves its frame behind
  (`herbstclient remove` merges the focused frame into its neighbour;
  `herbstclient load <tag-name> "(clients vertical:0)"` resets a whole
  layout). Frame skeletons also survive `close`.
- **Object tree tags are numeric** (`tags.3.tiling...`); tag NAMES are not
  valid object paths — resolve name -> index by reading `tags.N.name`.
  (`herbstclient silent` suppresses stdout too — never use it to read
  values.)
- **`focused_frame`** (under `tags.<i>.tiling`) exposes `.index` (the
  frame's path within the tree) and `.content_geometry` for the currently
  focused TILED client — jumpto the client first.
- **The jump maneuver:** a floating client unfloated while frame focus is
  on frame X is re-tiled INTO X. So float -> `cycle_frame 1` ->
  `floating=false` moves the window into the neighbouring (free) frame.
  NOTE: `polyframes tile` ("closest empty frame") jumps BACK into the
  vacated covered frame — useless here. `focus down/up` may report
  "No neighbour found" while a float holds client focus; `cycle_frame` is
  reliable. Also note `focus` takes up/down; `split` takes top/bottom.
- Window ids can be RECYCLED after a close; never cache winids across
  transactions.

The plugin's `screencast_uncover_tiling` implements this: largest
unobscured rect inside the tiled window's rect -> edge-aligned ->
split+fraction -> verify -> float/cycle_frame/unfloat recovery if the
client still intersects a float. Interior floats (touching no frame edge)
need TWO sequential splits — open the frame along one edge of the float,
then split the covered child along the perpendicular edge; generalize by
iterating over remaining covered children one float at a time. Not yet
implemented; the tool reports `unsupported` with the free-rect geometry
so a manual two-split can be done.
