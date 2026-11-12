---
name: operating-stow-directories
description: Manages Stow-based dotfiles repository at ~/dots. Use ONLY when editing dotfiles, running make targets for deployment, or committing changes. Never edit $HOME config files directly—work in the corresponding package inside ~/dots. NEVER restart user services (would destroy session and chat).
---

# Operating Stow Directories

This skill provides instructions for working with the Stow-based dotfiles repository at `~/dots`.

## Repository Location

The dotfiles repository is at `/home/kine/dots`. This is the **source of truth** for all configuration files.

## File Resolution Rule

**NEVER edit files directly in your home directory** (e.g., `~/.config/*`, `~/.bashrc`, `~/.profile`).

Always edit files inside the package directory:
- Example: `~/.config/opencode/*` → `~/dots/opencode/.config/opencode/*`
- Stow creates symlinks from `~/dots/<package>/*` to `$HOME/*` with the prefix pattern
- The source is always in `~/dots/`; `$HOME` is just the target location

## Package Locations

| Package Directory | Purpose |
|--------------------|---------|
| `~/dots/shell/` | Shell configs (.bashrcx, .profile, .exports, .aliases) |
| `~/dots/herbst/` | herbstluftwm configuration and helper scripts |
| `~/dots/services/` | systemd user units (herbst.service, compton.service) |
| `~/dots/polybar/` | Status bar and desktop management scripts |
| `~/dots/rofi/` | Menu launcher (dmenu, window-switcher) |
| `~/dots/compton/` | Compositor configuration |
| `~/dots/dunst/` | Notifications and mail checking |
| `~/dots/alacritty/` | Terminal emulator |
| `~/dots/git/` | Git identity (name/email) and credential loader |
| `~/dots/opencode/` | opencode configuration files |
| `~/dots/vim/` | Vim configuration |
| `~/dots/zshell/` | Zsh with Oh-My-Zsh |

## Deployment Workflow

### When to run `make stow`

**Always run `make stow` when performing FILE-LEVEL operations** (creating, deleting, moving, or renaming files/folders). Symlinks do not update automatically for these changes.

**Do NOT run `make stow` for content-only changes** (editing existing file contents) since symlinks automatically pick up file changes.

### File-Level Operations (NEEDS `make stow`)

Creating, deleting, moving, or renaming files or directories in the source repository:

```bash
# Example: Create a new file in a package
touch ~/dots/herbst/.config/herbstluftwm/my-new-config

# Example: Move a file between packages
mv ~/dots/herbst/.config/herbstluftwm/file.txt ~/dots/dunst/.config/dunst/file.txt

# Example: Delete a file
rm ~/dots/shell/.bashrcx
```

After file-level operations:
```bash
cd ~/dots
make stow
```

### Content-Only Operations (NO `make stow` needed)

Editing existing file contents (config values, scripts, etc.):
```bash
# Example: Change a value in a config file
vim ~/dots/herbst/.config/herbstluftwm/autostart
# No 'make stow' needed - symlink updates automatically
```

### Make Targets

Target | Description |
|-------|-------------|
| `make bash` | Deploys shell package and runs bashrc install hook |
| `make wm` | Deploys WM stack (herbst, services, polybar, rofi, compton, dunst, alacritty) and validates required binaries |
| `make services` | Deploys services package and reloads systemd daemon |
| `make install` | Alias for `make bash` + `make opencode` |

### Verification

After deployment, verify symlinks point to the correct source:

```bash
ls -la ~/.config
```

Output should show files like:
- `aliases -> ../dots/shell/.config/aliases`
- `herbstluftwm -> ../dots/herbst/.config/herbstluftwm`

## Commit Strategy

**DO NOT commit changes unless explicitly requested**. When you do commit:
1. Keep commits as single, focused change sets
2. Each commit should represent a complete, logical feature addition
3. Avoid incremental/split commits for complex features

Example:
```bash
cd ~/dots
git add .
git commit -m "Add rofi window-switcher configuration"
```
