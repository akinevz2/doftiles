# PLAN — doftiles stow-package restructure + polyframes deployment

Status: IMPLEMENTED (first pass) — the split landed in doftiles
(`3bc8fe1`); the npm publish path remains an owner decision.

## Goal

Two supported install paths for polyframes:

- **a) standalone**: `git clone` the polyframes repo anywhere +
  `make install` (binary → `~/.local/bin/polyframes`).
- **b) through doftiles**: the dots repo deploys polyframes as part
  of the WM stack — either from SOURCE (a git submodule, built via
  its own Makefile) or from NPM (a published package).

Plus a restructure of the monolithic `herbst` package into
single-responsibility packages, so each stow package guarantees one
thing.

## A. The herbst package split

IMPLEMENTED (plus the follow-up consolidation): the final package set
after both rounds:

- `herbstluftwm` (ex `herbst_wm`, absorbing alacritty/compton/rofi:
  `.config/{alacritty,compton,rofi}`, `rofi_hc_context`) — the systemd
  unit, the trimmed autostart (WM bootstrap + the keys.d sourcing
  loop), the deploy scripts, the generic `hc_*` query/tree tools.
- `herbst_theme` — `reload_theme` + `.config/herbstluftwm/theme`
  (the theme data, extracted from the script).
- `herbst_nav` — `keys.d/nav.sh` + the nav scripts.
- `herbst_floating` — `keys.d/floating.sh` + the float machinery.
- `herbst_focus` — `keys.d/focus.sh` + the focus helpers.
- `herbst_titles` — `winbarctl`.
- `herbst_bar` — polybar + polyctl + the Makefile + the polyframes
  submodule.

The keys.d fragment pattern: each keybind package drops a fragment
into `.config/herbstluftwm/keys.d/`; the autostart sources
`keys.d/*.sh` — stow unfolds the shared directory into per-file
links (verified live).

Further consolidation (second round): `llms` → **`agents`**;
`alacritty`/`compton`/`rofi` merged into `herbstluftwm`;
`zshell`/`vim`/`task`/`maintenance`/`git` merged into **`shell`**
(`.zshrc`, `.vim`, `.taskrc`, `.my-credentials`, `Makefile`,
`check-msi-dirs`, `load-credentials`, `adopt-these` (ex-dekineify) all moved). The
`herbst`/`polybar`/`alacritty`/`compton`/`rofi`/`zshell`/`vim`/
`task`/`maintenance`/`git`/`llms` packages retired.

| new package | owns | trimmed from |
| --- | --- | --- |
| `herbst_wm` | STARTING the WM and nothing else: `.config/systemd/user/herbst.service`, a trimmed `.config/herbstluftwm/autostart` (WM spawn, `emit_hook reload`, the spawn-env `setenv` block), `.local/bin/install/ubuntu.deploy`, `.local/bin/on.deploy` | `herbst` |
| `herbst_theme` | `.local/bin/reload_theme` + `.config/herbstluftwm/theme` (the theme block EXTRACTED from reload_theme into a data file reload_theme sources) | `herbst` |
| `herbst_nav` | navigation keybinds + frame/window nav scripts (`hc_focus`? see the open question) | `herbst` |
| `herbst_bar` | `.config/polybar/`, `.local/bin/polyctl` + friends, `.local/share/polybar/Makefile` (see §B) | `polybar` (minus polywins) |
| `herbst_titles` | title-strip settings + the title-related keybinds | `herbst` |
| `herbst_floating` | the float registers: `hc_focus`, `hc_floatx`, `hc_zoom`, the mod-f/mod-x/mod-ctrl-f keybinds | `herbst` |
| `herbst_focus` | the focus/cycle keybinds + `hc_full_focus`, `hc_peek` | `herbst` |

Open questions (owner decisions):
- which package owns `hc_unmaximize`/`hc_maximize` (the float
  machinery vs the maximize daemon pair)?
- `herbst_nav` vs `herbst_focus` boundary (mod-h/j/k/l resize vs
  directional focus)?
- the compton context-menu references to `hc_center`/`rofi_tags_*` —
  the shims keep the names, so no dots-side breakage either way.

## B. `herbst_bar/.local/share/polybar/Makefile`

Two recipes for polyframes deployment; the dots `make wm` picks one
via a variable (`POLYFRAMES_SOURCE=submodule|npm`, default
submodule):

