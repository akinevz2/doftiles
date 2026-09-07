# Right-Click Menu Configuration

This script contains all herbstluftwm key bindings for the context menu system.
Add these bindings to your herbstluftwm autostart configuration.

## Quick Integration

```bash
# Add these lines to your herbstluftwm/autoconf file
# These enable right-click menu access from anywhere

# Main context menu bindings
keyreg $Mod-Button2         chain . lock . spawn ~/.local/bin/rofi_hc_context . unlock
keyreg $Mod-Button3         chain . lock . spawn ~/.local/bin/rofi_hc_context . unlock

# Quick menu toggle
keyreg $Mod-Shift-Menu     herbstclient spawn rofi_hc_context

# Context menu for specific windows
keyreg $Mod-Button1 move   # Reserve left-click for window movement
```

## Keyboard Shortcuts Reference

**Mouse Bindings:**
- Alt+Button2 (Middle Click) or Alt+Button3 (Right Click): Open context menu

**Keyboard Shortcuts:**
- Shift+Menu (or similar): Toggle context menu

## Custom Window-Specific Bindings

For window class-specific actions:

```bash
# Terminal-specific shortcuts from context menu
keyreg $Mod-Alt-Return    spawn ~/.local/bin/terminal_restart

# Browser-specific shortcuts
keyreg $Mod-Alt-Tab        spawn ~/.local/bin/browser_open_bookmark

# Music player shortcuts
keyreg $Mod-Alt-p          spawn ~/.local/bin/music_player_controls
```

## Testing & Verification

Test each binding:
```bash
# Test main menu
herbstclient spawn rofi_hc_context

# Test bindings
herbstclient spawn "$Mod-Button2" ... # Syntax may vary
```

## Menu Customization

Modify `/home/kine/dots/compton/.config/rofi_hc_context` to add/remove operations based on your needs.

## Polybar Integration

Add to your polybar configuration for quick access:

```bash
# Example polybar context menu invocation
[module/context_menu]
type = custom/script
exec = echo "📋"
click-left = herbstclient spawn rofi_hc_context
click-right = herbstclient spawn rofi_hc_context
```