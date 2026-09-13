#!/bin/bash
# Show unread mail notification
# Uses dunst with infinite timeout (critical urgency)
# Click the notification to open terminal and view mail

mail_count=$(mail -H 2>/dev/null | wc -l | tr -d ' ')

if [ -n "$mail_count" ] && [ "$mail_count" -gt 0 ]; then
    notify-send -u critical -a "Mail" -t 0 \
        "Unread mail" \
        "You have $mail_count unread message(s)\nClick to view mail" -i mail
fi