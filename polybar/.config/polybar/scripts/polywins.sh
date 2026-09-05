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
char_case="normal" # normal, upper, lower
add_spaces="true"

# --- }}}


herb() {
	herbstclient "$@"
}


main() {
	# If no argument passed...
	if [ -z "$2" ]; then
		# ...print new window list every time
		# the active window changes, a window is
		# opened/closed or the visible tag changes
		xprop -root -spy _NET_CLIENT_LIST _NET_ACTIVE_WINDOW _NET_CURRENT_DESKTOP |
			while IFS= read -r _; do
				generate_window_list
			done

	# If arguments are passed, run requested on-click function
	else
		"$@"
	fi
}



# ON-CLICK FUNCTIONS {{{ ---

# Open the rofi window switcher, filtered to the given window class
switcher() {
	rofi -modi windowcd -show windowcd \
		-theme ~/.config/rofi/window-switcher.rasi \
		-window-match-fields class \
		-filter "$1"
}

# Hide/unhide a window: unminimize if hidden,
# minimize if focused, otherwise just raise it
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

# Focus the previous/next window on the focused tag,
# including hidden (minimized) ones
scroll_focus() {
	target=$(list_clients | awk -v act="$(get_active_wid)" -v dir="$1" '
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

# Show a rofi menu with window operations, attached to the polybar
window_ops() {
	title=$(herb attr "clients.$1.title" 2>/dev/null)
	# No Maximize/fullscreen entry: hlwm hides the polybar when a
	# window is fullscreen; Focus (pseudotile toggle) instead
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

# Emit all windows on the focused tag (visible and hidden),
# one per line: winid \t class \t minimized \t title
list_clients() {
	current_tag=$(herb attr tags.focus.name) || return 1
	herbstclient list_clients --title --tag="$current_tag" 2>/dev/null | while read -r line; do
		[ -z "$line" ] && continue
		wid="${line%% *}"
		ttl="${line#* }"
		cls=$(herb attr "clients.$wid.class" 2>/dev/null)
		min=$(herb attr "clients.$wid.minimized" 2>/dev/null)
		printf "%s\t%s\t%s\t%s\n" "$wid" "$cls" "$min" "$ttl"
	done
}

generate_window_list() {
	active_wid=$(get_active_wid)
	window_count=0
	on_click="$0"

	# Group windows by class: one entry per class, showing the title of
	# the group active window (or its first window). Hidden windows on
	# the focused tag are included, so groups never lose track of them
	grouped_windows=$(list_clients | awk -F'\t' -v act="$active_wid" '
		{
			wid = $1
			cls = $2

			if (!(cls in idx)) {
				idx[cls] = ++n
				classes[n] = cls
				gwid[n] = wid
				gtitle[n] = $4
				gactive[n] = 0
				gcount[n] = 0
			}
			i = idx[cls]
			gcount[i]++
			# Prefer the title of the active window in each class group
			if (wid == act) {
				gactive[i] = 1
				gwid[i] = wid
				gtitle[i] = $4
			}
		}
		END {
			for (i = 1; i <= n; i++)
				printf "%s\t%s\t%d\t%d\t%s\n", classes[i], gwid[i], gactive[i], gcount[i], gtitle[i]
		}')

	# Format each window group one by one
	while IFS="	" read -r cls wid is_active win_count title; do
		# Don't show the group if its class is forbidden
		case "$forbidden_classes" in
			*$cls*) continue ;;
		esac

		# If max number of windows reached, just increment
		# the windows counter
		if [ "$window_count" -ge "$max_windows" ]; then
			window_count=$(( window_count + 1 ))
			continue
		fi

		# Display the group's window title, falling back to the class
		w_name=${title:-$cls}

		# Use user-selected character case
		case "$char_case" in
			"lower") w_name=$(
				echo "$w_name" | tr '[:upper:]' '[:lower:]'
				) ;;
			"upper") w_name=$(
				echo "$w_name" | tr '[:lower:]' '[:upper:]'
				) ;;
		esac

		# Truncate displayed name to user-selected limit
		if [ "${#w_name}" -gt "$char_limit" ]; then
			w_name="$(echo "$w_name" | cut -c1-$((char_limit-1)))…"
		fi

		# Apply add-spaces setting
		if [ "$add_spaces" = "true" ]; then
			w_name=" $w_name "
		fi

		# Add left and right formatting to displayed name
		if [ "$is_active" = "1" ]; then
			w_name="${active_left}${w_name}${active_right}"
		else
			w_name="${inactive_left}${w_name}${inactive_right}"
		fi

		# Add separator unless the group is first in list
		if [ "$window_count" != 0 ]; then
			printf "%s" "$separator"
		fi

		# Add on-click action Polybar formatting
		# Left click: switch straight to a lone window; otherwise open
		# the rofi switcher filtered to this window class
		if [ "$win_count" = "1" ]; then
			printf "%s" "%{A1:$on_click raise_or_minimize $wid:}"
		else
			printf "%s" "%{A1:$on_click switcher \"$cls\":}"
		fi
		printf "%s" "%{A2:$on_click close $wid:}"
		printf "%s" "%{A3:$on_click window_ops $wid:}"
		printf "%s" "%{A4:$on_click scroll_focus up:}"
		printf "%s" "%{A5:$on_click scroll_focus down:}"
		# Print the final window name
		printf "%s" "$w_name"
		printf "%s" "%{A}%{A}%{A}%{A}%{A}"

		window_count=$(( window_count + 1 ))
	done <<-EOF
	$grouped_windows
	EOF

	# After printing all the windows,
	# print number of hidden windows
	if [ "$window_count" -gt "$max_windows" ]; then
		printf "%s" "+$(( window_count - max_windows ))"
	fi

	# Print empty desktop message if no windows are open
	if [ "$window_count" = 0 ]; then
		printf "%s" "$empty_desktop_message"
	fi

	# Print newline
	echo ""
}

# --- }}}

main "$@"