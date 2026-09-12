# AGENTS.md — dots repository guidance

Guidance for AI coding agents working in this dotfiles repository.

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
| `compton` | `.config/compton` (compositor config only) |
| `dunst` | `.config/dunst` |
| `git` | `.my-credentials` (git identity, name+email), `.local/bin/load-credentials` |
| `herbst` | `.config/herbstluftwm`, `.local/bin/hc_*` helper scripts |
| `opencode` | `.config/opencode` |
| `polybar` | `.config/polybar`, `.local` |
| `rofi` | `.config/rofi` |
| `services` | `.config/systemd/user/*.service` (herbst, compton units) |
| `shell` | `.bashrcx`, `.profile`, `.aliases`, `.exports`, `.config/aliases`, `.local/bin/install/bashrc` |
| `vim` | `.vim` |
| `zshell` | `.zshrc`, `.zprofile` |

There is no `.stow-local-ignore`; everything in a package is linked.
`analysis.md`, `polywins.md`, `Makefile`, `README.md` and this file are
repo-level files, **not** stowed (never put dotfiles at repo root — they
won't be linked).

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

- `make bash` — stow `shell`, run the bashrc install hook.
- `make git`  — stow `git`, run `load-credentials` (sets global git identity
  from `~/.my-credentials`).
- `make opencode` — stow `opencode`.
- `make install` — `bash` + `opencode`.
- `make wm` — stow the full WM stack (`herbst services polybar rofi compton
  dunst alacritty`) after verifying required binaries
  (`herbstluftwm herbstclient compton polybar rofi hsetroot xset dunst`);
  runs `systemctl --user daemon-reload` at the end. Fails fast (Error 1)
  listing missing binaries. `WM_PACKAGES` and `WM_BINARIES` are maintained
  together at the top of the target — update both when adding/removing a
  package.

After changing anything in `services/`, restow and run
`systemctl --user daemon-reload`, then restart the relevant unit.

## Services / WM runtime model

- `herbst.service` starts herbstluftwm; `ExecStartPre` polls
  `xset -display localhost:0.0 q` until the X server is reachable.
- `compton.service` is `After=`/`BindsTo=` herbst — it starts with the WM
  and is killed when the WM stops (intentional).
- The WM session runs inside VcXsrv on Windows (WSL2); the autostart script
  is `herbst/.config/herbstluftwm/autostart`.

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
8. **polybar warnings (known)**: `tray-position`/`tray-padding` in
   `polybar/.config/polybar/config.ini` are deprecated in favor of the
   dedicated tray module (polybar ≥ 3.6). Harmless for now.
9. **Files without trailing newlines** were normalized
   (`opencode.jsonc`, `shell/.config/aliases`, `shell/.profile`). Keep
   trailing newlines in new files to avoid noisy diffs.
10. **`opencode/.config/opencode/opencode.jsonc`** intentionally has no
    `temperature`/`top_p` keys for the local Ollama provider — don't
    re-add them.
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

## Quick verification workflow

```sh
cd ~/dots
make wm            # stow WM stack + binary checks + daemon-reload
systemctl --user restart herbst.service compton.service
journalctl --user -u herbst.service -u compton.service -b --since "2 min ago" --no-pager
```

Known noise to ignore in the journal: polybar tray deprecation warnings and
arandr `gdk_atom_intern` assertion failures (upstream GTK quirk).
