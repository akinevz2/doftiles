#!/bin/bash
_show_notification() {
    local _mount="$1"
    local _found="$2"
    
    ACTION=$(notify-send -u critical -a "MSI Check" -t 0 \
        --action 'view-mail=View in terminal' \
        "MSI*.tmp detected on:$_mount" \
        "Found: $_found\n\nClick to view mail in terminal" \
        -i dialog-warning)
    
    if [ "$ACTION" = "view-mail" ] && [ -x "$HOME/.local/bin/read-mail.sh" ]; then
        $HOME/.local/bin/read-mail.sh
    else
        notify-send -u critical -a "Mail" -t 5 \
            "Cannot open mail viewer\n(read-mail.sh not found)"
    fi
}

for mount in /mnt/{c,d,e,f,g,h}; do
    found=$(find "$mount" -maxdepth 1 -name 'MSI*.tmp' -type d 2>/dev/null)
    if [ -n "$found" ]; then
        echo "$found" | mail -s "MSI*.tmp detected on $mount" "$USER"
        _show_notification "$mount" "$found" &
    fi
done
