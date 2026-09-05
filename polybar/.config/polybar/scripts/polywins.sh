#!/bin/sh
# POLYWINS

# SETTINGS {{{ ---

active_text_color="#eeeeee"
active_bg=
active_underline="#FEEF69"

inactive_text_color="#888888"
inactive_bg=
inactive_underline=

separator="·"
forbidden_classes="Polybar Conky Gmrun"
empty_desktop_message="Desktop"

char_limit=20
max_windows=15
char_case="normal"
add_spaces="true"

# --- }}}


herb() {
	herbstclient "$@"
}


main() {
	if [ -z "$2" ]; then
		xprop -root -spy _NET_CLIENT_LIST _NET_ACTIVE_WINDOW _NET_CURRENT_DESKTOP |
			while IFS= read -r _; do
				generate_window_list
			done

	else
		"$@"
	fi
}


# ON-CLICK FUNCTIONS {{{ ---

switcher() {
	rofi -modi windowcd -show windowcd \
		-theme ~/.config/rofi/window-switcher.rasi \
		-window-match-fields class \
		-filter "$1"
}

raise_or_minimize() {
	herb lock
	if [ "$(herb attr "clients.$1.minimized" 2>/dev/null)" = "true" ]; then
		herb jumpto "$1" 
		herb and , compare tags.focus.curframe_wcount lt 1 , attr clients.$1.floating false
	elif [ "$(herb attr "clients.$1.floating" 2>/dev/null)" = "true" ]; then
		herb attr "clients.$1.floating" false
	elif [ "$1" = "$(get_active_wid)" ]; then
		herb set_attr "clients.$1.floating" true
		herb set_attr "clients.$1.minimized" true
	else
		herb jumpto "$1"
		herb raise "$1"
	fi
	herb unlock
}

close() {
	wmctrl -ic "$1"
}

scroll_focus() {
	target=$(get_all_wids | awk -v act="$(get_active_wid)" -v dir="$1" '
		{ wids[++n] = $1 }
		$1 == act { pos = n }
		END {
			if (!n) exit
			if (!pos) pos = (dir == "up") ? n + 1 : 0
			pos += (dir == "up") ? -1 : 1
			if (pos < 1) pos = n
			if (pos > n) pos = 1
			print wids[pos]
		}')
	[ -n "$target" ] && herb jumpto "$target"
}

window_ops() {
	title=$(herb attr "clients.$1.title" 2>/dev/null)
	choice=$(printf 'Close\nFocus\nMinimize\nToggle floating\n' |
		rofi -dmenu -l 4 -theme ~/.config/rofi/window-ops.rasi -p "${title:-window}")
	case $choice in
		Close) close "$1" ;;
		Focus) herb attr "clients.$1.pseudotile" toggle 2>/dev/null ;;
		Minimize) herb attr "clients.$1.minimized" toggle 2>/dev/null ;;
		"Toggle floating") herb attr "clients.$1.floating" toggle 2>/dev/null ;;
	esac
}

# --- }}}



# WINDOW LIST SETUP {{{ ---

active_left="%{F$active_text_color}"
active_right="%{F-}"
inactive_left="%{F$inactive_text_color}"
inactive_right="%{F-}"
separator="%{F$inactive_text_color}$separator%{F-}"

if [ -n "$active_underline" ]; then
	active_left="${active_left}%{+u}%{u$active_underline}"
	active_right="%{-u}${active_right}"
fi

if [ -n "$active_bg" ]; then
	active_left="${active_left}%{B$active_bg}"
	active_right="%{B-}${active_right}"
fi

if [ -n "$inactive_underline" ]; then
	inactive_left="${inactive_left}%{+u}%{u$inactive_underline}"
	inactive_right="%{-u}${inactive_right}"
fi

if [ -n "$inactive_bg" ]; then
	inactive_left="${inactive_left}%{B$inactive_bg}"
	inactive_right="%{B-}${inactive_right}"
fi

get_active_wid() {
	herb attr clients.focus.winid 2>/dev/null
}

# Get all window IDs (for scroll_focus)
get_all_wids() {
	herbstclient list_clients --title --tag="$(herb attr tags.focus.name)" 2>/dev/null | \
		while read -r line; do
			[ -z "$line" ] && continue
			echo "${line%% *}"
		done
}

# Get frame indices from dump
get_frame_indices() {
	herbstclient dump 2>/dev/null | grep -o '\(clients max:[0-9]*' | \
		grep -oE '[0-9]+' | sort -n | uniq
}

# Get window info for a specific frame
get_frame_windows() {
	local frame_idx=$1
	herbstclient list_clients --frame="$frame_idx" --title --tag="$(herb attr tags.focus.name)" 2>/dev/null | \
		while read -r line; do
			[ -z "$line" ] && continue
			wid="${line%% *}"
			ttl="${line#* }"
			cls=$(herb attr "clients.$wid.class" 2>/dev/null)
			printf "%s\t%s\t%s\n" "$wid" "$ttl" "$cls"
		done
}

generate_window_list() {
	active_wid=$(get_active_wid)
	on_click="$0"

	# Get frame indices
	frame_indices=$(get_frame_indices)
	[ -z "$frame_indices" ] && {
		echo "$empty_desktop_message"
		return
	}

	# Process each frame
	first_frame=1
	window_count=0

	for frame_idx in $frame_indices; do
		# Get windows for this frame and group by class
		frame_groups=$(get_frame_windows "$frame_idx" | awk -F'\t' -v act="$active_wid" '
			{
				wid = $1
				ttl = $2
				cls = $3
				
				if (!(cls in first)) {
					first[cls] = wid
					titles[cls] = ttl
					count[cls] = 0
					classes[++n] = cls
				}
				count[cls]++
			}
			END {
				for (i = 1; i <= n; i++) {
					cls = classes[i]
					printf "%s\t%s\t%s\t%d\n", cls, first[cls], titles[cls], count[cls]
				}
			}')

		# Output frame separator
		if [ "$first_frame" -eq 0 ]; then
			printf " %{F#888888}│%{F-} "
		fi
		first_frame=0

		# Output grouped windows for this frame
		echo "$frame_groups" | while IFS=$'\t' read -r cls wid ttl cnt; do
			[ -z "$cls" ] && continue

			# Skip forbidden classes
			case "$forbidden_classes" in
				*$cls*) continue ;;
			esac

			# Truncate title
			w_name="${ttl:-$cls}"
			if [ "${#w_name}" -gt "$char_limit" ]; then
				w_name="$(echo "$w_name" | cut -c1-$((char_limit-1)))…"
			fi

			# Apply spacing
			if [ "$add_spaces" = "true" ]; then
				w_name=" $w_name "
			fi

			# Format with colors
			if [ "$wid" = "$active_wid" ]; then
				printf "%%{F$active_text_color}%%{+u}%%{u$active_underline}%s%%{-u}%%{F-}" "$w_name"
			else
				printf "%%{F$inactive_text_color}%s%%{F-}" "$w_name"
			fi

			window_count=$((window_count + 1))
		done
	done

	# Print newline
	echo ""
}

# --- }}}

main "$@"