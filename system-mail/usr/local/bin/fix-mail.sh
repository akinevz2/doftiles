#!/bin/bash
# Fix mail setup after stow
# Postfix requires /var/mail/$USER to be a regular file, not a symlink

USER="${1:-$USER}"

if [ -z "$USER" ]; then
    echo "Usage: $0 [username]"
    exit 1
fi

MAIL_FILE="/var/mail/$USER"

if [ -L "$MAIL_FILE" ]; then
    echo "Removing symlink: $MAIL_FILE"
    sudo rm -f "$MAIL_FILE"
fi

if [ ! -f "$MAIL_FILE" ]; then
    echo "Creating mailbox file: $MAIL_FILE"
    sudo touch "$MAIL_FILE"
fi

echo "Setting ownership to $USER:mail"
sudo chown "$USER:mail" "$MAIL_FILE"

echo "Setting permissions to 660"
sudo chmod 660 "$MAIL_FILE"

echo "Mail setup complete for user: $USER"
ls -la "$MAIL_FILE"