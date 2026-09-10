#!/bin/sh
# POLYFRAMES — polybar window/frame module (polywins successor)
#
# With no arguments: print the polybar bar line and keep it updated
# (hlwm hook listener + frame-tree signature poll, like polywins).
#
# With arguments: dispatch to the on-click handlers living in
# ~/.local/bin (polyframes-switcher / polyframes-scroll), which rebuild
# the group themselves from the live WM on every invocation — the bar
# only carries the group's frame index + class as identifiers.

# Directory of the polyframes-* helper scripts (also on PATH).
PF="${HOME}/.local/bin"

# SETTINGS {{{ ---

# Window status colors (polybar):
#   visible (tiled, not focused) — bright gray
#   focused                      — bright gray + gold underline
#   floating                     — bright gray, no underline
#   not visible / minimized      — dark gray, no underline
visible_text_color="#eeeeee"
focused_text_color="#eeeeee"
floating_text_color="#eeeeee"
hidden_text_color="#888888"
focused_underline="#FEEF69"

separator="·"
forbidden_classes="Polybar Conky Gmrun"
empty_desktop_message="Desktop"

char_limit=20
max_windows=15
add_spaces="true"

# --- }}}

herb() {
	herbstclient "$@"
}

# Build the polybar format strings for one window state.
# Usage: format_for <text_color> <underline_color>
format_for() {
	left_fmt="%{F$1}"
	right_fmt="%{F-}"
	if [ -n "$2" ]; then
		left_fmt="${left_fmt}%{+u}%{u$2}"
		right_fmt="%{-u}${right_fmt}"
	fi
	printf "%s\t%s\n" "$left_fmt" "$right_fmt"
}

generate_window_list() {
	window_count=0
	on_click="$0"
	tab=$(printf '\t')
	sep="%{F$hidden_text_color}$separator%{F-}"

	# One tab-separated row per group from the shared grouping engine —
	# the exact same data the click/scroll handlers resolve. Fields:
	# frame \t class \t rep-wid \t is_active \t count \t title \t state
	while IFS="$tab" read -r frame cls wid is_active win_count title state; do
		# Skip malformed rows (a client that vanished mid-refresh)
		[ -z "$cls" ] || [ -z "$wid" ] && continue
		# Don't show the group if its class is forbidden
		case "$forbidden_classes" in
			*$cls*) continue ;;
		esac

		if [ "$window_count" -ge "$max_windows" ]; then
			window_count=$(( window_count + 1 ))
			continue
		fi

		# Display the group's title, falling back to the class
		w_name=${title:-$cls}

		# Truncate to the char limit
		if [ "${#w_name}" -gt "$char_limit" ]; then
			w_name="$(echo "$w_name" | cut -c1-$((char_limit-1)))…"
		fi
		if [ "$add_spaces" = "true" ]; then
			w_name=" $w_name "
		fi

		# Color by state. A FOCUSED window always gets the gold
		# underline, even when floating — the flt case only styles
		# unfocused floating windows.
		fmt=$(format_for "$focused_text_color" "$focused_underline")
		case "$state" in
			min)
				[ "$is_active" = "1" ] || fmt=$(format_for "$hidden_text_color" "") ;;
			flt)
				[ "$is_active" = "1" ] || fmt=$(format_for "$floating_text_color" "") ;;
			*)
				[ "$is_active" = "1" ] || fmt=$(format_for "$visible_text_color" "") ;;
		esac
		left_fmt=${fmt%%$tab*}
		right_fmt=${fmt#*$tab}
		w_name="${left_fmt}${w_name}${right_fmt}"

		if [ "$window_count" != 0 ]; then
			printf "%s" "$sep"
		fi

		# On-click actions. Left click: focus a lone window directly,
		# otherwise open the group switcher scoped to frame + class.
		if [ "$win_count" = "1" ]; then
			printf "%s" "%{A1:$on_click focus $wid:}"
		else
			printf "%s" "%{A1:$on_click switcher $frame \"$cls\":}"
		fi
		printf "%s" "%{A2:$on_click close $wid:}"
		printf "%s" "%{A3:$on_click window_ops $wid:}"
		printf "%s" "%{A4:$on_click scroll $frame \"$cls\" up:}"
		printf "%s" "%{A5:$on_click scroll $frame \"$cls\" down:}"
		printf "%s" "$w_name"
		printf "%s" "%{A}%{A}%{A}%{A}%{A}"

		window_count=$(( window_count + 1 ))
	done <<EOF
$("$PF/polyframes-groups")
EOF

	if [ "$window_count" -gt "$max_windows" ]; then
		printf "%s" "+$(( window_count - max_windows ))"
	fi
	if [ "$window_count" = 0 ]; then
		printf "%s" "$empty_desktop_message"
	fi
	echo ""
}

# Dispatch on-click actions to the helper scripts (or the few inline
# one-liners below).
case "$1" in
	"")
		# Bar mode + refresh loops (hooks + layout poll)
		generate_window_list
		(
			herbstclient --idle 2>/dev/null |
				while IFS= read -r hook; do
					case $hook in
						reload) kill "$$" 2>/dev/null ;;
						*) generate_window_list ;;
					esac
				done
		) &
		listener_pid=$!
		sig=""
		while :; do
			sleep 1
			new_sig=$(herbstclient dump 2>/dev/null | cksum)
			if [ "$new_sig" != "$sig" ]; then
				sig=$new_sig
				generate_window_list
			fi
		done &
		poll_pid=$!
		wait $poll_pid
		kill $listener_pid 2>/dev/null
		;;
	switcher)
		exec "$PF/polyframes-switcher" "$2" "$3" ;;
	scroll)
		exec "$PF/polyframes-scroll" "$2" "$3" "$4" ;;
	focus)
		exec "$PF/polyframes-toggle" "$2" ;;
	close)
		herbstclient close "$2" ;;
	window_ops)
		# rofi aborts on Wayland; the bar may carry WAYLAND_DISPLAY
		unset WAYLAND_DISPLAY
		title=$(herbstclient attr "clients.$2.title" 2>/dev/null)
		choice=$(printf 'Close\nFocus\nMinimize\nToggle floating\n' |
			rofi -dmenu -l 4 -theme ~/.config/rofi/window-ops.rasi -p "${title:-window}")
		case $choice in
			Close) herbstclient close "$2" ;;
			Focus) herbstclient attr "clients.$2.pseudotile" toggle 2>/dev/null ;;
			Minimize) herbstclient attr "clients.$2.minimized" toggle 2>/dev/null ;;
			"Toggle floating") herbstclient attr "clients.$2.floating" toggle 2>/dev/null ;;
		esac
		;;
esac
