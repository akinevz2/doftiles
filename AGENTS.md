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
| `alacritty` | `.config/alacritty` |
| `compton` | `.config/compton` (compositor config plus rofi context-menu helpers) |
| `dunst` | `.config/dunst`, `.local/bin/check-mail.sh`, `read-mail.sh` |
| `git` | `.my-credentials` (git identity, name+email), `.local/bin/load-credentials`, `.local/bin/dekineify`, home-level `Makefile` (stowed as `~/Makefile`) |
| `herbst` | `.config/herbstluftwm`, `.local/bin/` (`hc_*` helpers — `hc_tile`/`hc_center` are shims to the compiled `polyframes` binary; the `rofi_*` menus and `hc_switcher`/`hc_menu` moved to `~/development/personal/polyframes`, `polyctl`, `winbarctl`, `hlwm_cwds_dump`, ...) |
| `llms` | `.config/opencode` (config, agents, skills, themes, `opencode-screencast` submodule), `.config/poolside`, `.local/bin/` (SonarQube/MCP tooling, `opencode-remote*`), `docker-compose.yml` |
| `maintenance` | `.config/systemd/user/check-msi-dirs.service`, `.local/bin/check-msi-dirs.sh` |
| `polybar` | `.config/polybar` (config.ini, scripts, `polywins` submodule), `.local/bin/` — `polyframes` moved out to `~/development/personal/polyframes` (compiled bunli/Bun binary, self-installed to `~/.local/bin`) |
| `rofi` | `.config/rofi` (themes, applets, ~40 `bin/` helpers) |
| `services` | `.config/systemd/user/*.service` (herbst, compton, dunst active; xvfb, x11vnc, novnc disabled) |
| `shell` | `.bashrcx`, `.profile`, `.aliases`, `.exports`, `.config/{aliases,exports,mimeapps.list}`, `.local/bin/` (install hooks, firefox wrapper, check-wsl), `.local/share/applications/` |
| `task` | `.taskrc` |
| `vim` | `.vim` |
| `zshell` | `.zshrc`, `.zprofile` |

There is no `.stow-local-ignore`; everything in a package is linked.
Repo-level files — `analysis.md`, `polywins.md`, `Makefile`, `README.md`,
`AGENTS.md`, `wm.packages`, `wm.requires`, `service.order`, `depends/`
(empty placeholder) — are **not** stowed (never put dotfiles at repo root —
they won't be linked). `git/Makefile` is the exception that *is* stowed
(it becomes `~/Makefile`).

## How stow linking works (and how to resolve files)

- `stow -R -t $HOME <pkg>` restows: removes existing links for the package
  and re-creates them. It does **not** delete real files in `$HOME`.
- **Resolution rule**: when you see a file at `~/.config/...` or
  `~/.local/bin/...`, its source lives in this repo under the package that
  contains `.config/...`/`.local/...` with the same relative path. To edit a
  live config, edit the repo file, not the symlink target in `$HOME`
  (they're the same inode for stowed links, but new files must be added in
  the repo and restowed).
- `~/.my-credentials -> dots/git/.my-credentials` is provided **by stow**
  (the `git` target). Do not create manual symlinks for files that are
  top-level entries of a stow package — stow handles them.
- Conflict caveat: if a real file already exists at the target path, stow
  fails. For `~/.bashrc` specifically, the distributed file is preserved via
  the `shell` package's `.bashrcx` + install hook instead of a direct link.

## Makefile targets

Package manifests live in repo-level files: `wm.packages` (WM stack list),
`wm.requires` (required binaries — the Makefile reads only its **first
line**; the second line `ubuntu` is a target-distro annotation),
`service.order` (unit start order). Known stale: `wm.packages` still lists
the pre-rename `opencode` package (now `llms`) and omits
`vim`/`zshell`/`maintenance` — stow those individually.

- `make bash` — metapackage: stow + post-stow hooks for `shell`, `git`,
  `llms`, `task`.
- `make git` — stow `git`, run `load-credentials` (sets global git identity
  from `~/.my-credentials`).
- `make llms`, `make task`, `make services` — stow the respective package.
- `make wm` — `herbst`: stow `herbst`, `alacritty`, `dunst`, `compton`; the
  `herbstluftwm` sub-target runs `herbstclient reload` after stowing. **No
  binary verification here** — that lives in `add-packages`.
- `make install` — `stow` (`bash` + `wm`) then `system`.
- `make add-packages` — runs `on.deploy`, then verifies every binary in
  `wm.requires`, failing fast listing missing ones (map binary → apt
  package with `~/.local/bin/install/ubuntu.deploy <binary>`).
- `make add-packages-system` — previews, then after confirmation
  `sudo stow -t /` any `system-*` packages; runs the service stack via
  `start-services`.
- `make status`, `services-available`, `services-installed` — report
  systemd user-unit state.
- `make reload-systemd`, `start-services`, `stop-services`,
  `restart-services` — restow `services`, daemon-reload, then
  start/stop/restart units in `service.order` order (start/stop/restart
  prompt for confirmation).
- `make update`, `push`, `sync` — safe git flow: fetch + fast-forward
  (fallback merge, `$EDITOR` on conflicts), stage/commit/push;
  `stow-wm` loops over `wm.packages`.

After changing anything in `services/`, restow and run
`systemctl --user daemon-reload` (or `make reload-systemd`), then restart
the relevant unit.

## Services / WM runtime model

- `herbst.service` starts herbstluftwm; `ExecStartPre` polls
  `xset -display localhost:0.0 q` until the X server is reachable.
- `compton.service` is `After=`/`BindsTo=` herbst — it starts with the WM
  and is killed when the WM stops (intentional).
- The WM session runs inside VcXsrv on Windows (WSL2); the autostart script
  is `herbst/.config/herbstluftwm/autostart`.
- `service.order` currently enables `herbst compton dunst`; `xvfb`, `x11vnc`
  and `novnc` units exist for headless/VNC setups and are commented out in
  the order file.

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
18. **polyframes lives outside this repo** (2026-10): the polybar module
    is a standalone Bun/bunli binary built from
    `~/development/personal/polyframes` (`make install` puts it in
    `~/.local/bin/polyframes`). `[module/polyframes]` in `config.ini`
    execs the binary directly; the Node renderer dir and the
    `polyframes.sh` shim were deleted from the `polybar` package.
    Click actions re-exec the binary itself — there is intentionally no
    shim and no nvm/Node dependency.
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

## Quick verification workflow

```sh
cd ~/dots
make wm                  # stow herbst + alacritty + dunst + compton
make restart-services    # restow services, daemon-reload, restart service.order units
journalctl --user -u herbst.service -u compton.service -b --since "2 min ago" --no-pager
```

Known noise to ignore in the journal: polybar tray deprecation warnings and
arandr `gdk_atom_intern` assertion failures (upstream GTK quirk).