- **submodule (from source)**:
  - `polyframes-register`: `git submodule add https://github.com/akinevz2/polyframes .local/share/polyframes` (or sync/update: `submodule update --init --remote`), then `bun install && make install` inside it.
  - `polyframes-sync`: `submodule sync --recursive` + `update --remote` + rebuild + install.
- **npm**: requires publishing polyframes to npm first (the
  package.json needs `bin` + `files: ["dist"]`; publish the compiled
  binary or ship the source and require bun at runtime — owner
  decision). Recipe: `polyframes-npm`: `npm install -g polyframes`
  (or `github:akinevz2/polyframes` pre-publish).
- both end at the same invariant: `~/.local/bin/polyframes` exists and
  `[module/polyframes]` execs it.

## B2. Consolidation round three (2026-10-30)

IMPLEMENTED. The package set after round three:

- `compton`, `git` — empty dirs, removed. (`git`'s personal settings
  would live on a separate branch if reintroduced; nothing to move.)
- `herbst_nav` -> `herbstluftwm` (nav.sh keybinds + the three nav
  scripts).
- `services` -> `herbstluftwm` (compton/dunst units join herbst.service).
- `herbst_floating` -> `herbst_focus` (the whole float machinery +
  keys.d/floating.sh join focus.sh and the focus helpers).
- `herbst_bar` -> `polybar` (config, polyctl, the polybar Makefile —
  now bar-control only, polyframes deploys delegated to depends).
- `herbst_titles` repurposed: winbarctl moved to `herbst_theme`; the
  package now holds ONLY the window-title subsection of the theme as
  `.config/herbstluftwm/theme.d/titles.theme`, sourced by
  reload_theme after the main theme file (keys.d-style partials).
- `depends` (was an empty placeholder) is now the deployment +
  dependency package: the deploy scripts (on.deploy,
  install/ubuntu.deploy), the polyframes submodule (moved from
  herbst_bar), a Makefile with `deploy-fromsource` (conditional
  submodule clone + build + install), `deploy-fromnpm` (npm install
  -g github:akinevz2/polyframes), `update` (fetch + ff-only with
  --rebase --autostash fallback; submodule sync; per-method artifact
  refresh), `uninstall`, and conf-get/conf-set helpers backed by
  `.config/doftiles.conf` (POLYFRAMES_METHOD=source|npm|none).
  The top-level `make update` delegates here. The opencode-screencast
  submodule STAYS in agents: opencode.json(c) loads the plugin via
  the relative path ./opencode-screencast.
- Top-level Makefile: the `depends` metapackage renamed to `deps`
  (the name now belongs to the stow target); the `services` stow
  target dropped; `wm` covers the full WM stack; the MAKEFILES
  variable renamed to MF_FILES (a sub-make inheriting MAKEFILES
  re-reads the files and double-defines every target).
- `wm.packages` updated to the final set: herbstluftwm herbst_theme
  herbst_focus herbst_titles herbst_web dunst polybar depends agents
  shell.

## B3. Consolidation round four (2026-10-30): the herbst re-merge

IMPLEMENTED. The four herbst split packages are folded back into
`herbstluftwm`, undoing the herbst half of round three (the
polybar/depends half stays):

- `herbst_focus` -> `herbstluftwm` (keys.d/{focus,floating}.sh + the
  whole .local/bin float machinery incl. the polyframes shims
  hc_center/hc_resize/hc_tile/hc_fit_to).
- `herbst_theme` -> `herbstluftwm` (theme + reload_theme + winbarctl).
- `herbst_titles` -> `herbstluftwm` (theme.d/titles.theme).
- `herbst_web` -> `herbstluftwm` (xvfb/x11vnc/novnc units).
- `wm.packages`: herbstluftwm dunst polybar depends agents shell.
- deploy-menu.sh: the herbst_theme post-stow hook (reload_theme -f)
  folded into the herbstluftwm hook (reload + theme apply).
- Live cutover order: stow -D the four packages FIRST (unstow while
  the dirs are intact), git mv the trees, rmdir the emptied packages,
  stow -R herbstluftwm, herbstclient reload. Verified: the full
  keybind set (91) survives the reload and no dangling links.
- `~/.config/herbstluftwm` is now a single stow FOLD (whole-dir
  symlink) — the autostart configuration lives in exactly one place.

## C. Per-package resource matrix

SUPERSEDED by the second consolidation round (the herbst split +
alacritty/compton/rofi → herbstluftwm; zshell/vim/task/maintenance/
git → shell; llms → agents) — the live matrix is now:

