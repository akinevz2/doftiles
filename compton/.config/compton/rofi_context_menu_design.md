# Herbstluftwm Right-Click Menu Design Document

## Overview
This document outlines a comprehensive right-click menu system for herbstluftwm window manager that uses rofi for interactive menu selection. The system provides quick access to all common window management operations through a mouse-driven interface.

## 1. Operation Categories & Commands

### 1.1 Window Management

| Operation | Command | Description |
|-----------|---------|-------------|
| Close Window | `close_or_remove` | Close the focused window gracefully |
| Delete Window | `close_or_remove; wmexec xkill` | Force kill window |
| Minimize | `toggle hidden` | Toggle window visibility (minimize/restore) |
| Maximize | `toggle fullscreen` | Toggle fullscreen mode |
| Minimize/Maximize | `chain . toggle fullscreen . focus --level=frame` | Quick toggle between fullscreen and normal |

### 1.2 Focus Management

| Operation | Command | Description |
|-----------|---------|-------------|
| Focus Left | `focus --level=visible left` | Cycle focus to window on the left |
| Focus Right | `focus --level=visible right` | Cycle focus to window on the right |
| Focus Up | `focus --level=visible up` | Cycle focus to window on top |
| Focus Down | `focus --level=visible down` | Cycle focus to window below |
| Focus Next | `cycle_all +1` | Move to next window in focus order |
| Focus Prev | `cycle_all -1` | Move to previous window in focus order |
| Focus Frame | `focus --level=frame` | Jump to frame containing window |
| Jump Urgent | `jumpto urgent` | Jump to urgent window |
| Next Tag | `shift_to_monitor +1` | Jump to next monitor tag |
| Prev Tag | `shift_to_monitor -1` | Jump to previous monitor tag |

### 1.3 Layout Operations

| Operation | Command | Description |
|-----------|---------|-------------|
| Toggle Float | `floating toggle` | Toggle window floating mode |
| Center Float | `chain ! lock . spawn ~/.local/bin/hc_center! unlock` | Center floating window |
| Pseudotile | `pseudotile toggle` | Enable/disable pseudotile behavior |
| Move Left | `shift left` | Move window left by one position |
| Move Right | `shift right` | Move window right by one position |
| Move Up | `shift up` | Move window up by one position |
| Move Down | `shift down` | Move window down by one position |
| Split Left | `split right; cycle_frame` | Split frame and cycle |
| Split Right | `split vertical; cycle_frame` | Add vertical split to right |
| Split Bottom | `split horizontal; cycle_frame` | Add horizontal split to bottom |
| Split Top | `chain split top 0.5 ; cycle_frame` | Add horizontal split to top |
| Split Auto | `split auto; cycle_frame` | Automatically detect split type |

### 1.4 Tag/Workspace Management

| Operation | Command | Description |
|-----------|---------|-------------|
| Move to Next Tag | `tag_move_nth -1` | Send window to previous tag |
| Move to Previous Tag | `tag_move_nth 1` | Send window to next tag |
| Move to Target Tag | `tag_move_nth #X` | Send to specific tag (requires rofi input) |
| Move All to Next Tag | `chain . lock . tag_move_nth -1 . unlock` | Move all windows to next tag |
| Move All to Previous Tag | `chain . lock . tag_move_nth 1 . unlock` | Move all windows to previous tag |
| Swap with Tag | `chain . lock . swap /tag_index. . unlock` | Swap windows with tag (requires input) |
| Toggle Monitors | `chain . lock . use_previous . unlock` | Toggle between monitors |

### 1.5 Process Control

| Operation | Command | Description |
|-----------|---------|-------------|
| Kill Process | `chain . lock . close_or_remove . spawn xkill . unlock` | Kill process and force remove |
| Restart WM | `reload` | Reload herbstluftwm configuration |
| Restart App | `chain . close_or_remove; spawn rofi_apps` | Restart current application |

### 1.6 Visual Operations

