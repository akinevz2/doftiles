# dots

dots is a GNU Stow–based dotfiles repository for a
[herbstluftwm](https://herbstluftwm.org)–centered Linux environment. The
system deploy — the `on-deploy` binary — is implemented in the
[on-deploy repository](https://github.com/akinevz2/on-deploy) (the deploy
tool's source and releases, checked out here as a submodule); this
repository is its **procedural specialiser**: the manifests, the
per-package Makefiles and the recorded configuration that turn the general
deployer into *this* system's deployment. The `Makefile` here is
delegation-only — every target is a short sequence of `on-deploy` commands,
except the bootstrap build of the binary itself, which cannot delegate to
anything before it exists.

- every top-level directory is a **stow package**: its contents mirror `$HOME`
  and are linked with `stow -R -t $HOME <package>` (similar to a plain stow
  repository, but nothing is run by hand — always through the Make recipes,
  which wrap restowing with hooks, conflict resolution and service reloads)
- repo-level files (`Makefile`, `README.md`, `AGENTS.md`, `docs/`, `scripts/`,
  `stow.depends`, `wm.depends`, `system.depends`) are **not** stowed
- the secrets produced at deploy time (`shell/.cache/*.env`) are gitignored;
  `~/.my-credentials` (name + email only) is tracked on purpose
- the primary consumers are a WSL2 host (herbstluftwm + compton against
  VcXsrv/X11; the `DISPLAY=localhost:0.0` convention holds everywhere) and
  devcontainers

## Deployment

The deployment is an explicit chain; each step is idempotent and safe to
re-run:

```bash
cd ~/dots
make bootstrap    # deploy on-deploy: submodule checkouts, the binary, stow depends, bun trust
make toolchain    # on-deploy toolchain --bun (or --rustup for the rust side)
make deps         # on-deploy depends --install: sync submodules, build, install
make install      # configure + preserve (conflict resolver) + per-package rules + status
```

`make update` is the safe pull of the repository itself (fetch + fast-forward,
submodule sync, then `on-deploy depends --install`, which rebuilds the
on-deploy binary unconditionally as its first artifact).

### The verbs

| Recipe           | Effect                                                                                       |
| ---------------- | -------------------------------------------------------------------------------------------- |
| `bootstrap`      | submodule checkouts tracking their upstream branches (`branch = main`/`master` in .gitmodules; bat and other nested assets are never chased per machine), the on-deploy binary when missing, `stow depends`, the bun-trust steps |
| `toolchain`      | `on-deploy toolchain --bun` — the language toolchains the per-package Makefiles build with (`YES=1` runs non-interactively; `on-deploy toolchain --check` fails fast, installing nothing) |
| `deps`           | `on-deploy depends --install` — sync the submodules and run each package's `build`→`install` rules (`--build` for install-less builds) |
| `install` / `wm` / `all` | configure, conflict-safe restow (`preserve --only $(stow.depends)`), the per-package rules, and `stow -R` of the `stow.depends` stack |
| `services-*`     | `services.depends` unit control via `on-deploy services` (`check`/`start`/`stop`/`restart`; non-interactive runs require `YES=1`) |
| `status`         | the `check` + `services status` + credentials reminder                                       |

## The per-package depends scheme

`on-deploy depends` drives every stow package that ships
`dots/<pkg>/.local/state/depends/<pkg>.Makefile`; the package owns ALL of its
build / link / install recipes there, so no package behavior is hardcoded into
on-deploy (`depends` discovers and delegates only):

- `toolchain` — `on-deploy toolchain --<lang>` (missing toolchains install
  through the platform package manager; `--check` fail-fasts with the
  "toolchain missing" message instead)
- `build` — compile from the submodule checkouts, placing nothing
- `link` — place the built binaries into `dots/<pkg>/.local/bin/` (the
  package owns its artifacts; a subsequent `stow -R` ships them into
  `~/.local/bin` and swaps legacy regular files for the package links)
- `install` — source by default (`PKG=true` routes through the platform
  package manager: `on-deploy pkg install <name>` for distro artifacts, the
  npm global rider for the JS artifacts); knobs: `FORCE=1`, `DRY=1`, `M=`
  (explicit method, recorded in `~/.config/doftiles.conf`)

## Packages

| Package        | Stows into `$HOME`                    | Contents                                                                                                          |
| -------------- | ------------------------------------- | ----------------------------------------------------------------------------------------------------------------- |
| `agents`       | `~/.local/bin` | OpenCode helper tools (`github-mcp-wrapper`, `opencode-remote(-add)`) |
| `opencode`     | `~/.config/opencode` | OpenCode configuration + the vendored `opencode-screencast` plugin; the CLI itself is the bun global `@opencode/cli` (registry metapackage) |
| `poolside`     | `~/.config/poolside` | poolside assistant configuration (its own package since the agents split) |
| `bat`          | —                                     | the rust package: the `sharkdp/bat` submodule (`bat/.local/share/bat-src`) and its per-package depends Makefile    |
| `compton`      | `~/.config/compton`, units            | compositor configuration and its user service                                                                     |
| `depends`      | `~/.local/bin/on.deploy`, `~/.local/bin/install/`, `~/.config/doftiles.conf` | the deployment machinery: the four bun submodules (`on-deploy`, `herbstutil`, `herbctl`, `polyframes`) at `.local/share/`, the per-package depends Makefile, the `on.deploy` shim and the `<target>.deploy` scripts |
| `dunst`        | `~/.config/dunst`, `~/.local/bin`     | notification daemon configuration; the mail scripts (`check-mail.sh`, `read-mail.sh`) and its user service         |
| `herbstluftwm` | `~/.config/{herbstluftwm,alacritty,rofi}`, `~/.local/bin` | the WM stack: the autostart, the theme (`reload_theme`, `winbarctl`), the whole `hc_*`/`hlwm_*` float + focus machinery, and its user services |
| `polybar`      | `~/.config/polybar`, `~/.local/bin`, `~/.local/share/polybar` | the bar (`config.ini`, `polybar.sh`, `polywins.sh`), the control scripts (`polyctl`, `ewmh_labels`) and the bar-control Makefile |
| `shell`        | `$HOME`                               | `.bashrcx` (sourced by the preserved `~/.bashrc`), `.profile`, `.aliases`, `.exports`, `.zshrc`, `.zprofile`, `.taskrc`, `~/.my-credentials`; the `firefox` wrapper (+ `.desktop` and `mimeapps.list`), `check-wsl`, and the `install/` hook scripts |
| `xrdp`, `xvfb`, `x11vnc`, `novnc` | user units         | individually deployable headless / VNC / RDP stacks (not in `stow.depends`; `systemctl --user` face only)          |

`stow.depends` lists the stow set of bulk targets; `wm.depends` the required
binaries plus the deploy target; `services.depends` the unit start order.

## Requirements

Building/deploying the repository needs `git`, `make`, GNU `stow`, `bash` and
systemd (user session). The WM stack binaries are manifested in `wm.depends`
(herbstluftwm, herbstclient, compton, polybar, rofi, hsetroot, xset, dunst,
notify-send): `on-deploy install` verifies each and installs the missing ones
through the `<target>.deploy` scripts. The language toolchains install through
the platform package manager when missing — bun through
`on-deploy toolchain --bun` and the rust toolchain through
`on-deploy toolchain --rustup`; `--check` verifies without installing.

For more, see [AGENTS.md](AGENTS.md) — the detailed agent-facing guide (the
package table, the service model, and the accumulated quirks) — and the misc
documentation in `docs/`.
