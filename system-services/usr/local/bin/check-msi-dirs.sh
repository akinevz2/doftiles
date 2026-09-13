#!/bin/bash
_show_notification() {
    local _mount="$1"
    local _found="$2"
    
    notify-send -u critical -a "MSI Check" -t 0 \
        "MSI*.tmp detected on:\n$_mount" \
        "Found: $_found\n\nClick to view mail in terminal" \
        -i dialog-warning
}

for mount in /mnt/{c,d,e,f,g,h}; do
    found=$(find "$mount" -maxdepth 1 -name 'MSI*.tmp' -type d 2>/dev/null)
    if [ -n "$found" ]; then
        echo "$found" | mail -s "MSI*.tmp detected on $mount" "$USER"
        _show_notification "$mount" "$found"
    fi
done