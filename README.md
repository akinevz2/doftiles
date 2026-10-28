# dots — GNU Stow dotfiles

Personal configuration repository managed with [GNU Stow](https://www.gnu.org/software/stow/).
Every top-level directory is a **stow package** whose contents mirror `$HOME`; packages are
linked into place with `stow -R -t $HOME <package>`. Repo-level files (`Makefile`, `README.md`,
`AGENTS.md`, `analysis.md`, `polywins.md`, `wm.packages`, `wm.requires`, `service.order`,
`depends/`) are **not** stowed.

Primary consumers: a WSL2 host (herbstluftwm + compton against VcXsrv/X11, hostname `WS*`)
and devcontainers. Agent guidance lives in [AGENTS.md](AGENTS.md).

## Quick start

```bash
cd ~/dots
git submodule update --init --recursive   # polywins + opencode-screencast
make install                              # full WM host: shell, git, llms, task + WM stack
make bash                                 # headless / container: shell, git, llms, task only
```

## Packages provided

| Package | Stows into `$HOME` | Rough contents |
|---------|--------------------|----------------|
| `alacritty` | `~/.config/alacritty` | Terminal emulator config (`alacritty.toml`) |
| `compton` | `~/.config/compton` | Compositor config (`compton.conf`) plus rofi context-menu helpers (`context_menu.rasi`, `rofi_tags_move`, `rofi_tags_swap`, design docs) |
| `dunst` | `~/.config/dunst`, `~/.local/bin` | Notification daemon config; mail-notification scripts (`check-mail.sh`, `read-mail.sh`) |
| `git` | `~/.my-credentials`, `~/.local/bin`, `~/Makefile` | Tracked (intentionally non-sensitive) name/email credentials; `load-credentials` post-stow hook; `dekineify` (re-personalize the repo); home-level Makefile for multi-repo `pull`/`push`/`sync` |
| `herbst` | `~/.config/herbstluftwm`, `~/.local/bin` | WM autostart, `dunst_keybinds`, theme reload; ~40 helper scripts: `hc_*` window ops, `rofi_*` launchers/switchers, `hlwm_launch`, `polyctl`, `winbarctl`, `hlwm_cwds_dump` |
| `llms` | `~/.config/opencode`, `~/.config/poolside`, `~/.local/bin`, `~/.local/share` | OpenCode config (`opencode.jsonc` with `opencode.json` as a symlink to it, agents, skills, themes, `tui.json`, `opencode-screencast` submodule); poolside assistant config; SonarQube/MCP tooling, its `docker-compose.yml` and setup docs; `opencode-remote`/`opencode-remote-add` |
| `maintenance` | `~/.config/systemd/user`, `~/.local/bin` | `check-msi-dirs` oneshot unit + script (alerts on Windows temp dirs via dunst) |
| `polybar` | `~/.config/polybar`, `~/.local/bin` | `config.ini`; `scripts/polybar.sh`, `polywins.sh` (+ `polywins` submodule); `polyframes` Node.js frame-label renderer; `ewmh_labels`, `polyframes.sh` |
| `rofi` | `~/.config/rofi` | `config.rasi`, launcher/powermenu themes, applets, and ~40 `bin/` helper scripts (menus, launchers, powermenu) |
| `services` | `~/.config/systemd/user` | User units: `herbst`, `compton`, `dunst` (active in `service.order`) plus `xvfb`, `x11vnc`, `novnc` for headless/VNC setups (currently disabled) |
| `shell` | `$HOME` dotfiles | `.bashrcx` (sourced by the preserved `~/.bashrc`), `.profile`, `.aliases`, `.exports`, `.config/{aliases,exports,mimeapps.list}`; `~/.local/bin`: `firefox` wrapper (→ Windows Firefox), `check-wsl`, `green`/`yellow`; `~/.local/share/applications/firefox.desktop`; `.cache/` (gitignored SonarQube env/token) |
| `task` | `~/.taskrc` | Taskwarrior config |
| `vim` | `~/.vim` | Vim config (runtime state gitignored) |
| `zshell` | `~/.zshrc`, `~/.zprofile` | Oh My Zsh-based config, sources the generated credentials env |

`depends/` is an empty placeholder. `wm.packages` still lists the pre-rename `opencode`
package (now `llms`) and omits `vim`/`zshell`/`maintenance`; stow those individually.

## Required system binaries

### Toolchain (needed to install the repo at all)

| Binary | Ubuntu/Debian package | Purpose |
|--------|-----------------------|---------|
| `git` | `git` | Clone, submodules, `make update/push` |
| `make` | `make` | All deployment targets |
| `stow` | `stow` | Linking packages |
| `bash` | `bash` | Hooks and scripts (all scripts are bash/sh) |
| `systemctl` | `systemd` (user session) | Only for the `services`/WM workflow |

### WM stack — `wm.requires`, verified by `make add-packages`

| Binary | Ubuntu/Debian package |
|--------|-----------------------|
| `herbstluftwm`, `herbstclient` | `herbstluftwm` |
| `compton` | `compton` (or a picom build with compton syntax) |
| `polybar` | `polybar` |
| `rofi` | `rofi` |
| `hsetroot` | `hsetroot` |
| `xset` | `x11-xserver-utils` |
| `dunst` | `dunst` |
| `notify-send` | `libnotify-bin` |

### Per-package runtime binaries

| Binary | Package needed by | Ubuntu/Debian package |
|--------|-------------------|-----------------------|
| `alacritty` | alacritty | `alacritty` |
| `task` | task | `taskwarrior` |
| `zsh` (+ `~/.oh-my-zsh`) | zshell | `zsh` |
| `vim` | vim | `vim` |
| `node` ≥ 18, `npm` | llms (OpenCode, MCP tooling), polybar `polyframes` | `nodejs npm` |
| `bun` | llms (`opencode-remote-add`) | `bun` |
| `docker` + compose plugin | llms SonarQube stack | `docker.io docker-compose-v2` |
| `curl` | llms bootstrap | `curl` |
| `gh` | llms GitHub MCP token fallback (optional) | `gh` |
| `mail` | dunst mail scripts | `bsd-mailx` or `mailutils` |
| `xvfb`, `x11vnc`, `novnc` | disabled VNC service units (optional) | `xvfb x11vnc novnc` |

WSL2 hosts additionally need an X server on the Windows side (VcXsrv); the repo
convention is `DISPLAY=localhost:0.0` everywhere.

`make add-packages` checks the WM binaries and refuses to continue listing what is
missing; `~/.local/bin/install/ubuntu.deploy <binary>` maps a missing binary to the
apt package that provides it.

## Deployment-aid scripts

### Repo level — `Makefile`

- **Metapackages**: `bash` (shell, git, llms, task), `wm` → `herbst` (herbst, alacritty,
  dunst, compton), `stow` (bash + wm), `stow-wm` (loops `wm.packages`), `install`
  (stow + system checks), `depends` (manifest sanity + sync).
- **System wiring**: `add-packages` (post-stow hook + binary verification),
  `add-packages-system` (dry-run preview, then `sudo stow -t /` of any `system-*`
  packages after confirmation), `system`.
- **Service lifecycle**: `status`, `services-available`, `services-installed`,
  `reload-systemd`, `start-services`, `stop-services`, `restart-services` — driven by
  `service.order` (`herbst compton dunst`).
- **Repo maintenance**: `update` (safe pull: fast-forward, then merge, then editor on
  conflict), `push` (commit/push with editor staging), `sync` (update + push).
  `git/Makefile` (stowed as `~/Makefile`) orchestrates the same across the `dots` and
  `development` repos.

### Package-internal scripts

- **shell** — the deployment hooks:
  - `.local/bin/install/bashrc` — stow hook run by `make bash`; appends a source line to
    the distributed `~/.bashrc` instead of overwriting it.
  - `.local/bin/install/ubuntu.deploy` — resolves (or installs) the apt package providing
    a given binary.
  - `.local/bin/on.deploy` — preflight guard invoked by `make add-packages`.
  - `.local/bin/check-wsl`, `firefox` wrapper + `firefox.desktop` + `mimeapps.list` —
    WSL detection and browser/link plumbing.
- **git** — `load-credentials` (post-stow hook: sets global git identity from
  `~/.my-credentials` and generates the sourced credentials env), `dekineify` (adapt the
  repo for a new user/branch), home Makefile (see above).
- **llms** — `bootstrap-sonarqube.sh` (fresh instance → admin password → API token →
  gitignored env file), `sonarqube-mcp-manager` (compose stack lifecycle),
  `docker-compose.yml` (SonarQube + PostgreSQL + SonarQube-MCP), `sonarqube-mcp-wrapper`
  and `github-mcp-wrapper` (stdio MCP wrappers for OpenCode), `opencode-remote` /
  `opencode-remote-add` (inspect/add remote provider config).
- **maintenance** — `check-msi-dirs.sh` + its systemd oneshot unit (dunst alert with
  actionable click-through).
- **herbst / polybar / rofi / dunst** — WM *runtime* helpers rather than installers:
  the `hc_*` suite, `rofi_*` launchers, `polyctl`/`winbarctl`, polybar
  `polybar.sh`/`polywins.sh`/`polyframes`, dunst `check-mail.sh`/`read-mail.sh`.

Secrets produced at deploy time (`shell/.cache/sonarqube.env`, `*.admin`) are gitignored
and never tracked; `~/.my-credentials` (name + email only) is tracked on purpose.
