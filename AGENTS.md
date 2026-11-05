# AGENTS.md — dots repository guidance

`Hi guys, how's it going? :)`

Guidance for AI coding agents working in this dotfiles repository.

`My only baseline request is that you do not commit without direct request to do so.`

## What this repo is

A GNU Stow-based dotfiles repo (`github.com/akinevz2/doftiles`). Each
top-level directory is a **stow package**: its contents mirror the layout of
`$HOME` and get symlinked into place with `stow -R -t $HOME <package>`.

Primary consumer environments:

- **WSL2 host** (`WS-VISION`, hostname matches `WS*`) running
  herbstluftwm + compton against VcXsrv/X11 on Windows.
- **Devcontainer** (`~/development`), which clones this repo via the
  devcontainer `dotfiles` feature and runs
  `.devcontainer/update-dots.sh` on start/attach.

## Stow package layout

| Package | Contents |
| ----------- | ---------- |
| `herbstluftwm` | THE single herbst stack package (2026-10 re-merge: herbst_focus, herbst_theme, herbst_titles and herbst_web folded back in, then the last `keys.d/{nav,focus,floating}.sh` fragments folded into the master autostart — no fragment sourcing loop remains). The WM bootstrap (autostart only), the theme (`theme`, `theme.d/titles.theme`, `reload_theme`, `winbarctl`), ALL the float machinery + focus helpers (`hc_focus`, `hc_floatx`, `hc_zoom`, the maximize family, `hc_center`/`hc_resize`/`hc_tile`/`hc_fit_to` shims, minimize/reveal/show, `hc_bounce`, `hc_peek`, `hc_full_focus`), the generic `hc_*` tools + `hlwm_*` scripts, `rofi_hc_context`, `.config/{alacritty,compton,rofi}` and all systemd user units (`herbst`, `compton`, `dunst`, `hc_send-error-daemon`, `xvfb`, `x11vnc`, `novnc`). |
| `polybar` | `.config/polybar/` (config.ini + polybar.sh + polywins.sh
scripts), `.local/bin/{polyctl,ewmh_labels}`,
`.local/share/polybar/Makefile` (bar control: theme/reload/up/down) |
| `depends` | deployment + dependency management: `.local/bin/on.deploy`,
`.local/bin/install/{ubuntu,manjaro}.deploy`, the FOUR bun submodules
at `.local/share/{on-deploy,herbstutil,herbctl,polyframes}`, the
per-package depends Makefile at `.local/state/depends/depends.Makefile`
(the 2026-11 scheme: toolchain/build/link/install/trust rules), and
`.config/doftiles.conf` (deploy-method state, written by the package
Makefile's conf-set) |
| `dunst` | `.config/dunst`, `.local/bin/check-mail.sh`, `read-mail.sh` |
| `agents` | `.config/opencode`, `.config/poolside`, `.local/bin`,
`.local/share` — OpenCode config (the `opencode-screencast` plugin is
vendored here as plain tracked files — opencode.json(c) loads it via
the relative path `./opencode-screencast`, so moving it would break
plugin loading) |
| `shell` | `.bashrcx`, `.profile`, `.aliases`, `.exports`, `.zshrc`,
`.vim`, `.taskrc`, `.my-credentials`, `Makefile`,
`.config/{aliases,exports,mimeapps.list}`, `.local/bin/` (install
hooks, firefox wrapper, check-wsl, check-msi-dirs, load-credentials,
dekineify), `.local/share/applications/` |

Repo-level files —
`Makefile`, `README.md`, `AGENTS.md`, `wm.packages`, `wm.requires`,
`service.order` — are **not** stowed (never put dotfiles at repo root
— they won't be linked). Misc documentation lives in `docs/`
(`PLAN.polyframes-deployment.md`, `analysis.md`, `polywins.md`) —
also not stowed.

## How stow linking works (and how to resolve files)

- `stow -R -t $HOME <pkg>` restows: removes existing links for the package
  and re-creates them. It does **not** delete real files in `$HOME`.
- **Resolution rule**: when you see a file at `~/.config/...` or
  `~/.local/bin/...`, its source lives in this repo under the package that
  contains `.config/...`/`.local/...` with the same relative path. To edit a
  live config, edit the repo file, not the symlink target in `$HOME`
  (they're the same inode for stowed links, but new files must be added in
  the repo and restowed).
- `~/.my-credentials -> dots/shell/.my-credentials` is provided **by
  stow** (the `shell` target). Do not create manual symlinks for files
  that are top-level entries of a stow package — stow handles them.
- Conflict caveat: if a real file already exists at the target path, stow
  fails. For `~/.bashrc` specifically, the distributed file is preserved via
  the `shell` package's `.bashrcx` + install hook instead of a direct link.

## Makefile targets

Package manifests live in repo-level files: `wm.packages` (WM stack
list), `wm.requires` (required binaries — the Makefile reads only its
**first line**; the second line `ubuntu` is a target-distro
annotation), `service.order` (unit start order).

- ANY package target (`make polybar`, `make shell`, ...) stows the
  package and runs its post-stow hook. Hooks live in
  `scripts/deploy-menu.sh` (repo-side, not stowed) and are GUARDED:
  hooks needing a running WM/X no-op with a note on headless targets
  (`herbstluftwm` -> herbstclient reload; `herbst_theme` ->
  reload_theme -f; `polybar` -> polyctl reload; `shell` -> bashrc
  hook only — the load-credentials call was MOVED out of the hook
  into the gated `make credentials` step, the last stage of
  bootstrap, which prints a name/email reminder when
  ~/.my-credentials is missing instead of hard-erroring mid-deploy).
- `make deploy` — selective deployment, TUI-driven when interactive:
  a whiptail checklist (preselecting currently-stowed packages; plain
  numbered menu when whiptail is missing). Fine-grained and
  non-interactive: `make deploy P="shell herbst_theme"`.
- bare `make` — restows the REMEMBERED subset: every stow action
  records itself in `~/.local/state/doftiles/stowed` (machine-local
  XDG state, deliberately not in the repo — the stowed set differs per
  machine). Stale entries are skipped with a note; `make forget
  P="pkg ..."` drops entries (without unstowing).
- `make all` — stow + hook every package (and remember them all).
- `make bootstrap` — DEPLOY ON-DEPLOY, NOTHING ELSE (the delegation
  seed; safe on a systemd target with no running WM): initialize the
  submodule checkouts at their remote tips, install the on-deploy
  binary when missing (`_bootstrap-on-deploy` builds it — bun is
  bootstrapped through npm inside the build when neither bun nor the
  platform provide it), stow the `depends` package (the on.deploy
  shim + the `install/` deploy scripts the binary's machinery needs),
  and run the bun-submodule trust steps (`make trust`, delegating to
  the depends package Makefile). A full deployment is the explicit
  chain now: `make bootstrap toolchain deps install`.
- `make toolchain` — bootstrap chain + `on-deploy toolchain --bun`:
  installs the language toolchain the per-package depends Makefiles
  build with (`YES=1` runs it non-interactively). on-deploy's
  `toolchain` verb supports `--bun|--rustup` (platform package
  manager; bun falls back to npm) and `--check` (verify-only
  fail-fast) — the `<lang>` assurance the per-package Makefiles call.
- `make deps` — manifest existence check, then
  `on-deploy depends --install`: sync the submodule checkouts and
  drive every package's `dots/<pkg>/.local/state/depends/<pkg>.Makefile`
  — `--build` = sync + build (no install), `--install` = sync +
  build + install, bare = the discovery report. `on-deploy depends
  --no-sync` re-runs the Makefile rules without the git phase, and
  `--only <pkgs>` narrows the walk.
- `make wm` — stow the stack from `wm.packages`; `make stow` is the
  same thing; `make bash` = `shell` + `agents` only.
- `make add-packages` — verifies every binary in `wm.requires`,
  failing fast listing missing ones; the `on.deploy` walk (which
  prompts per missing binary) runs only on an interactive terminal.
- `make add-packages-system` — previews, then after confirmation
  `sudo stow -t /` any `system-*` packages; interactive only (sudo
  needs a terminal); `YES=1` bypasses the confirmation.
- `make status`, `services-available`, `services-installed` — report
  systemd user-unit state.
- `make reload-systemd` — daemon-reload ONLY (no enabling: `services-stop`
  and `restart` depend on it and must never start what they're stopping).
  `make services-check` — daemon-reload + `enable --now --no-block` all
  units in `service.order` (used by bootstrap). `make services-start`,
  `services-stop`, `restart` — confirm on an interactive terminal;
  non-interactive runs REQUIRE `YES=1` (nothing hangs on stdin).
  start/stop/restart share one `service-action` body. All service
  actions run `--no-block` and print a post-run state summary, so a
  headless session (check-x-server retries probe failures, herbst is
  gated by Requires= on it) never idles the make. `services-stop` disables by removing
  `default.target.wants` symlinks directly — do NOT use
  `systemctl --user disable` on dots units: the stow-created unit
  symlink in `~/.config/systemd/user` is a systemd `linked` unit file,
  and disable treats it as an undoable `systemctl link`, DELETING the
  unit file (systemd then falls back to distro units, e.g. the static
  dunst.service that ABRTs headless). Pending start/restart jobs are
  cancelled before stopping so stop never waits on a stuck start job.
  `check-x-server.service` carries StartLimitIntervalSec/Burst so a
  missing X server cannot spin its Restart=on-failure probe loop
  forever.
- `make update` — the safe pull directly in the repo: fetch +
  fast-forward (fallback `git pull --rebase --autostash`), submodule
  sync, then `on-deploy depends --install` — which rebuilds the
  on-deploy binary UNCONDITIONALLY as its first artifact, so a pulled
  submodule always lands a fresh binary.

## The per-package depends Makefile scheme (2026-11)

`on-deploy depends` drives EVERY stow package that ships
`dots/<pkg>/.local/state/depends/<pkg>.Makefile` — a package with
submodules owns ALL of its build/link/install recipes there:

- standard rules: `toolchain` (runs `on-deploy toolchain --<lang>`),
  `build` (compile, nothing placed), `link` (place the built binaries
  into `dots/<pkg>/.local/bin/` — the package owns its artifacts and
  stow ships them), `install` (source default; `PKG=true` = the
  platform package manager — the deploy target's `on-deploy pkg
  install <name>` for distro artifacts, the npm global rider for the
  JS artifacts), `uninstall`, `status`; start/stop/enable/disable are
  no-ops. Knobs: `FORCE=1` (redeploy), `DRY=1` (nothing changes),
  `M=` (explicit method, recorded).
- artifacts at `dots/<pkg>/.local/bin/` are gitignored (build
  products); the stow links at `~/.local/bin/` point AT the package
  copies — a legacy REGULAR file at a system path is swapped for the
  package link on first `stow -R` (see `stow-depends` in the depends
  Makefile). NOTE `~/.local/bin/install` is a SHARED TREE dir folded
  per-file from `dots/shell` AND `dots/depends` — treat it as normal
  stow folding, never as an artifact to swap/remove.
- the `depends` package hosts four bun submodules (on-deploy, herbstutil,
  herbctl, polyframes); `bat` hosts the rust one (`bat-src`, sharkdp/bat;
  legacy release-download method still reachable via `M=release`).
- the old per-package hook dirs `dots/<pkg>/.local/share/<pkg>/Makefile`
  are retired for packages with the scheme Makefile; pkgops/
  `on-deploy packages` still falls back to them for the rest (e.g.
  polybar's bar-control Makefile). The `components` script and
  `depends/.local/share/depends/Makefile` are DELETED — bun trust
  moved into the depends package Makefile (`trust-local`/
  `trust-global`), bun installation into `on-deploy toolchain --bun`,
  and installing bun when missing for the on-deploy build itself
  stays in the dots `_build-on-deploy`.

`~/.config/doftiles.conf` (stowed from `depends`) tracks the install
method per deployable (`POLYFRAMES_METHOD=source|npm|none`,
`BAT_METHOD=source|release|none`) — it lives
in the repo, so method changes show up as tracked diffs. conf-set
writes through the stow link (`sed --follow-symlinks` — plain
`sed -i` would replace the symlink with a regular file).

After changing anything in `services/`, restow and run
`systemctl --user daemon-reload` (or `make reload-systemd`), then restart
the relevant unit.

## Headless / non-interactive mode (2026-11)

- **`make update` is headless out of the box** (verified repeatedly on
  non-tty shells): every step is non-gated — the git pull falls back to
  `--rebase --autostash` (fails loudly on conflict, never hangs), the
  bun/npm builds are quiet, and `depends --install` has no TTY gates.
- **The deploy chain is headless with `YES=1`**
  (`make bootstrap toolchain deps install YES=1`): the knob feeds `-y`
  to the verbs whose installs may prompt (`toolchain` errors out
  "non-interactive without --yes" otherwise); `deps`/`depends
  --install` never confirm; `make install` gates nothing on a tty —
  the TUI wizard branch stays TTY-only (non-interactive runs keep the
  recorded config and apply it), preserve auto-keeps conflicts,
  per-package rules run straight.
- **The honest exception**: anything shelling through sudo or a
  platform `<target>.deploy` script needs passwordless sudo (or an
  interactive TTY) — inherent to system-package installation, not an
  on-deploy gate; failures exit loudly, no hangs.
- The TUI/session gates are the only real tty assumptions (bunli
  prompts hard-fail without one); every command has a non-tty fallback
  documented in its verb.

## Services / WM runtime model

- `check-x-server.service` (2026-11, `shell` package) runs FIRST and
  is the only place that resolves the X server: `on-deploy detect-server
  --persist-to-systemd` — the shared detectDisplay probe — sets
  `DISPLAY` in the systemd user manager environment. The wait-for-X
  loop that used to be herbst's `ExecStartPre` lives here as the
  on-failure Restart cycle (1s backoff, burst-capped to fail cleanly).
  Every WM unit is `After=`/`Requires=` it; the ordering is NOT
  transitive, so each unit names it explicitly.
- `herbst.service` starts herbstluftwm; DISPLAY is inherited from the
  manager env (no hardcoded display in any unit; `x11vnc` keeps a
  localhost:0.0 fallback for the standalone Xvfb profile).
- `compton.service` is `After=`/`BindsTo=` herbst — it starts with the WM
  and is killed when the WM stops (intentional).
- **Provided names** (2026-11): systemd has NO Requires=-through-Provides=
  resolution (verified on 259 — `Requires=<nonexistent>` is "Unit not
  found"), so "provides" is expressed with `[Install] Alias=`
  (display-manager.service pattern): `check-x-server` and `xvfb` both
  declare `Alias=x-server.service`, `herbst` declares
  `Alias=x-window-manager.service`; the ENABLED provider installs the
  alias symlink (`~/.config/systemd/user/<alias>` -> provider) and they
  must NOT be enabled together. Consumers require the symbolic name.
  Never `systemctl --user enable --force`-style over an alias, and
  never `reenable` stow-linked units (reenable = disable + enable, and
  disable deletes a linked unit file symlink — that destroyed stow
  links once already; use plain `enable`, which is idempotent and
  still processes `Alias=`).
- The WM session runs inside VcXsrv on Windows (WSL2); the autostart script
  is `herbst/.config/herbstluftwm/autostart`.
- `service.order` currently enables `check-x-server herbst dunst compton
  hc_send-error-daemon`; `xvfb`, `x11vnc` and `novnc` units exist for
  headless/VNC setups and are commented out in the order file.
- **xrdp layer on the nested profile** (2026-10): the `xrdp` FEATURE in
  `deploy.profile` provisions a system-level xrdp whose Xvnc
  module attaches to the running x11vnc framebuffer (`localhost:5900`) —
  an RDP client lands in the same shared Xvfb session noVNC serves, no
  per-connection session spawn. on-deploy installs the `xrdp` package,
  patches the distro's `/etc/xrdp/xrdp.ini` in place (Xvnc module port
  pinned to 5900, RDP listen port moved to **3390** — 3389 stays free
  for Windows' own RDP / netsh portproxy, Xvnc promoted to the first
  module slot, backup at
  `xrdp.ini.on-deploy.bak`) and `enable --now`es the unit (restart only
  when it was already active). xrdp is a SYSTEM service — it is NOT in
  `service.order` (user units only) and no dots unit exists for it; the
  config is provisioner-managed, not stowed (no `system-xrdp` package).

## Quirks and conventions established in this session

1. **DISPLAY comes from the manager env now** (2026-11). The single
   source of truth is `check-x-server.service` running
   `on-deploy detect-server --persist-to-systemd`; user units inherit
   DISPLAY from the systemd user manager, shells inherit it the usual
   way. Never hardcode `Environment=DISPLAY=...` in a unit again (it
   was DaemonCoupling pain: units pinned `localhost:0.0` while the
   server drifted to `:1.0`). Fallback convention if/when hardcoded
   fallbacks are unavoidable is `localhost:0.0` — never `127.0.0.1:0`
   (that regression already happened once across units, autostart, and
   the `herbst` helper scripts). `shell/.config/exports` sets no
   display at all; helper scripts use
   `DISPLAY=${DISPLAY:-localhost:0.0}`.
2. **Software GL is WSL-only**: `LIBGL_ALWAYS_INDIRECT` /
   `LIBGL_ALWAYS_SOFTWARE` live inside the `WS*` block of `exports`, not
   globally. Keep them scoped there.
3. **`hc_current` vs `hc_center`** (`herbst/.local/bin/`):
   - `hc_current [attr]` — prints `herbstclient attr clients.focus.$attr`
     (defaults to `winid`).
   - `hc_center` — centers the focused window inside
     `tags.focus.tiling.focused_frame.content_geometry`, resolving the
     window id and geometry via `hc_current`.
   - Client geometry attributes: `content_geometry` (read), `floating_geometry`
     (read/write — the one to set), `decoration_geometry` (read).
   - There was a stale duplicate `hc_center` in `compton/.config/compton/`;
     it was deleted. Helper scripts belong in the `herbst` package
     (`.local/bin`), not in `compton`.
4. **Credentials flow**: `~/.my-credentials` (name on line 1, email on
   line 2) is tracked in this repo on purpose — it is non-sensitive (name +
   email, the same as every commit author field) and is the shared source of
   truth for both the WSL host and the devcontainer. It must **stay
   tracked**; do not re-add it to `.gitignore`. The generated
   `~/.my-credentials-env` (GIT_NAME/GIT_EMAIL exports) is *not* tracked.
   `~/development/.devcontainer/update-dots.sh` reads
   `~/.my-credentials`, runs `git config --global`, and (re)generates
   `~/.my-credentials-env`, appending a guarded source line
   (`[ -f "$HOME/.my-credentials-env" ] && source ...`) to `.bashrc`/`.zshrc`.
   Its idempotency check is a substring grep on the fragment path — keep the
   source line compatible with that.
5. **`.zshrc` sources `$HOME/.my-credentials-env`** with an existence guard —
   never hardcode `/home/kine/...` paths; this repo must stay
   user/machine-agnostic.
6. **`shell/.profile`** pushes `PATH` (and `WSL_INTEROP` on WSL) into the
   systemd user manager. The `systemctl` calls are guarded by
   `command -v systemctl && systemctl --user` so non-systemd logins don't
   error. Keep new environment propagation inside that guard.
7. **`BROWSER="firefox"` is intentionally unqualified** in `exports`: the
   `shell` package stows `~/.local/bin/firefox` (a wrapper that execs
   Windows Firefox via `/mnt/c/...`). Since `~/.local/bin` is first on
   `PATH`, the bare name resolves to the wrapper when present and to a real
   Linux Firefox otherwise. Do not "fix" it to an absolute path.
   `$BROWSER` is **not enough** on its own: GUI apps open links via
   `xdg-open`, which ignores `$BROWSER` and follows XDG `.desktop`
   associations. The `shell` package also stows
   `~/.local/share/applications/firefox.desktop` (Exec=firefox) and
   `~/.config/mimeapps.list` must map `x-scheme-handler/http(s)` and
   `text/html` to `firefox.desktop`. Without this, xdg-mime falls back to
   scanning `/usr/share/applications` by `InitialPreference` and Chrome wins
   (it is also `x-www-browser` in the alternatives system). If links open in
   the wrong browser, run:
   `xdg-mime default firefox.desktop x-scheme-handler/http x-scheme-handler/https text/html`.
   Note `xdg-settings set default-web-browser` refuses to run while
   `$BROWSER` is exported — use `xdg-mime` directly.
   **The wrapper is deployed conditionally**: the `shell` post-stow hook
   (`scripts/deploy-menu.sh`) keeps the `~/.local/bin/firefox` link only
   while `/mnt/c/Program Files/Mozilla Firefox/firefox.exe` exists. On
   hosts without the exe (or without working interop) the stow link is
   pruned and the unqualified `BROWSER=firefox` resolves to a real Linux
   firefox if one is installed. The exact-duplicate `firefox-wrapper.sh`
   was removed — `firefox` is the single wrapper name.
8. **polybar warnings (known)**: `tray-position`/`tray-padding` in
   `polybar/.config/polybar/config.ini` are deprecated in favor of the
   dedicated tray module (polybar ≥ 3.6). Harmless for now.
9. **Files without trailing newlines** were normalized
   (`opencode.jsonc`, `shell/.config/aliases`, `shell/.profile`). Keep
   trailing newlines in new files to avoid noisy diffs.
10. **`llms/.config/opencode/opencode.jsonc`** intentionally has no
    `temperature`/`top_p` keys for the local Ollama provider — don't
    re-add them. `opencode.json` in the same directory is a **symlink to
    `opencode.jsonc`** (single source of truth; either filename loads) —
    edit the `.jsonc` only.
11. **`herbst/.config/herbstluftwm/autostart`** uses `hsetroot` (not
    `xsetroot`) for the background color.
12. **Avoid `awk` in shell scripts** (polywins.sh lesson). Inline awk
    one-liners inside pipelines caused three separate bugs here: wrong
    field indexes after a column was added, `\x` escapes not supported
    by mawk, and unportable constructs. Rules:
    - If complex string manipulation is genuinely needed, **prototype
      and test it in Node.js first**, then translate to simple POSIX sh.
    - In the actual scripts use only simple column-wise operations:
      `cut` to select columns, `grep -F` to filter rows, `printf` with
      explicit separators for joining/transforming/mapping rows.
    - `read` strips leading/trailing IFS-whitespace: with tab-separated
      fields, an EMPTY FIRST FIELD (e.g. root frame's empty index) is
      silently eaten and every column shifts. Either guarantee no field
      is ever empty (normalize at the source, e.g. empty frame index →
      `0`), or use a non-whitespace separator (`\x01`).
13. **Rofi dmenu gotchas** (window-switcher): icon placeholders render
    as gray squares unless `element-icon { size: 0; }` is set; pango
    `-markup` is unreliable in dmenu mode (prefer plain-text prefixes
    like `->`).
14. **Screencast task-tool completion signal** (opencode-screencast,
    developed in `~/development/system`): `run_task` sessions have
    been reported as `"state":"absent"` by `task_status` after
    spawning — task registration and end-of-command completion are
    not reliably signaled back to the agent, and a closed task window
    is indistinguishable from a never-started session. A fix is being
    developed (register sessions immediately, detect completion via
    tmux pane state / a sentinel instead of the window title, and
    report a distinct terminal state when the window is closed
    mid-run). Until it lands: when `task_status` returns `absent`,
    the task may still be running — re-check the floating terminal
    windows directly before re-spawning.
15. **Ollama `num_ctx` vs OpenCode `limit.context`**: a `limit.context` in
    `opencode.jsonc` is bookkeeping only — Ollama's runtime window stays at
    its default `num_ctx` unless the model tag sets it. Established pattern:
    create a `:<n>k` variant via `POST /api/create` with
    `parameters: {"num_ctx": ...}` (e.g. `glm-4.7-flash:32k`,
    `laguna-xs-2.1:32k` on ws-rarebox) and declare a matching model entry in
    `opencode.jsonc` with the same limit. The GLM-4.7-Flash MOE entry stays
    at its declared 96k by user choice.
16. **No Python in this repo**: the last python3 script
    (`polybar/.config/polybar/scripts/wm_icon_png`, an unwired
    `_NET_WM_ICON`→PNG helper) was deleted. If window icons are ever
    wanted, wire a helper into polywins explicitly instead of assuming one
    exists.
17. **herbstutil is a real global npm package** (used by
    `herbst/.local/bin/hlwm_cwds_dump` and the screencast plugin) — not
    junk. Its (and `bun`'s) postinstall may sit blocked under bun's default
    trust policy (`bun pm trust -g herbstutil bun` to allow).
18. **Submodule deploys live in the per-package depends Makefiles**
    (2026-11: replaces the old `on-deploy deps` — see the scheme
    section above). The polybar module is a standalone Bun/bunli
    binary built by `depends/.local/state/depends/depends.Makefile`
    from `dots/depends/.local/share/polyframes` into
    `dots/depends/.local/bin/polyframes` (stow ships it); its method
    is recorded in `~/.config/doftiles.conf`. `[module/polyframes]`
    in `config.ini` execs the binary directly — no shim, no nvm/Node
    dependency.
19. **rofi menus also moved into the polyframes binary** (2026-10):
    `rofi_tags`, `rofi_hidden`, `rofi_windows`, `rofi_launch`,
    `hc_switcher` and `hc_menu` were deleted from `herbst/.local/bin`
    and are now subcommands of `polyframes` (`tags`, `hidden`,
    `windows`, `launch`, `switcher-menu`, `window-menu`). The autostart
    keybinds call `polyframes tags|hidden|launch`; `hc_tile` and
    `hc_center` REMAIN in dots as two-line exec-shims delegating to
    `polyframes tile|center` (dots-side callers in hc_zoom/hc_focus/
    hc_full_focus/hc_unmaximize and the compton context menu depend on
    the untouched names). Window enumeration is pure hlwm
    (`herbstclient attr clients`), no xprop; JSON parsing is delegated
    to the herbstutil npm package (`parseAttr` imported directly, not
    its CLI).
20. **`polyframes spawn` = typed one-shot `hc rule once`** (2026-10):
    spawns a client detached after installing a single-use rule as
    typed flags (`--class`, `--instance`, `--title`, `--tag`,
    `--float on|off`, `--switchtag on|off`, `--focus`, `--center`).
    At least one criterion is required — a criterion-free rule would
    float the next attach of ANY class. hlwm 0.9.5 has no
    `floating=center` consequence, so `--center` floats+focuses the
    window and then centers it post-attach with decoration-aware
    geometry. Careful: bunli parses flag-like tokens even after `--`,
    so commands with flags go through `--cmd '<string>'` (shell-form)
    or a wrapper FILE, never raw dash tokens. `scripts/live.guard.sh`
    (repo) uses this for its xmessage confirmation dialog.
21. **`make deploy` runs the profile TUI first** (2026-10): on an
    interactive terminal, `scripts/deploy-menu.sh --profile` walks
    through distro target (wm.requires last line — pacman vs apt
    branches in on-deploy's provisioners), session model, features,
    units (universe = repo `*.service` files) and env lines, writes
    `deploy.profile`, then `make provision` runs before any stowing.
    Bypasses: `P="a b"` non-interactive, `PROFILE=skip`. The value
    sets mirror on-deploy's `src/lib/profile.ts` — keep them in sync.
    `depends/.local/bin/install/manjaro.deploy` is the pacman
    counterpart of `ubuntu.deploy` for the requirement walk
    (pacman -Fs resolution; needs `sudo pacman -Fy` on first run) —
    never tested on real pacman yet (no pacman on the WSL host).

## Quick verification workflow

```sh
cd ~/dots
make wm                  # stow herbst + alacritty + dunst + compton
make restart             # daemon-reload, restart service.order units
journalctl --user -u herbst.service -u compton.service -b --since "2 min ago" --no-pager
```

Known noise to ignore in the journal: polybar tray deprecation warnings and
arandr `gdk_atom_intern` assertion failures (upstream GTK quirk).
