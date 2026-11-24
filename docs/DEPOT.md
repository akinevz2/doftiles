# depot — the system identity document

> SCAFFOLD: structure and verified facts only. Every `[prose: …]` marker is
> the author's to write — no marketing copy is invented here. The name
> `depot` is chosen (2026-11-24); note below on collisions.

## 1. What depot is

depot is the name for the whole system: this repository (`~/dots`) **plus
its submodules** — the collection of utilities it deploys and the deployer
that binds them.

[prose: the one-paragraph identity statement. The facts below are the
ground it must stand on; write it in your own voice.]

- **Thin deployed layer on top of an existing Linux operating system** —
  depot never installs an OS; it deploys onto whatever Linux the user
  already runs, currently proven on **Windows 11 WSL2 (Debian)** via
  X11/VcXsrv (`DISPLAY=localhost:0.0` convention).
- **Self-managing**: the deployed layer is deployed _by_ the layer's own
  tooling (`on-deploy`), stow packages with per-package Makefiles,
  idempotent re-runnable chain — `make bootstrap toolchain install`.
- **Unix composition, not a product**: the parts are independent
  utilities, each useful alone, bundled for convenience:
  | part                 | role                                                                                              | repo                |
  | -------------------- | ------------------------------------------------------------------------------------------------- | ------------------- |
  | `on-deploy`          | the deployer binary (checks, stowing, per-distro installers, manifests, services, state)          | akinevz2/on-deploy  |
  | `herbstutil`         | herbstclient `attr` as typed JSON (the "reading half")                                            | akinevz2/herbstutil |
  | `herbctl`            | imperative layer: every composite mod-binding as a `herbctl <verb>` subcommand (the "doing half") | akinevz2/herbctl    |
  | `polyframes`         | polybar frame module, rofi menus, frame surgery (native bun binary)                               | akinevz2/polyframes |
  | `got` (`got-source`) | file search (`get`)                                                                               | akinevz2/got-source |
  | `polytags`           | workspace/tag tooling                                                                             | akinevz2/polytags   |
- **Agentic harness ships in the layer**: the `opencode` stow package +
  skills (`operating-stow-directories`, `hlwm`, `hlwm-notifications`,
  `imagework`, …) mean a deployed depot maintains itself with an agent
  from day one — the agent story is infrastructure, not a bolt-on.

## 2. Positioning vs Omarchy

[prose: the framing paragraph. Omarchy sells a complete distribution
(Arch + userscript theming a Wayland environment, shortcut to an agentic
harness for userspace OS customisation). depot claims the category from
the other side: a deployable toolkit for OS-surface convenience that
respects the OS the user already has — integrators and developers adopt
piecewise, not wholesale.]

|             | Omarchy                                  | depot                                                                       |
| ----------- | ---------------------------------------- | --------------------------------------------------------------------------- |
| Base        | installs its own Arch Linux              | deploys onto your existing Linux                                            |
| Method      | one-shot userscript, opinionated product | stow packages + per-package Makefiles + a deployer; idempotent, re-runnable |
| Philosophy  | a finished desktop                       | independent Unix utilities that integrate; each useful alone                |
| Agent story | shortcut to install a harness            | the harness is part of the deployed layer                                   |
| Today       | mature, Wayland                          | works today in WSL2/Debian; feature set grows toward Omarchy's              |

## 3. WSL2 as the first-class story

[prose: why running _inside_ Windows 11 is the differentiator, not an
apology — no competing dotfiles distribution runs there; the VcXsrv/
`DISPLAY=localhost:0.0` convention; devcontainers as secondary consumers.]

## 4. Roadmap: toward Omarchy's feature set

[prose: honest gap list and growth intent. Known gaps: Wayland
(herbstluftwm is X11), one-command onboarding for a fresh machine,
upstream-distro breadth beyond Debian-family installers. Factual seeds:
`on-deploy` already walks per-distro installers (ubuntu.deploy,
manjaro.deploy); the stow chain is distro-portable by design.]

## 5. Where each README must carry the identity

- `~/dots/README.md` — the top section names the system and links DEPOT.md
  (author's rewrite; the current top section describes mechanics only)
- each submodule README opens with one sentence naming it a depot part
  (author's prose): on-deploy, herbstutil, herbctl, polyframes,
  got-source, polytags

## 6. Name note (collision, for the record)

"depot" collides with depot.dev (a Docker build-acceleration service) —
different space, but both developer-facing. Recorded here so the choice
is made with the collision visible, not discovered later.
