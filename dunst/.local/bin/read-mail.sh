#!/bin/bash
# Spawn terminal with mail -p for reading mail
# Called as action from dunst notification
# Uses herbstclient spawn to avoid X server issues

mail_content=$(mail -H 2>/dev/null)
if [ -z "$mail_content" ]; then
    notify-send -u low -a "Mail" "No mail to display"
    exit 0
fi

if command -v herbstclient >/dev/null 2>&1; then
    herbstclient spawn "$TERMINAL" -e "$SHELL" -c "mail -p; exec $SHELL -c mail"
elif command -v "$TERMINAL" >/dev/null 2>&1; then
    $TERMINAL -e "$SHELL" -c "mail -p; exec $SHELL -c mail"
else
    mail -p 2>/dev/null || echo "No mail client available"
fi
