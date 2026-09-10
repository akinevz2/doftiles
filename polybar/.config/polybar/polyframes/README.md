# polyframes — JS port of the polybar window-list renderer

CommonJS modules, Node >= 18, no npm dependencies, no build step.
Port of `scripts/polywins.sh` + the `hc_get-*` / `polyframes-*` shell
helpers in `herbst/.local/bin`.

## Module map

| File | Role |
| ---- | ---- |
| `hc.js` | Thin async wrapper around `herbstclient` (`execFile`). Missing objects resolve to `null`, never throw. |
| `clients.js` | `getClients()` — port of `hc_get-clients`. Clients on the focused tag in WM order: `{wid, cls, min, ttl, flt, frame}`. Frame `-1` when `parent_frame` is missing or its index is empty (unsplit root). |
| `frames.js` | `frameSelection(flatIndex)` — port of `hc_get-frame-selection`. Flat index `"00"` → dotted attr path `root.0.0`, but the FLAT index is passed to `list_clients --frame`. No arg → root selection. |
| `groups.js` | `groupClients(clients, activeWid)` — port of `polyframes-groups`. Pure grouping: `minflt|wid` / `unframed|wid` / `frame|frame|class`, first-wins dedup, WM order. Frame-selection lookup injectable. |
| `render.js` | `render(groups, onClick, settings)` — pure polybar formatting (`%{A1..A5}` actions, colors, truncation, separator, max_windows, empty-desktop message). |
| `actions.js` | On-click handlers: `switcher`, `scroll_focus`, `raise_or_minimize`, `close`, `window_ops`, `toggle`. All re-query fresh state. |
| `index.js` | Entrypoint / dispatcher (see below). |

## Run

```sh
node index.js          # bar line + hook listener + layout poll (polybar module)
node index.js --once   # one-shot bar line print, no listeners
node index.js switcher 0 Alacritty
node index.js scroll_focus 0 Alacritty down
node index.js raise_or_minimize 0x1234567
node index.js toggle 0x1234567
```

`DISPLAY` defaults to `localhost:0.0` (WSL2 convention) when unset.

## Debugging pieces with `node -e`

```sh
cd ~/.config/polybar/polyframes

# raw clients
node -e 'require("./clients").getClients().then(c => console.dir(c, {depth:null}))'

# groups (real data)
node -e 'Promise.all([require("./clients").getClients()]).then(([c]) =>
  console.dir(require("./groups").groupClients(c), {depth:null}))'

# frame selection for flat index "00"
node -e 'require("./frames").frameSelection("00").then(console.log)'

# full bar line, one shot
node index.js --once

# render only (pure, no WM)
node -e 'console.log(require("./render").render(
  [{frame:"0",cls:"Alacritty",rep:"0x1",isActive:1,count:2,title:"term",state:"tiling"}],
  "node ./index.js"))'
```

## Fixed bugs vs the shell originals

- `switcher`: pairs were built with command substitution that stripped
  trailing newlines, collapsing all pairs onto one line — the wid
  lookup then matched garbage. Pairs are now array elements joined
  with explicit `\n`.
- `hc_get-frame-selection` with a flat index like `"00"` built the
  nonexistent path `root.00`; `frames.js` converts flat → dotted for
  the attr path only.
- Renderer is defensive: rows with empty wid/cls are skipped, missing
  attributes resolve to `null`, and no field is ever emitted empty.

## Known limitations

- `switcher`/`window_ops` need `rofi`; they fail soft (no-op) when it
  is unavailable or cancelled.
- The hook listener does not cover frame splits/removals (no hook in
  hlwm 0.9.5) — the 1 s layout poll covers those, same as the shell.