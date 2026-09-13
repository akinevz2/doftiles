#!/bin/bash
# Spawn terminal with mail -p for reading mail
# Called as action from dunst notification

if command -v "$TERMINAL" >/dev/null 2>&1; then
    $TERMINAL -e mail -p
else
    mail -p 2>/dev/null || echo "No mail client available"
fi