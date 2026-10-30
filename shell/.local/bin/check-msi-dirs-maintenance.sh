#!/bin/bash

_herbst_pid=$(pgrep herbstluftwm)
export DISPLAY=$(cat /proc/$_herbst_pid/environ | tr '\0' '\n' | grep ^DISPLAY= | cut -d= -f2-)
export DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$(id -u)/bus"
_show_notification() {
    local _mount="$1"
    local _found="$2"
    
    ACTION=$(notify-send -u critical -a "MSI Check" -t 0 \
        --action 'view-mail=View in terminal' \
        "MSI*.tmp detected on:$_mount" \
        "Found: $_found\n\nClick to view mail in terminal" \
        -i dialog-warning)
    
    echo ACTION $ACTION
    if [ "$ACTION" = "view-mail" ]; then
        if [ -x "$HOME/.local/bin/read-mail.sh" ]; then
            systemd-run --user --no-block \
                -E DISPLAY="$DISPLAY" \
                -E DBUS_SESSION_BUS_ADDRESS="$DBUS_SESSION_BUS_ADDRESS" \
                -E TERMINAL="$TERMINAL" \
                -E SHELL="$SHELL" \
                -- "$HOME/.local/bin/read-mail.sh"
        else
            notify-send -u critical -a "Mail" -t 5 "Cannot open mail viewer" "(read-mail.sh not found)"
        fi
    fi
}

if [ "$1" = "--notify" ]; then
    _show_notification "$2" "$3"
    exit 0
fi

for mount in /mnt/{c,d,e,f,g,h}; do
    found=$(find "$mount" -maxdepth 1 -name 'MSI*.tmp' -type d 2>/dev/null)
    if [ -n "$found" ]; then
        echo "$found" | mail -s "MSI*.tmp detected on $mount" "$USER"
        # _show_notification "$mount" "$found" &
        systemd-run --user --no-block \
            -E DISPLAY="$DISPLAY" \
            -E DBUS_SESSION_BUS_ADDRESS="$DBUS_SESSION_BUS_ADDRESS" \
            -- "$HOME/.local/bin/check-msi-dirs.sh" --notify "$mount" "$found"
    fi
done
