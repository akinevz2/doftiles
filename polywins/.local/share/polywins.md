# Polywins Specification

## Overview
Event-driven window switcher for herbstluftwm with polybar. Designed to provide Windows-like window management experience.

## Window Classification
- **Minimized window**: Hidden, should use `hc_show` to unhide and float
- **Hidden window (not minimized)**: Obscured by another window, should use `hc_show` to jump to
- **Floating window**: Should use `hc_show` to unfloat and unpseudotile
- **Visible window**: Rendered normally on screen

## Group Display
- Windows of the same class on one workspace are grouped together
- Display shows window **title**, not class name

## Styling Rules
- **Inactive window class group**: Text in darker gray (`#888888`)
- **Active window (focused)**: 
  - Text in `#eeeeee` (white)
  - Underline in `#FEEF69` (wm accent color)
- **Focused group**: Always has underline
- **Group with single visible window**: 
  - Underline only when window is **not** focused
  - No underline when window IS focused

## Event Actions

### Scroll Actions
- **Scroll down (A5)** over empty/no-visible groups → `rofi_tags`
- **Scroll up (A4)** over single visible group → `rofi_tags`
- **Scroll down (A5)** over group with visible windows → `minimize_window`

### Click Actions
- **Single window group**: `raise_or_minimize` (or use `hc_show`)
- **Multiple window group**: Show rofi window switcher filtered to class

## Implementation Details

### Using Herb Attributes
- Query client attributes: `herb attr clients.<winid>.<property>`
- Properties: `tag`, `minimized`, `floating`, `pseudotile`, `class`, `title`, `focus`
- Check current workspace: `herb attr tags.focus.name`

### Window Query Examples
```bash
herb attr clients.0x12345.tag
herb attr clients.0x12345.minimized
herb attr clients.0x12345.class
herb attr clients.0x12345.title
herb attr clients.0x12345.floating
herb attr clients.0x12345.pseudotile
herb attr tags.focus.name
```

### Herbswitch Hooks
Check herbstclient manual for hooks:
- `add_hook <client> <event>` - Register hooks for client events
- Events: `focus`, `unfocus`, `title_changed`, `mapped`, `unmapped`, `hidden`, `shown`
- Window workspace changes: `tag_changed`

## Scripts
- `herbst/.local/bin/hc_show` - Show window (handle minimized/hidden/floating cases)
- `herbst/.local/bin/hc_hide` - Minimize window
- `herbst/.local/bin/rofi_windows` - Window switcher script-mode backend
- `herbst/.local/bin/rofi_tags` - Workspace switcher

## File Paths
- Script: `/home/kine/dots/polybar/.config/polybar/scripts/polywins.sh`
- Scripts: `/home/kine/dots/herbst/.local/bin/`
- Theme: `/home/kine/dots/rofi/.config/rofi/`

## Development Notes
- polybar should read from: `/home/kine/dots/polybar/.config/polybar/scripts/polywins.sh`
- Should be symlinked to: `/home/kine/.config/polybar/scripts/polywins.sh`
- polybar polywin module should be configured to use the symlink