#!/bin/bash
for mount in /mnt/{c,d,e,f,g,h}; do
    found=$(find "$mount" -maxdepth 1 -name 'MSI*.tmp' -type d 2>/dev/null)
    if [ -n "$found" ]; then
        echo "$found" | mail -s "MSI*.tmp detected on $mount" "$USER"
    fi
done