| Operation | Command | Description |
|-----------|---------|-------------|
| Screenshot | `spawn scrot` | Take screenshot of focused window |
| Color Picker | `spawn xcolor` | Choose color from window |
| Peek Layouts | `cycle_layout +1 grid max` | Cycle window layouts |
| Grid Layout | `cycle_layout grid` | Switch to grid layout |
| Max Layout | `cycle_layout max` | Switch to max layout |
| Vertical Layout | `cycle_layout vertical` | Switch to vertical layout |
| Horizontal Layout | `cycle_layout horizontal` | Switch to horizontal layout |
| Rotate Layout | `chain ! lock ! rotate ! rotate ! unlock` | Rotate window rotation |
| Flip Layout | `chain ! lock ! rotate ! unlock` | Flip window rotation |
| Center Window | `spawn ~/.local/bin/hc_center` | Helper script for centering |

### 1.7 Quick Actions

| Operation | Command | Description |
|-----------|---------|-------------|
| Hide Window | `chain . lock . hide . unlock` | Temporarily hide window |
| Show Hidden | `chain . lock . spawn ~/.local/bin/hc_hidden_list . unlock` | Show hidden windows |
| Cycle Frame | `cycle_frame` | Cycle to next frame |
| Lock Focus | `! attr clients.focus.client_floating` | Lock floating window |

## 2. Rofi Menu System

### 2.1 Menu Structure

```
┌─────────────────────────────────────┐
│  🪟 Window Management                │
│  ┌───────────────────────────────┐   │
│  │  🚪  Close Window             │   │
│  │  💀  Force Delete             │   │
│  │  💤  Minimize/Restore         │   │
│  │  ⛶  Maximize/Restore         │   │
│  └───────────────────────────────┘   │
├─────────────────────────────────────┤
│  👁️  Focus Management               │
│  ┌───────────────────────────────┐   │
│  │  ⬅️  Focus Left                │   │
│  │  ➡️  Focus Right               │   │
│  │  ⬆️  Focus Up                  │   │
│  │  ⬇️  Focus Down                │   │
│  │  🔜 Focus Next                │   │
│  │  🔙 Focus Prev                │   │
│  │  📍 Jump to Urgent             │   │
│  └───────────────────────────────┘   │
├─────────────────────────────────────┤
│  🏗️  Layout Operations              │
│  ┌───────────────────────────────┐   │
│  │  🎈 Toggle Float               │   │
│  │  ⏺️  Center Float              │   │
│  │  📐 Pseudotile                 │   │
│  │  🚚 Move Left/Right/Up/Down   │   │
│  │  ✂️  Split Left/Right/Top/Down│   │
│  │  🔧 Auto Split                │   │
│  └───────────────────────────────┘   │
├─────────────────────────────────────┤
│  📁 Tag/Workspace Management         │
│  ┌───────────────────────────────┐   │
│  │  ⏭️  Move to Prev Tag         │   │
│  │  ⏪  Move to Next Tag         │   │ │
│  │  📤 Move to Specific Tag      │   │ │
│  │  🔄 Swap with Tag             │   │ │
│  │  🌐 Toggle Monitors           │   │ │
│  └───────────────────────────────┘   │
├─────────────────────────────────────┤
│  ⚡ Process Control                  │
│  ┌───────────────────────────────┐   │
│  │  💣 Kill Process               │   │
│  │  🔄 Restart WM                │   │
│  │  ▶️ Restart App               │   │
│  └───────────────────────────────┘   │
├─────────────────────────────────────┤
│  🎨 Visual Operations                │
│  ┌───────────────────────────────┐   │
│  │  📸 Screenshot                 │   │
│  │  🎨 Color Picker              │   │
│  │  📊 Grid Layout               │   │
│  │  ⬛ Max Layout                │   │
│  │  📏 Vertical Layout           │   │
│  │  ↔️  Horizontal Layout         │   │
│  │  🔄 Rotate/Flip Layout        │   │
│  └───────────────────────────────┘   │
└─────────────────────────────────────┘
```

### 2.2 Rofi Theme Configuration

