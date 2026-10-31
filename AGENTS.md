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
`.local/bin/install/{ubuntu,manjaro}.deploy`, the polyframes submodule
at `.local/share/polyframes`, and `.config/doftiles.conf`
(deploy-method state, written by `on-deploy deps`) |
| `dunst` | `.config/dunst`, `.local/bin/check-mail.sh`, `read-mail.sh` |
| `agents` | `.config/opencode`, `.config/poolside`, `.local/bin`,
`.local/share` — OpenCode config (the `opencode-screencast` submodule
STAYS here: `opencode.json(c)` loads the plugin via the relative path
`./opencode-screencast`, so moving it would break plugin loading) |
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
- `make bootstrap` — full deployment in ONE call, safe on a systemd
  target with no running WM: stow everything (hooks no-op headless),
  run the toolchain assurances (`on-deploy toolchain` — bun via npm
  when missing, bun postinstall trust, herbctl binary; the former
  bun-toolchain/bun-trust/on-deploy-ensure/herbctl-ensure recipes are
  steps inside it now, with `_bootstrap-on-deploy` building the
  on-deploy binary itself when missing so the add-packages walk
  resolves), verify `wm.requires` binaries, daemon-reload +
  `enable --now` per `service.order` (units needing X stay
  enabled-but-failed until X exists), deploy the depends artifact (per
  the conf method, default source), status report, then install git
  credentials (`credentials` — reminder + skip when
  ~/.my-credentials is missing). `make install` is an alias.
- `make wm` — stow the stack from `wm.packages`; `make stow` is the
  same thing; `make bash` = `shell` + `agents` only.
- `make deps` — manifest existence check, then `make sync`.
- `make add-packages` — verifies every binary in `wm.requires`,
  failing fast listing missing ones; the `on.deploy` walk (which
  prompts per missing binary) runs only on an interactive terminal.
- `make add-packages-system` — previews, then after confirmation
  `sudo stow -t /` any `system-*` packages; interactive only (sudo
  needs a terminal); `YES=1` bypasses the confirmation.
- `make status`, `services-available`, `services-installed` — report
  systemd user-unit state.
- `make reload-systemd`, `services-start`, `services-stop`,
  `restart` — daemon-reload, then enable/start/stop/restart units in
  `service.order` order. Confirmations: interactive terminal prompts;
  non-interactive runs REQUIRE `YES=1` (nothing hangs on stdin).
  start/stop/restart share one `service-action` body.
- `make update` — the safe pull directly in the repo: fetch +
  fast-forward (fallback `git pull --rebase --autostash`), submodule
  sync, then `on-deploy deps --force` refreshes the polyframes
  artifact per the recorded method.
- `on-deploy deps` — the dependency deployment (was the deleted
  `depends/.local/share/doftiles/Makefile`): ensure (deploy only when
  missing, the install step), `--force` redeploy (the refresh flow),
  `--method source|npm|release` (explicit + recorded),
  `--uninstall` (removes the artifact per the recorded method,
  resets the conf). `source` = submodule checkout on `main` at the
  remote tip + `bun install` + the package's own make install — this
  advances the submodule past the recorded commit; commit the gitlink
  bump.

`~/.config/doftiles.conf` (stowed from `depends`) tracks the install
method per deployable (`POLYFRAMES_METHOD=source|npm|none`) — it lives
in the repo, so method changes show up as tracked diffs. conf-set
writes through the stow link (`sed --follow-symlinks` — plain
`sed -i` would replace the symlink with a regular file).

After changing anything in `services/`, restow and run
`systemctl --user daemon-reload` (or `make reload-systemd`), then restart
the relevant unit.

## Services / WM runtime model

- `herbst.service` starts herbstluftwm; `ExecStartPre` polls
  `xset -display localhost:0.0 q` until the X server is reachable,
  bounded at 30s (a headless `enable --now` fails cleanly instead of
  hanging the start job).
- `compton.service` is `After=`/`BindsTo=` herbst — it starts with the WM
  and is killed when the WM stops (intentional).
- The WM session runs inside VcXsrv on Windows (WSL2); the autostart script
  is `herbst/.config/herbstluftwm/autostart`.
- `service.order` currently enables `herbst compton dunst`; `xvfb`, `x11vnc`
  and `novnc` units exist for headless/VNC setups and are commented out in
  the order file.
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

1. **DISPLAY is `localhost:0.0` everywhere** (WSL2 convention). Do not
   reintroduce `127.0.0.1:0` — it appeared in the systemd units, the hlwm
   autostart, and the `herbst/.local/bin` helper scripts, and had to be
   unified. `shell/.config/exports` sets it only inside the
   `hostname == WS*` block; the helper scripts use
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
18. **polyframes deployment lives in `on-deploy deps`** (2026-10): the
    polybar module is a standalone Bun/bunli binary. The git
    submodule checkout is `dots/depends/.local/share/polyframes`
    (stowed to `~/.local/share/polyframes`); `on-deploy deps`
    (`--method source|npm|release`) builds/installs
    `~/.local/bin/polyframes` and records the method in
    `~/.config/doftiles.conf`. `[module/polyframes]` in `config.ini`
    execs the binary directly — no shim, no nvm/Node dependency.
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