| package | bin | share | config | share Makefile |
| --- | --- | --- | --- | --- |
| herbstluftwm | generic hc_* tools, deploy scripts | — | hlwm autostart + keys.d, alacritty, compton, rofi | — |
| herbst_theme | reload_theme | — | hlwm/theme | — |
| herbst_nav | hlwm_cwds_dump, hlwm_launch, hc_move | — | keys.d/nav.sh | — |
| herbst_floating | the float machinery + shims | — | keys.d/floating.sh | — |
| herbst_focus | hc_full_focus, hc_peek, hc_bounce | — | keys.d/focus.sh | — |
| herbst_titles | winbarctl | — | — | — |
| herbst_bar | polyctl | polyframes (submodule) | polybar | polybar/Makefile |
| herbst_web | — | — | xvfb/x11vnc/novnc units | — |
| agents | opencode-remote*, MCP tooling | — | opencode/poolside config | — |
| shell | install hooks, firefox wrapper, check-wsl, check-msi-dirs, load-credentials, adopt-these | — | bashrcx/profile/zshrc/vim/taskrc/credentials | — |
| services | — | — | compton/dunst units | — |
| rofi/compton remnants | merged into herbstluftwm | — | — | — |

Original matrix (pre-consolidation, kept for reference):

## C. Per-package resource matrix (all dots stow packages)

For each package: `.local/bin` (scripts), `.local/share` (clone-able
resources: submodules + docs, or plaintext docs that just exist),
`.config/{software}` (a package may span several), and
`.local/share/{software}/Makefile` (per-software orchestration):

| package | bin | share | config | share Makefile |
| --- | --- | --- | --- | --- |
| herbst_wm | install/on.deploy | — | systemd/user + hlwm autostart | — |
| herbst_theme | reload_theme | — | hlwm/theme | — |
| herbst_bar | polyctl + friends | polyframes (submodule) | polybar | polybar/Makefile |
| herbst_nav | nav scripts | — | (keybinds live in autostart — see open question) | — |
| herbst_floating | hc_focus/floatx/zoom | — | — | — |
| herbst_focus | hc_full_focus/peek | — | — | — |
| herbst_titles | — | — | — | — |
| rofi | ~40 bin helpers | — | rofi themes/applets | — |
| compton | context-menu helpers | — | compton.conf + rofi_hc_context | — |
| dunst | check-mail/read-mail | — | dunst config | — |
| alacritty | — | — | alacritty config | — |
| shell | install hooks, firefox wrapper, check-wsl | — | bashrcx/profile/aliases | — |
| git | load-credentials, adopt-these | — | `.my-credentials` | — |
| llms | opencode-remote*, MCP tooling | — | opencode/poolside config | — |
| services | — | — | systemd units | — |
| maintenance | check-msi-dirs | — | check-msi-dirs unit | — |
| task / vim / zshell | — | — | taskrc / .vim / zshrc | — |

Rule of thumb going forward: a package earns a `.local/share/Makefile`
when it deploys something with its own build/pull lifecycle
(polyframes now; potential: polywins).

## D. Implementation order

1. Extract `herbst_wm` (the systemd unit + the trimmed autostart +
   the deploy scripts) — verify: `make wm` still boots hlwm.
2. Extract `herbst_theme` (reload_theme + the theme file) — verify:
   `reload_theme -f` re-applies identically.
3. Split the keybinds into nav/floating/focus/titles packages (the
   autostart keyreg block moves per-register; the keybind helpers
   follow their keys).
4. `herbst_bar` + the polybar Makefile (the submodule path first —
   it needs no npm publish).
5. The npm path (publish + the recipe) — owner decision on
   visibility/naming.
6. Retire the monolithic `herbst` package (update `wm.packages`,
   AGENTS.md, the README's package table).

## E. Risks

- stow package ordering: `herbst_wm` must stow before `herbst_bar`
  (the bar needs the WM env); the `service.order` file covers
  services only.
- the autostart split: keybinds reference helper paths owned by
  OTHER packages — the stow -R of one package must not break
  another's paths (all helpers stay in `~/.local/bin`, merged by
  stow, so this holds).
- the fresh-start guard (`PF_THEME_APPLIED`) lives in the WM env —
  `herbst_theme`'s reload_theme must keep working across the split
  (the env flag survives, only the autostart re-runs).