```rasi
* {
    font: "Segoe UI Light 11";
    background-color: #1a1a2e00;
    text-color: #ffffff;
    border-color: #666600ff;
    separator-color: #666600ff;
    listview: {
        columns: 2;
        lines: 10;
        spacing: 0px;
        scrollbar: true;
        fixed-height: false;
        expand: true;
        layout: vertical;
    };
    element-normal: {
        background-color: #2d2d4433;
        text-color: #ffffff;
        border: 1px solid #66660044;
    };
    element-alternate: {
        background-color: #33334422;
        text-color: #cccccccc;
    };
    element-selected: {
        background-color: #feef69ff;
        text-color: #1a1a2e00;
    };
    element-icon: {
        size: 16px;
    };
    element-text: {
        text-color: inherit;
    };
    window: {
        fullscreen: false;
        width: 600px;
        height: 700px;
        border-color: #666600ff;
        background-color: #1a1a2eaa;
    };
    scrollbar: {
        handle-width: 4px;
    };
    inputbar: {
    };
    message: {
        background-color: #666600ff;
        text-color: #1a1a2e00;
    };
    prompt: {
    };
    case-sensitive: false;
    separator: "╌";
}

@theme "dmenu"
```

### 2.3 Menu Launch Script

```bash
#!/bin/bash

# herbstluftwm context menu script
# Run with: herbstluftwm --context-menu

MOD="Mod1"  # Alt key
TERM="alacritty"
ROFITHEME="${HOME}/.config/rofi/launcher.rasi"
ROFIBIN="${HOME}/.local/bin/rofi_hc_context"

# Create main context menu
generate_menu() {
    cat <<EOF
🪟<b>Window Management</b>

🚪<b>Close Window       </b>close_or_remove
💀<b>Force Delete       </b>chain . lock . spawn xkill . unlock

👁️<b>Focus Management</b>

⬅️<b>Focus Left          </b>focus --level=visible left
➡️<b>Focus Right         </b>focus --level=visible right
⬆️<b>Focus Up           </b>focus --level=visible up
⬇️<b>Focus Down         </b>focus --level=visible down
🔍<b>Focus Next         </b>cycle_all +1
🔎<b>Focus Prev         </b>cycle_all -1
📍<b>Jump Urgent         </b>jumpto urgent

🏗️<b>Layout Operations</b>

🎈<b>Toggle Float        </b>floating toggle
⏺️<b>Center Float       </b>chain ! lock . spawn ~/.local/bin/hc_center . unlock
📐<b>Pseudotile        </b>pseudotile toggle
🚚<b>Move Left           </b>shift left
🚚<b>Move Right          </b>shift right
🚚<b>Move Up            </b>shift up
🚚<b>Move Down          </b>shift down
✂️<b>Split Left         </b>chain split right 0.5 . cycle_frame
✂️<b>Split Right        </b>chain split vertical . cycle_frame
✂️<b>Split Top          </b>chain split top 0.5 . cycle_frame
✂️<b>Split Bottom       </b>chain split horizontal . cycle_frame
🔧<b>Auto Split         </b>chain split auto . cycle_frame

📁<b>Tag/Workspace</b>

⏭️<b>Move to Prev Tag    </b>chain . lock . tag_move_nth -1 . unlock
⏪<b>Move to Next Tag   </b>chain . lock . tag_move_nth 1 . unlock
📤<b>Move to Specific    </b>chain . lock . spawn rofi_tags_move . unlock
🔄<b>Swap with Tag       </b>chain . lock . spawn rofi_tags_swap . unlock
🌐<b>Toggle Monitors    </b>chain . lock . use_previous . unlock

⚡<b>Process Control</b>

💣<b>Kill Process        </b>chain . lock . close_or_remove . spawn xkill . unlock
🔄<b>Restart WM          </b>reload
▶️<b>Restart App         </b>chain . close_or_remove . spawn rofi_apps

🎨<b>Visual Operations</b>

📸<b>Screenshot          </b>spawn scrot
🎨<b>Color Picker       </b>spawn xcolor
📊<b>Grid Layout        </b>cycle_layout grid
⬛<b>Max Layout         </b>cycle_layout max
📏<b>Vertical Layout    </b>cycle_layout vertical
↔️<b>Horizontal Layout  </b>cycle_layout horizontal
🔄<b>Rotate Layout      </b>chain ! lock ! rotate ! rotate ! unlock
EOF
}

# Parse and execute selected action
execute_action() {
    local action="$1"
    shift
    
    if [[ "$action" == "close_or_remove" ]]; then
        herbstclient close_or_remove
    elif [[ "$action" == "floating toggle" ]]; then
        herbstclient floating toggle
    elif [[ "$action" == "fullscreen toggle" ]]; then
        herbstclient fullscreen toggle
    elif [[ "$action" == "toggle hidden" ]]; then
        herbstclient toggle hidden || echo "Window not hidden"
    elif [[ "$action" == "jumpto urgent" ]]; then
        herbstclient jumpto urgent || echo "No urgent windows"
    elif [[ "$action" == "spawn scrot" ]]; then
        herbstclient spawn scrot
    elif [[ "$action" == "reload" ]]; then
        herbstclient reload
    elif [[ "$action" == "chain" && "$*" ]]; then
        herbstclient "$@"
    fi
    
    exit 0
}

# Main menu invocation
MENU=$(generate_menu)
COMMAND=$(echo "$MENU" | rofi -dmenu -i -p "📋 Herbstluftwm Actions:" -theme "$ROFITHEME")

# Parse the command
if [[ -n "$COMMAND" ]]; then
    if [[ "$COMMAND" =~ \] ]]; then
        # Simple command
        execute_action "$COMMAND" "$COMMAND"
    else
        # Chain command
        parts=($(echo "$COMMAND" | tr -s ' ' '\n' | grep -v '^$'))
        part_count=${#parts[@]}
        if [[ $part_count -ge 2 ]]; then
            execute_action "${parts[0]}" "${parts[@]}"
        fi
    fi
fi
```

