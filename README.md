# dots — GNU Stow dotfiles

Personal configuration repository managed with [GNU
Stow](https://www.gnu.org/software/stow/). Every top-level directory
with `.config`/`.local` content is a **stow package** whose contents
mirror `$HOME`. Repo-level files (`Makefile`, `README.md`,
`AGENTS.md`, `docs/`, `profiles/`, `scripts/`, `wm.packages`,
`wm.requires`, `service.order`) are **not** stowed.

**Deploy through Make, never bare stow.** The recipes wrap `stow -R
-t $HOME <package>` with hooks, service reloads and checks; running
`stow` by hand silently skips all of that.

Primary consumer: a WSL2 host (herbstluftwm + compton against the
Windows-side VcXsrv X server, `DISPLAY=localhost:0.0`). Agent
guidance lives in [AGENTS.md](AGENTS.md).

## Quick start

```bash
cd ~/dots
git submodule update --init --recursive
make install        # prompts for the deployment profile
```

`make install` (= `make bootstrap`) runs, in order: submodule sync,
stow of everything, the polyframes artifact deploy, the
binary-requirements walk, provisioning for the picked profile, the
systemd enable pass, and a status report.

## Deployment profiles

`profiles/<name>.profile` selects how the graphical session starts.
`make install` prompts (whiptail radiolist on a real terminal; the
choice is remembered in `~/.local/state/doftiles/profile`); override
any time with `make provision PROFILE=<name>`.

| Profile | Session | Runs |
| ------- | ------- | ---- |
| `wsl` | wsl-systemd | hlwm as the user unit `herbst.service` |
| `nested` | nested | hlwm inside Xvfb `:1`, browser via noVNC |
| `xinit` | xinit | startx + `~/.xinitrc`, no display manager |
| `greetd` | greetd | greetd + tuigreet own the console |

- **wsl** — the `herbst.service` user unit waits for the
  Windows-side VcXsrv X server on `:0`. Provision also checks
  `C:\Program Files\VcXsrv` and offers to download + silently
  install it from the SourceForge release feed.
- **nested** — the temporary profile, **co-installable** with a
  primary one: units enable additively and the displays never
  collide (`:1` vs `:0`). Browse in at `http://localhost:6081`.
- **xinit** — for bare-OS machines (the friend's arch box).
- **greetd** — hlwm picked from the greeter's session list.

A profile declares `session =`, `features =` (xserver xinitrc
greeter nested), `units =` (systemd user units, enabled additively)
and `env = KEY=VALUE` lines (written to `~/.config/doftiles/env`,
which the units read via `EnvironmentFile` — the profile DISPLAY
overrides the WSL hardcodes).

## Packages

| Package | Rough contents |
| ------- | -------------- |
| `herbstluftwm` | The WM stack, merged |
| `polybar` | Bar config + `polyctl`; polyframes renders it |
| `dunst` | Notification daemon config + mail scripts |
| `shell` | Shell dotfiles, hooks, `.my-credentials` |
| `agents` | OpenCode config + skills + MCP tooling |
| `depends` | Deploy scripts + the four submodules |

- **herbstluftwm** — autostart + the `keys.d/` fragments (nav,
  focus, floating), theme + `theme.d/` partials, `reload_theme`,
  `winbarctl`, the whole `hc_*`/`hlwm_*` helper suite, the systemd
  user units (herbst, herbst-nested, xvfb, x11vnc, novnc — plain
  and `-nested`, compton, dunst, hc_send-error-daemon) and the
  alacritty/compton/rofi configs.
- **polybar** — `config.ini` (+ polywins scripts), `polyctl`, the
  bar Makefile. The label renderer is the `polyframes` binary (a
  submodule under `depends/`, not part of this tree).
- **shell** — `.bashrcx`, `.profile`, `.zshrc`, `.vim`, `.taskrc`,
  `.my-credentials`, `Makefile`, `.config/{aliases,exports}`,
  `.local/bin` (install hooks, `adopt-these`, `load-credentials`,
  `check-wsl`, `check-msi-dirs`, the `firefox` wrapper) and the
  applications dir.
- **agents** — OpenCode config + skills, the `opencode-screencast`
  submodule, MCP tooling.
- **depends** — the `on.deploy` shim target, the deploy scripts
  (`ubuntu.deploy`, `arch.deploy`), `doftiles.conf`
  (install-method state) and the submodules: **polyframes** (the
  bar binary), **herbstutil** (the hlwm compatibility layer),
  **herbctl** (the keybind imperative verbs), **on-deploy** (the
  deployer itself).

`depends/.local/share/` submodules are synced to their remote tips
by every install.

## Required binaries

Toolchain: `git`, `make`, `stow`, `bash`, plus a systemd user
session for the service workflow. `wm.requires` line 1 lists the
WM-stack binaries; line 2 names the deploy target (`ubuntu`, `arch`,
...) selecting `~/.local/bin/install/<target>.deploy`. `make
add-packages` verifies them and maps any missing one to its package.

| Profile | Adds |
| ------- | ---- |
| `nested` | `xvfb`, `x11vnc`, `novnc` |
| `xinit`/`greetd` | the X server + xinit set (per target) |
| `greetd` | plus `greetd`; tuigreet via cargo |

## The Make targets

**Deployment**

- `make` — restow the **remembered subset**
  (`~/.local/state/doftiles/stowed`; every stow action records
  itself)
- `make all` — stow + hook every package
- `make deploy` — selective: whiptail checklist interactive, `P="pkg
  pkg"` fine-grained
- `make <pkg>` — stow + hook one package
- `make bootstrap` — the full single-call deployment (see Quick
  start)
- `make uninstall` — the reverse: disable every shipped unit, unstow
  everything, clear the state; installed binaries untouched
- `make clean` — unstow only (no unit changes)

**Inspection / maintenance**

- `make status` — binaries, packages, services, git state
- `make provision` — platform services for the picked profile
  (`PROFILE=<name>` overrides; `make help` lists all)
- `make restore-defaults` — stow the snapshotted pre-dots config
  back
- `make update` / `push` / `sync` — the safe git flow (fast-forward
  with a `--rebase --autostash` fallback, submodule sync, artifact
  refresh)

**Services**

- `make services-start | services-stop | restart` — operate the
  `service.order` units; `restart` prompts on a terminal,
  non-interactive runs need `YES=1`

## The defaults/ snapshot

Before a first deploy clobbers an existing machine's config, `make
bootstrap` runs `on-deploy snapshot`: every `$HOME` file a package
would replace that is **not** already dots-owned is copied into
`defaults/` — stow-shaped, versioned in git, NOT auto-stowed.
Restore the machine's original config with `make restore-defaults`;
re-snapshot any time with `on-deploy snapshot`.

## on-deploy

The deployer: a submodule under `depends/`, installed as
`~/.local/bin/on-deploy` (the dots `on.deploy` is a shim). It runs
inside the `~/dots` checkout and reads `wm.requires` +
`deploy.profile`. Verbs:

| Verb | Effect |
| ---- | ------ |
| `check` | Requirement report; exit 1 when missing |
| `deploy` | Install the missing binaries |
| `provision` | Platform services per profile |
| `snapshot` | Collect pre-existing config → defaults/ |
| `configure` | Edit target + package list (TUI/flags) |

`deploy` confirms per package (Enter = yes) and re-verifies after
each install; `--yes`/`--dry-run` available on deploy and provision,
`--json` on check. The full contract lives in the submodule's own
README.

## Secrets

Deploy-time secrets (`shell/.cache/sonarqube.env`, `*.admin`) are
gitignored and never tracked. `~/.my-credentials` (name + email
only) is tracked **on personal branches only** (kine) — `main`
gitignores it. `adopt-these` re-personalizes a fresh clone (new
branch + credentials).
