#!/usr/bin/env bash

battery_info() {
    BAT_PATH="/sys/class/power_supply/BAT1"
    if [ ! -d "$BAT_PATH" ]; then
        echo "N/A"
        return
    fi
    
    charge=$(cat "$BAT_PATH/charge_now" 2>/dev/null)
    capacity=$(cat "$BAT_PATH/capacity" 2>/dev/null)
    status=$(cat "$BAT_PATH/status" 2>/dev/null)
    adapter="/sys/class/power_supply/ACAD"
    is_charging="false"
    
    if [ -d "$adapter" ] && [ "$(cat "$adapter/online" 2>/dev/null)" = "1" ]; then
        is_charging="true"
    fi
    
    if [ -z "$capacity" ] || [ "$capacity" = "" ]; then
        capacity=$(cat "$BAT_PATH/energy_now" 2>/dev/null)
        total=$(cat "$BAT_PATH/energy_full" 2>/dev/null)
    fi
    
    if [ "$is_charging" = "true" ]; then
        echo "⚡ $capacity%"
    elif [ "$capacity" -gt 80 ]; then
        echo "🔋 $capacity%"
    elif [ "$capacity" -gt 40 ]; then
        echo "🔋 $capacity%"
    elif [ "$capacity" -gt 20 ]; then
        echo "🔋 $capacity%"
    else
        echo "🔋 $capacity%"
    fi
}

battery_info