## 3. Integration with Polybar Setup

### 3.1 Update Polybar Configuration

Add right-click bindings to your polybar configuration:

```bash
# In your polybar config file

# Example polybar context menu invocation
[module/window_manager]
type = custom/script
exec = echo "herbstluftwm" # or whatever identifies your setup
click-left = rofi_modi=windowcd -show windowcd

# Additional polybar shortcuts
[module/context_menu]
type = custom/script
exec = echo "📋"
click-left = herbstclient spawn ~/.local/bin/rofi_hc_context
click-right = herbstclient spawn ~/.local/bin/rofi_hc_context
```

### 3.2 Key Bindings in herbstluftwm Autoconf

Add bindings to your herbstluftwm autostart:

```bash
# Right-click menu bindings
keyreg $Mod-Button2         chain . lock . spawn ~/.local/bin/rofi_hc_context . unlock
keyreg $Mod-Button3         chain . lock . spawn ~/.local/bin/rofi_hc_context . unlock
```

### 3.3 Enhanced Functions

Create helper scripts for common actions:

**`~/.local/bin/hc_center`**
```bash
#!/bin/bash
WINDOW=$(herbstclient attr clients.focus.twin)
if [[ -z "$WINDOW" ]]; then
    WINDOW=$(herbstclient list_clients | head -1)
fi
FOCUSED=$(herbstclient dump | grep -f "$WINDOW")
if [[ -n "$FOCUSED" ]]; then
    herbstclient attr clients.$WINDOW.geometry "$(herbstclient attr clients.$WINDOW.geometry | awk "{print \$1\"x\"$4\"+\"($1+\$3/2)\")}"
fi
```

**`~/.local/bin/rofi_tags_move`**
```bash
#!/bin/bash
TAGS=($(herbstclient names | tr '\n' ' '))
TAGS+=("Cancel")
SELECTED=$(printf '%s\n' "${TAGS[@]}" | rofi -dmenu -i -p "Select Target Tag:")
if [[ -n "$SELECTED" ]] && [[ "$SELECTED" != "Cancel" ]]; then
    index=$(printf '%s\n' "${TAGS[@]}" | grep -n "$SELECTED" | cut -d: -f1)
    if [[ -n "$index" ]]; then
        herbstclient lock
        tag_move_nth "$((index - 1))"
        herbstclient unlock
    fi
fi
```

**`~/.local/bin/rofi_tags_swap`**
```bash
#!/bin/bash
TAGS=($(herbstclient names | tr '\n' ' '))
TAGS+=("Cancel")
SELECTED=$(printf '%s\n' "${TAGS[@]}" | rofi -dmenu -i -p "Select Tag to Swap:")
if [[ -n "$SELECTED" ]] && [[ "$SELECTED" != "Cancel" ]]; then
    index=$(printf '%s\n' "${TAGS[@]}" | grep -n "$SELECTED" | cut -d: -f1)
    if [[ -n "$index" ]]; then
        current_tag=$(herbstclient attr tags.focus.index)
        herbstclient lock
        swap "/tag/${index}"
        use "/tag/$current_tag"
        herbstclient unlock
    fi
fi
```

