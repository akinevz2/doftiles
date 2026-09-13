#!/bin/bash
# Show unread mail notification
# Uses dunst with infinite timeout (critical urgency)
# Click the notification (or run read-mail.sh) to open terminal and view mail

if [ ! -f /var/mail/$USER ] && [ ! -f /var/spool/mail/$USER ]; then
    exit 0
fi

mail_content=$(mail -H 2>/dev/null)

if [ -z "$mail_content" ]; then
    exit 0
fi

mail_count=$(echo "$mail_content" | wc -l | tr -d ' ')
body="You have $mail_count unread message(s)"

if command -v notify-send >/dev/null 2>&1; then
    action=$(notify-send --action 'read-mail=View in terminal' \
        -u critical -a "Mail" -t 0 \
        "Unread mail" "$body" -i mail 2>/dev/null)
    
    if [ "$action" = "read-mail" ]; then
        if [ -x "$HOME/.local/bin/read-mail.sh" ]; then
            $HOME/.local/bin/read-mail.sh
        else
            notify-send -u critical -a "Mail" \
                "Error" "Could not find read-mail.sh"
        fi
    fi
fi

