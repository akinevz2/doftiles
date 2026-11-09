# AGENTS.md — dots repository guidance

`Hi guys, how's it going? :)`

Guidance for AI coding agents working in this dotfiles repository.

**Baseline: do not commit without a direct request to do so.**

## What this repo is

A GNU Stow-based dotfiles repo (`github.com/akinevz2/doftiles`). Each
top-level directory is a **stow package**: its contents mirror `$HOME`
and get symlinked into place with `stow -R -t $HOME <package>`.

Consumer machines: WSL2 hosts (`WS-MINIFRIDGE`, `WS-VISION`) running
herbstluftwm + compton against VcXsrv/X11 on Windows; `ws-rarebox`
(Ollama host); and the devcontainer (`~/development`), which clones
this repo via the dotfiles feature and runs
`.devcontainer/update-dots.sh` on start/attach.

## Stow package layout

| Package | Contents |
| ------- | -------- |
| `herbstluftwm` | THE single herbst stack package: WM bootstrap (`autostart`), theme (`theme`, `theme.d/titles.theme`, `reload_theme`, `winbarctl`), ALL float/focus machinery + the full `hc_*` toolset (`hc_command` is the `$Mod-c` menu; `hc_center`/`hc_tile` are two-line shims delegating to `polyframes center|tile`), `dunstify-{callback,input}`, `pause`, `launch_alacritty`, `hc_send-error(-daemon)`, `.config/{alacritty,herbstluftwm,opencode,rofi,systemd}` and `rofi_hc_context` |
| `compton` | `.config/compton` (picom-adjacent compositor config + rofi context menu), unit |
| `dunst` | `.config/{dunst,systemd}` (`dunstrc`, `dunst.service`), legacy `.local/share/dunst/Makefile` hook |
| `polybar` | `.config/polybar` (config.ini + polybar.sh + polywins.sh), `.local/bin/{polyctl,ewmh_labels}`, `.local/share/polybar/Makefile` (bar control) |
| `shell` | `.bashrcx`, `.profile`, `.aliases`, `.exports`, `.zshrc`, `.shellx.rc` (THE shell extension — see credentials doctrine), `.vim`, `.taskrc`, `.my-credentials`, `Makefile`, `.config/{aliases,exports,mimeapps.list,systemd}` (incl. `check-x-server.service`), `.local/bin/` (install/ hooks, `check-wsl`, `got`, `green`, `yellow`), `.local/share/applications/` |
| `wsl` | WSL-interop metapackage: `.local/bin/firefox` — the runtime-conditional browser launcher (Windows Firefox via the interop mount when present, native fallback otherwise; decides at INVOCATION, no stow-time conditionals) — and `.config/exports.d/wsl.sh`, the opt-in WSL env fragment. **NOT in the stows manifest: machines opt in with `make stow-wsl` and configure per machine** (the generic repo auto-installs nothing WSL) |
| `agents` | `.config/{opencode,poolside}` — OpenCode config (the `opencode-screencast` plugin is vendored as plain files; `opencode.jsonc` loads it via the relative path `./opencode-screencast` — moving it breaks plugin loading), `.local/bin/{github-mcp-wrapper,opencode-remote,opencode-remote-add}` (manual user tools) |
| `depends` | deploy machinery remnants ONLY: `.local/bin/install/{ubuntu.deploy,manjaro.deploy}` — the `<target>.deploy` scripts are LIVE machinery (stow-folds into `~/.local/bin/install/`; on-deploy's check/install/pkg/toolchain resolve every binary through them), `.config/doftiles.conf` (deploy-method state). Hosts the on-deploy bootstrap build |
| `on-deploy` | submodule checkout `.local/share/on-deploy` + the built binary artifact `.local/bin/on-deploy` |
| `herbctl` | submodule checkout + artifact (same shape) |
| `herbstutil` | submodule checkout; deploys through the bun GLOBAL install (registry package) |
| `polyframes` | submodule checkout + artifact (rofi menus, tile/center live as its subcommands) |
| `bat` | submodule checkout `bat-src` + artifact |
| `novnc`, `xvfb`, `x11vnc`, `xrdp` | individually deployable service packages (commented out of the stows manifest; enable deliberately) |

Repo-level files — `Makefile`, `README.md`, `AGENTS.md`, the manifests
(`*.depends` — tracked via force-add, see Manifests), — are **not
stowed** (never put dotfiles at repo root). `docs/` holds misc
analysis; also not stowed.

## How stow linking works

- `stow -R -t $HOME <pkg>` restows: removes the package's links and
  re-creates them. It does not delete real files in `$HOME`.
- **Resolution rule**: a file seen at `~/.config/...` or
  `~/.local/...` comes from the package holding the same relative
  path. Edit the repo file, never the `$HOME` link; NEW files must be
  added in the repo and restowed.
- Conflict caveat: a real file at the target path makes stow fail.
  Never create `$HOME` links by hand for package entries — stow owns
  them (an absolute hand-made symlink once blocked `make wm/update`
  with "existing target is not owned by stow").

## Manifests — one file each, `*.depends`, tracked via force-add

Every manifest is ONE file (stows, wm, system, services):
`<name>.depends`. The pattern is gitignored, so:

- **Developer expansion**: edit the manifest, then
  `git add -f <name>.depends` + commit — mainline ships. This is the
  ONLY way manifest content enters the repo.
- **User personalization**: machines edit the same file and hide the
  dirtiness with `git update-index --skip-worktree <name>.depends`
  (set once, after personalizing). `git status` stays clean forever;
  pulls never merge-conflict on the manifests.
- **The ritual**: upstream manifest changes would otherwise collide
  with a skip-worktree file — `make update` / `make force-upgrade`
  run the dance automatically (stash the flagged manifests → pull →
  `depends` pops the stash back and re-skips). A stash-pop CONFLICT is
  the volition point: resolve by hand (the stash is kept).
- Fresh machines that never personalize just track the generic build
  and receive mainline updates as normal pulls.

Layer contents:
- stows — the stow package list (space-separated lines, `#` comments);
  `WM_PACKAGES` walks it; `make install` and the stow verbs deploy
  exactly this set.
- wm — line 1: required BINARIES (resolved via the `<target>.deploy`
  protocol); line 2: the deployment session; last line: the deploy
  target.
- system — the SUBMODULE manifest: each line `<pkg> <path>…`; the
  configured scope of `on-deploy depends`.
- services — user units, enabled+started IN ORDER by
  `make services-check`.

## Makefile targets (verified 2026-11-06)

- `make help` — the recipe listing. **Formatting doctrine**: ONE
  recipe per line (never bunch aliases like `all/stow/wm/restow`),
  wrapped description continuations indent TWO MORE spaces than the
  command column, ≤80 columns, knobs listed separately.
- `make depends` — submodule sync + `--init --remote` update to each
  tracked branch tip (bat's nested layers skipped) + the on-deploy
  bootstrap build.
- `make bootstrap` — depends + `bun` + `rustup` + `trust` + the FULL
  `on-deploy depends --install` walk (the system manifest's scope). The
  walk IS the deploy of every submodule artifact.
- `make bun` / `make rustup` — ensure a toolchain: `--check` query
  FIRST; the sudo pre-flight (`make sudo`) runs only when an install
  is actually needed (headless runs with both toolchains present pass
  without sudo). Force re-checks: `FORCE=1`.
- `make trust` — bun postinstall policy steps (via the herbstutil
  adapter).
- `make toolchain` — depends + both toolchain verbs (each --check
  first).
- `make configure` — **the ONLY credentials interaction point** and
  the reconfiguration gate: the on-deploy configure TUI on a tty;
  headless requires `FORCE=1` (applies the recorded config) and
  otherwise exits 2 loudly.
- `make on-deploy` — ALWAYS rebuilds the binary from the checkout,
  then stows the `depends` + `on-deploy` packages.
- `make install` — on-deploy + configure gate + `preserve` +
  `packages install $(WM_PACKAGES)` + status. The safe headless
  deploy: `make bootstrap toolchain install YES=1` (there is no
  `make deps` — the walk lives in bootstrap).
- `make add-packages` — the wm-manifest binary walk: verify every
  binary, install the MISSING ones through the `<target>.deploy`
  protocol (`on-deploy install`; `YES=1` = no confirmations; the sudo
  grant still needs a tty). This is the recipe to hand the user when
  a wm-manifest binary is missing.
- `make all` / `stow` / `wm` / `restow` — the same recipe: restow the
  `WM_PACKAGES` stack (one line each in `make help`; no alias
  bunching).
- `make stow-<pkg>` / `unstow-<pkg>` / `depends-<pkg>` — ONE package
  through on-deploy (`depends-<pkg>` honors toolchain checks loudly).
- `make unstow` / `clean` — drop the WM_PACKAGES links.
- `make update` — SAFE PULL (branch-local): fetch + ff (fallback
  rebase --autostash), submodule sync + update, on-deploy rebuild.
  Artifacts untouched; chain `make update install` for
  pull-with-install (install runs EXACTLY once).
- **AGENTS rule — submodule sources**: whenever working with the
  sources of a dots submodule, run `make update` (to update to the
  latest) and `make stow` (to deploy the latest) after the changes —
  the stowed binaries are only as fresh as the last `make stow`.
- `make force-upgrade` — fetch + ff + submodule re-anchor + healing
  clean + rebuild + configure gate + stow.
- `make livereload` — check gate (LOUD on missing wm-manifest
  binaries) + restow the unit packages + daemon-reload + per-unit
  reload (`herbstclient reload` keeps the WM binary).
- `make status` — on-deploy check + services status + the
  credentials reminder.
- `make services-check` — daemon-reload + `enable --now --no-block`
  in the services manifest's order. `services-start`/`services-stop`/
  `restart` — interactive-confirm; non-interactive requires `YES=1`.
  **Never restart user services casually** (kills the WM session).
- Knobs: `FORCE=1` (redeploy / non-interactive fail-safe), `YES=1`
  (bypass confirmations), `DRY=1`, `M=` (explicit method).

## The per-package depends Makefile scheme

`on-deploy depends` drives every stow package shipping
`.local/share/depends/<pkg>/Makefile` (the uniform layout, the
2026-11 resplit). Standard
rules: `toolchain`, `build`, `link`, `install`, `uninstall`,
`status`; a `metadata` contract (five bare `key=value` echoes) is
consumed by `on-deploy managed <pkg>` — the router owns ALL
method/branching logic. Artifacts land in `dots/<pkg>/.local/bin/`
(gitignored build products; stow ships them). Knobs: `FORCE=1`,
`DRY=1`, `M=`.

**Freshness guards** (2026-11): the expensive package steps skip when
up to date — `herbctl`/`polyframes` `compile` (standalone recompiles,
~120–133 MB) compare `dist/<artifact>` against `src/` + `package.json`
+ `bunli.config.ts`; `polyframes` `bun-hooks` skips when
`node_modules/bun/bin/bun.exe` already exists; `herbstutil` `link-src`
skips the global `bun add -g` when the globally installed version
matches the checkout's; the `depends` bootstrap build skips when the
on-deploy artifact is fresher than the checkout (a pull updates source
mtimes, so pulled changes still land a fresh binary). `FORCE=1` forces
every one of them. bun.lock is deliberately excluded from the
freshness sets (bun install touches its mtime on no-change runs).
Wall-clock effect: `make install` 35.7 s → 10.3 s, `make status`
13.3 s → 3.1 s.

## Deployment doctrine

- **Every deployed artifact is deployed from inside the repo via
  stowing of one package — never raw into the user's profile.**
  Generated artifacts live INSIDE their package (gitignored, like the
  `.local/bin` builds) and stow publishes the link. Example:
  `~/.my-credentials-env` → `dots/shell/.my-credentials-env`.
- **`.local/bin` membership**: a deployed script must be WIRED
  (referenced by a config, unit, autostart, or another script) or an
  actively used manual tool. Orphans get removed (2026-11-06 purge:
  `dekineify`, the `check-msi-dirs` machinery — script, maintenance
  script, and its service file — the `check-mail` flow: `check-mail.sh`,
  `read-mail.sh`, `show-mail`, `test-stack-notify`,
  `test-urgent-notification`, `hlwm_launch`/`hlwm_cwds_dump`, and the
  deploy helpers `on.deploy` + `deploy-menu` — zero callers; the
  firefox wrapper became runtime-conditional in `dots/wsl`, so the
  stow-time prune/relink hook died with deploy-menu). **Keep** all
  `hc_*` (the `$Mod-c` hlwm operation menu) and `green`/`yellow`
  (used liberally in user scripting).
- **Credentials** (2026-11, final): `make configure` is the ONLY
  point credentials may be interacted with. `~/.my-credentials` (name
  line 1, email line 2) is tracked ON PURPOSE — never re-add it to
  `.gitignore`. The env artifact `dots/shell/.my-credentials-env` is
  gitignored, written by the configure flow, stow-deployed to
  `$HOME`. git config is applied INLINE by that flow. There are NO
  standalone credential bins (`configure-credentials`,
  `load-credentials` were deleted) and NO `make credentials` recipe —
  never re-create either. **Loading happens ONLY in the shell
  extensions at shell start**: `~/.shellx.rc` (sourced by
  `.bashrcx`→bash and `.zshrc`→zsh) reads `~/.my-credentials`
  directly and exports `GIT_AUTHOR_*`/`GIT_COMMITTER_*`.

## Services / WM runtime model

- `check-x-server.service` (`shell` package) runs FIRST and is the
  only place that resolves the X server: `on-deploy detect-server
  --persist-to-systemd` sets `DISPLAY` in the systemd user manager
  environment. Every WM unit is `After=`/`Requires=` it (not
  transitive — each names it).
- Provided names: providers declare `[Install] Alias=` (check-x-server
  and xvfb both `Alias=x-server.service`; herbst
  `Alias=x-window-manager.service`). Enable exactly ONE provider;
  consumers require the symbolic name. Never `systemctl --user
  reenable` stow-linked units (disable deletes a linked unit file
  symlink — that destroyed stow links once already).
- `compton.service` is `After=`/`BindsTo=` herbst.
- After changing anything under a unit: restow the package +
  `systemctl --user daemon-reload`.
- The xrdp FEATURE (provisioner-managed, no stow package) attaches
  RDP to the x11vnc framebuffer on port 3390.

## Headless / non-interactive mode

- The deploy chain is headless with `YES=1`:
  `make bootstrap toolchain install YES=1` (or
  `make update install YES=1`).
- Toolchain recipes query `--check` first — an installed toolchain is
  a cheap no-op, no sudo consulted.
- Anything shelling through sudo (system packages) needs passwordless
  sudo or an interactive TTY — inherent, fails loudly, never hangs.
- **Interactive sudo from the agent**: when a step needs root and the
  session is headless, spawn an interactive terminal in the repo
  (`launch_alacritty --urgent --no-distract "cd ~/dots && exec bash
  -l"`; see the spawn-directory skill) and ask the user to run the
  MAKE RECIPE that implements the step — `sudo make <recipe>` (e.g.
  `sudo make bootstrap` for missing toolchains, `make add-packages`
  for missing wm-manifest binaries) — NEVER the raw system-level
  command. The recipe owns the flow (pre-flight grant, package
  resolution through the `<target>.deploy` protocol, verification);
  asking for the raw command bypasses the machinery the repo
  documents.
- TUI/session gates: `make configure` is tty-only without `FORCE=1`.

## Quirks and conventions

1. **DISPLAY comes from the manager env** (check-x-server persists
   it). Never hardcode `Environment=DISPLAY=` in a unit. Fallback
   convention when unavoidable: `localhost:0.0` — never
   `127.0.0.1:0`.
2. **Software GL is WSL-only**: `LIBGL_ALWAYS_*` live inside the
   `WS*` block of `exports`.
3. **`BROWSER="firefox"` is intentionally unqualified** — it resolves
   to the `wsl` package's runtime-conditional wrapper: Windows Firefox
   via the interop mount when present, native fallback otherwise.
   `$BROWSER` alone is not enough: `xdg-mime default firefox.desktop
   x-scheme-handler/http x-scheme-handler/https text/html` wires the
   associations. `xdg-settings` refuses to run while `$BROWSER` is
   exported.
4. **Files end with a trailing newline** (normalized 2026-10). Keep
   it in new files.
5. **`herbstluftwm/.config/opencode/opencode.jsonc`-style local
   provider configs**: no `temperature`/`top_p` keys for the local
   Ollama provider. Where `opencode.json` is a symlink to
   `opencode.jsonc`, edit the `.jsonc` only.
6. **herbst autostart uses `hsetroot`** (not `xsetroot`) for the
   background.
7. **Avoid `awk` in shell scripts** (three past bugs). Prototype
   complex string manipulation in Node first; in scripts use only
   `cut`, `grep -F`, `printf`, and remember `read` strips
   IFS-whitespace (normalize empty first fields or use `\x01`
   separators).
8. **Rofi dmenu gotchas**: icon placeholders need `element-icon {
   size: 0; }`; pango markup is unreliable in dmenu mode (use plain
   prefixes like `->`).
9. **herbstutil is a real global npm package** (used by polyframes
   and the screencast plugin). bun's trust policy may block
   postinstalls: `bun pm trust -g herbstutil bun`.
10. **Submodules track their upstream branches** (.gitmodules, 2026-11):
    each submodule declares `branch = main` (bat: `master`), so
    `git submodule update --remote` follows the upstream branch rather
    than a frozen SHA. `make update` still fast-forwards only when
    upstream advanced; nested assets (bat) stay untouched by routine
    flows unless deliberately bumped.
11. **polyframes owns the rofi menus** (`tags`, `hidden`, `windows`,
    `launch`, `switcher-menu`, `window-menu` subcommands). `hc_tile`/
    `hc_center` remain two-line shims — dots-side callers depend on
    the untouched names.
12. **`polyframes spawn` = typed one-shot `hc rule once`**; at least
    one criterion required. bunli parses flag-like tokens even after
    `--` — commands with flags go through `--cmd '<string>'` or a
    wrapper file.
13. **No Python in this repo** (the last one was deleted 2026-10).
14. **Submodule versioning — don't burn the minor on small patches**
    (herbctl, polyframes, herbstutil, on-deploy; 2026-11): semver with
    segments read as `0.x.0` = minor, `0.0.x` = patch. Minor bumps
    (`v1.5.0`) are for real features/new verbs; small patches and
    behavior tweaks bump the PATCH segment (`v1.4.1` style). Burning a
    minor per patch churns releases for nothing (v1.5.0 + v1.6.0 both
    went out on same-day tweaks — kept, not reverted; the doctrine
    applies going forward).
15. **`make update` is headless out of the box**; the TUI/session
    gates are the only real tty assumptions.

## Quick verification workflow

```sh
cd ~/dots
make install YES=1       # full non-interactive deploy
make status              # check + services + credentials reminder
make services-check      # daemon-reload + enable --now (ordered)
journalctl --user -u herbst.service -u compton.service -b --since "2 min ago" --no-pager
```

Known journal noise: polybar tray deprecation warnings and arandr
`gdk_atom_intern` assertion failures (upstream GTK quirk).