## 4. Keyboard Shortcuts for Quick Access

Add to herbstluftwm configuration:

```bash
# Quick menu toggles
keyreg $Mod-Button2         chain . lock . spawn rofi_hc_context . unlock
keyreg $Mod-Button3         chain . lock . spawn rofi_hc_context . unlock

# Direct menu selection
keyreg $Mod-Shift-Menu     herbstclient spawn rofi_hc_context

# Nested quick menus within main menu
M-C-a                      chain . lock . chain , spawn ~/.local/bin/rofi_tags_swap . chain . unlock
M-c                       chain . lock . chain , spawn rofi-hidden , chain . unlock
```

## 5. User Workflow Scenarios

### 5.1 Common Task: Minimizing a Window
1. Right-click on window title
2. Select "Minimize/Restore" from Focus Management section
3. Window disappears, can be restored via Mod-z or rofi hidden menu

### 5.2 Common Task: Moving to Different Workspace
1. Right-click on window title
2. Select "Move to Specific Tag" from Tag/Workspace section
3. Select target tag from rofi popup
4. Window now appears on selected workspace

### 5.3 Common Task: Quick Layout Adjustment
1. Right-click on window title
2. Select "Toggle Float" or "Pseudotile"
3. Immediate layout change without keyboard shortcuts

### 5.4 Common Task: Restarting a Crashed Application
1. Right-click on window title
2. Select "Restart App" from Process Control section
3. Window closes, rofi apps launcher opens for application selection

## 6. Maintenance & Customization

### 6.1 Menu Customization
- Add custom scripts for specific window classes
- Create per-application context menus using window class matching

### 6.2 Performance Optimization
- Cache rofi output for frequently used commands
- Optimize herbstclient command chains for speed

### 6.3 Testing Commands
- Test each command individually before adding to menu
- Use `herbstclient chain . lock . [command] . unlock` pattern for safe operations

## 7. Deployment Checklist

- [ ] Create `~/.local/bin/rofi_hc_context` script with executable permissions
- [ ] Create helper scripts (`hc_center`, `rofi_tags_move`, `rofi_tags_swap`)
- [ ] Add rofi theme configuration if not already present
- [ ] Add key bindings to herbstluftwm autostart
- [ ] Update polybar configuration if using
- [ ] Test menu with various mouse positions
- [ ] Verify keyboard shortcuts work correctly
- [ ] Test window management operations
- [ ] Test tag/workspace switching
- [ ] Verify visual operations behave as expected
- [ ] Customization: Add window class-specific menus

## 8. Future Enhancements

- [ ] Add search functionality for operations
- [ ] Create dynamic menu based on window properties
- [ ] Add configuration menu for global herbstluftwm settings
- [ ] Create session management operations (save/restore layouts)
- [ ] Add power management integration (suspend, hibernate, shutdown)
- [ ] Create application-launching shortcuts
- [ ] Add window snapping configurations menu
- [ ] Integrate with external tools (dunst, dunst-config, etc.)

## 9. Advanced Implementation Notes

### 9.1 Window Class Detection
```bash
WINDOW_CLASS=$(herbstclient attr clients.focus.client_class)
case $WINDOW_CLASS in
    "firefox") spawn ~/scripts/firefox_menu ;;
    "alacritty") spawn ~/scripts/terminal_menu ;;
esac
```

### 9.2 Dynamic Menu Generation
```bash
generate_window_specific_menu() {
    WINDOW_CLASS=$(herbstclient attr clients.focus.client_class)
    case $WINDOW_CLASS in
        "terminal") echo "Restart Terminal" ;;
        "browser") echo "Bookmark Current URL" ;;
    esac
}
```

### 9.3 Context-Aware Operations
```bash
# Only show maximize for tiled windows
is_tiled=$(herbstclient attr clients.focus.tiling)
if [[ "$is_tiled" == "1" ]]; then
    echo "Maximize" >> menu_text
fi

# Only show floating operations for floating windows
is_floating=$(herbstclient attr clients.focus.floating)
if [[ "$is_floating" == "1" ]]; then
    echo "Tile Window" >> menu_text
fi
```
