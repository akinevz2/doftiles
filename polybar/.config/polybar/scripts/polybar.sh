#!/bin/sh
# polybar.sh - Main script to handle polybar IPC actions

ACTION="$1"
DATA="$2"

# Log action and data to file
echo "polybar.sh: ACTION=$ACTION, DATA=$DATA" >> /tmp/polybar_action.log

# Short-circuit and return early
exit 0