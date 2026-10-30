# Herbstluftwm Context Menu System - Implementation Guide

## Quick Start
1. **Copy the scripts** from `/home/kine/dots/compton/.config/compton/` to your system
2. **Set executable permissions** on all scripts (`chmod +x`)
3. **Add bindings** to your herbstluftwm autostart configuration
4. **Test** the menu by triggering on window titles

## Files Created

### Main Components
- `rofi_context_menu_design.md` - Complete design documentation
- `rofi_hc_context` - Main context menu script
- `context_menu.rasi` - Rofi theme configuration
- `rofi_hc_context_bindings.sh` - Integration instructions
- `hc_center` - Helper script for centering windows
- `rofi_tags_move` - Tag management script
- `rofi_tags_swap` - Tag swap script

## Integration Steps

### Step 1: Install Required Scripts
```bash
# Copy scripts to your system
cp /home/kine/dots/compton/.config/compton/* ~/.local/bin/
chmod +x ~/.local/bin/{rofi_hc_context,hc_center,rofi_tags_move,rofi_tags_swap}

# Copy rofi theme
cp /home/kine/dots/compton/.config/compton/context_menu.rasi ~/.config/rofi/
```

### Step 2: Update herbstluftwm Configuration
Add these bindings to your `~/.config/herbstluftwm/autostart`:

```bash
# Window title right-click context menu
keyreg $Mod-Button2    chain . lock . spawn ~/.local/bin/rofi_hc_context . unlock
keyreg $Mod-Button3    chain . lock . spawn ~/.local/bin/rofi_hc_context . unlock

# Alternative keyboard shortcut
keyreg $Mod-Shift-Menu herbstclient spawn rofi_hc_context
```

### Step 3: Test the System
1. Restart herbstluftwm
2. Right-click on any window title
3. Select operation from the menu
4. Verify actions work as expected

## Menu Features

### Categories Available
- 🪟 Window Management (close, minimize, maximize)
- 👁️ Focus Management (quick focus navigation)
- 🏗️ Layout Operations (float, resize, move)
- 📁 Tag/Workspace Management (send to other workspaces)
- ⚡ Process Control (kill, restart)
- 🎨 Visual Operations (fullscreen, screenshots, layouts)

### Example Operations
```bash
🚪 Close Window
💀 Force Delete
⬅️ Focus Left
➡️ Focus Right
🎈 Toggle Float
📤 Move to Specific Tag
📸 Screenshot
🔄 Restart WM
```

## Customization Options

### Add Custom Operations
Edit `~/.local/bin/rofi_hc_context` and add your own commands:
```bash
🛠️<b>Your Custom Action</b> custom_command
```

### Window Class Detection
Create class-specific menus in `~/.local/bin/rofi_hc_context`:
```bash
case $WINDOW_CLASS in
    "firefox") 
        echo "🧹 Clear Cache" clear_firefox_cache
        echo "📚 Show Bookmarks" show_firefox_bookmarks
        ;;
    "alacritty")
        echo "💾 Save History" save_terminal_history
        ;;
esac
```

### Dynamic Menu Items
Add context-aware operations based on window state:
```bash
# Only show maximize for tiled windows
if [[ "$(herbstclient attr clients.focus.tiling)" == "1" ]]; then
    echo "⬛ Maximize" cycle_layout max
fi
```

## Additional Features

### Tag Management
- Move windows between workspaces
- Swap window positions with tags
- Quick tag cycling

### Process Control
- Graceful window closing
- Force kill options
- Application restart capability

### Visual Operations
- Fullscreen toggling
- Layout switching
- Window centering
- Screenshot capture

## Troubleshooting

### Menu Not Appearing
- Verify script permissions: `ls -la ~/.local/bin/rofi_hc_context`
- Check herbstluftwm is running: `herbstclient version`
- Test rofi: `rofi -theme /path/to/context_menu.rasi -dmenu`

### Commands Not Working
- Test commands individually: `herbstclient <command>`
- Verify herbstclient syntax matches your herbstluftwm version
- Check for spelling errors in commands

### Rofi Theme Issues
- Ensure `context_menu.rasi` is in correct location
- Check rofi installation: `rofi --version`
- Try default theme first: `rofi -dmenu`

## Advanced Setup

### Polybar Integration
Add to your polybar config for quick access:
```bash
[module/context_menu]
type = custom/script
exec = echo "📋"
click-left = herbstclient spawn rofi_hc_context
click-right = herbstclient spawn rofi_hc_context
```

### Mouse Bindings
Customize mouse button bindings in herbstluftwm:
```bash
# Map additional buttons
herb mousebind $Mod-Button4 call cycle +1
herb mousebind $Mod-Button5 call cycle -1
```

### Session Management
Add save/restore layout operations:
```bash
💾 Save Layout    spawn herbstclient dump > ~/.herbstluftwm/layouts/$(date +%s)
🔄 Restore Layout spawn herbstclient load "$(cat ~/.herbstluftwm/layouts/latest)"
```

## Documentation Reference
- Full design: `~/.local/share/rofi_context_menu_design.md`
- Commands reference: `herbstclient help` or `man herbstluftwm`
- Rofi documentation: `rofi -help`

## Support
- Test commands individually: `herbstclient <command> <args>`
- Debug menu: `echo "$MENU" | rofi -dmenu -p "Debug:"`
- Check herbstluftwm version: `herbstclient version`