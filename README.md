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
make install      # configure + preserve (conflict resolver) + per-package rules + status
```

### The `make on-deploy` rule — the binary refresh

`make on-deploy` is the belt-and-braces step that guarantees the deployer
servicing the deployment is the freshest build of its own sources. It runs
three things in order:

```bash
make on-deploy
# 1. git submodule update --init --remote   ← syncs the on-deploy sources
# 2. make -C depends -f .local/share/depends/on-deploy/Makefile install
#      ├─ bun-ensure       (the bun toolchain, npm-bootstrapped when missing)
#      ├─ deps-install     (STALE-guarded: bun install)
#      ├─ compile          (STALE-guarded: bunli build → dist/on-deploy)
#      └─ stow -R on-deploy                    ← THE deploy step
# 3. re-ensures the package link pre-exists
```

The deployed command is a **live-by-reference symlink chain**:

```
~/.local/bin/on-deploy
  → ~/dots/on-deploy/.local/bin/on-deploy     (stow-owned link)
  → ../share/on-deploy/dist/on-deploy         (committed link)
  → the built binary itself
```

Because the chain resolves directly into `dist/`, the moment `bunli build`
writes a fresh binary the deployed command *is* that binary — the stow step
guarantees the link exists and is owned by the package. Freshness is the
`STALE` predicate: `src/` + `package.json` + `bunli.config.ts` vs
`dist/on-deploy` mtimes; the build is skipped when up to date:

```bash
make on-deploy          # rebuilds ONLY when sources are newer than dist
make on-deploy FORCE=1  # ignore mtimes, always rebuild (~1 min, 121M bundle)
make on-deploy DRY=1    # print what would run
```

`make install` and `make stow` both declare `on-deploy` as a prerequisite,
so the "latest on-deploy services the deployment" property holds even
without running it explicitly.

### Configuration — the user branch

Manifests (`stow.depends`, `wm.depends`, `system.depends`, `services.depends`)
and the deployment-method record (`depends/.config/doftiles.conf`) are
**tracked on a branch named after your unix username**. `main` carries the
generic content; a machine that personalizes lives on its own branch:

```bash
cd ~/dots
on-deploy configure          # edit the manifests (TUI or flags); every save is
                             # committed to the branch `kine` (id -un) automatically
git branch --show-current    # → kine (after the first personalization)
git push origin kine         # the user branch is pushed like any other
```

`make update` completes the model:

```bash
make update   # fetch, then:
              #   user branch exists → git rebase origin/main  (the machine's
              #     personalization replays on top of the latest mainline)
              #   no user branch     → plain mainline fast-forward
```

A rebase conflict is the only hand-intervention point: resolve the manifest,
`git rebase --continue`. There is no skip-worktree anywhere — the working
tree stays clean, and `git status` tells the truth.

### The verbs

| Recipe           | Effect                                                                                       |
| ---------------- | -------------------------------------------------------------------------------------------- |
| `bootstrap`      | submodule checkouts tracking their upstream branches (`branch = main` in .gitmodules), the on-deploy binary when missing, `stow depends`, the bun-trust steps |
| `on-deploy`      | sync the on-deploy sources, rebuild the binary when stale, deploy it via stow (see above) |
| `toolchain`      | `on-deploy toolchain --bun` — the language toolchains the per-package Makefiles build with (`YES=1` runs non-interactively; `on-deploy toolchain --check` fails fast, installing nothing) |
| `install` / `wm` / `all` | configure, conflict-safe restow (`preserve --only $(stow.depends)`), the per-package rules, and `stow -R` of the `stow.depends` stack |
| `update`         | safe pull: fetch, rebase the user branch onto `origin/main` (or fast-forward main), submodule sync + the bootstrap build |
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
- `install` — source by default; `pkg` routes through the package managers
  (the platform package manager for distro artifacts, the bun/npm registry
  for JS artifacts). The method is recorded per package in
  `~/.config/doftiles.conf` (`M=` overrides for one run); knobs: `FORCE=1`,
  `DRY=1`, `M=`

## Packages

| Package        | Stows into `$HOME`                    | Contents                                                                                                          |
| -------------- | ------------------------------------- | ----------------------------------------------------------------------------------------------------------------- |
| `agents`       | `~/.local/bin` | OpenCode helper tools (`github-mcp-wrapper`, `opencode-remote(-add)`) |
| `opencode`     | `~/.config/opencode` | OpenCode configuration + the vendored `opencode-screencast` plugin; the CLI itself is the bun global `@opencode/cli` (registry metapackage) |
| `poolside`     | `~/.config/poolside` | poolside assistant configuration (its own package since the agents split) |
| `bat`          | —                                     | pkg-only adapter: bat deploys through the system package manager (apt package `bat`, binary `batcat`, carried in `wm.depends`) — no sources, no toolchain |
| `compton`      | `~/.config/compton`, units            | compositor configuration and its user service                                                                     |
| `depends`      | `~/.local/bin/install/`, `~/.config/doftiles.conf` | the deployment machinery remnants: the four bun submodules (`on-deploy`, `herbstutil`, `herbctl`, `polyframes`) at `.local/share/`, the per-package depends Makefile and the `<target>.deploy` scripts |
| `dunst`        | `~/.config/dunst`, `~/.config/systemd` | notification daemon configuration and its user service                                          |
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
notify-send, jq, rg, fzf, gh, batcat, btop): `on-deploy install` verifies
each and installs the missing ones through the `<target>.deploy` scripts
(binary name → package resolved via the platform's package-manager search —
e.g. `batcat` resolves to the apt package `bat`). The language toolchains
install through the platform package manager when missing — bun through
`on-deploy toolchain --bun` and the rust toolchain through
`on-deploy toolchain --rustup`; `--check` verifies without installing.

For more, see [AGENTS.md](AGENTS.md) — the detailed agent-facing guide (the
package table, the service model, and the accumulated quirks) — and the misc
documentation in `docs/`.
