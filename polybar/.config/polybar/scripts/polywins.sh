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
resize_increment=16
wm_border_width=1 # setting this might be required for accurate resize position

# --- }}}


main() {
	# If no argument passed...
	if [ -z "$2" ]; then
		# ...print new window list every time
		# the active window changes or
		# a window is opened or closed
		xprop -root -spy _NET_CLIENT_LIST _NET_ACTIVE_WINDOW |
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

raise_or_minimize() {
	if [ "$(get_active_wid)" = "$1" ]; then
		wmctrl -ir "$1" -b toggle,hidden
	else
		wmctrl -ia "$1"
	fi
}

close() {
	wmctrl -ic "$1"
}

slop_resize() {
	wmctrl -ia "$1"
	wmctrl -ir "$1" -e "$(slop -f 0,%x,%y,%w,%h)"
}

increment_size() {
	while IFS="[ .]" read -r wid ws wx wy ww wh _; do
		test "$wid" != "$1" && continue
		x=$(( wx - wm_border_width * 2 - resize_increment / 2 ))
		y=$(( wy - wm_border_width * 2 - resize_increment / 2 ))
		w=$(( ww + resize_increment ))
		h=$(( wh + resize_increment ))
	done <<-EOF
	$(wmctrl -lG)
	EOF

	wmctrl -ir "$1" -e "0,$x,$y,$w,$h"
}

decrement_size() {
	while IFS="[ .]" read -r wid ws wx wy ww wh _; do
		test "$wid" != "$1" && continue
		x=$(( wx - wm_border_width * 2 + resize_increment / 2 ))
		y=$(( wy - wm_border_width * 2 + resize_increment / 2 ))
		w=$(( ww - resize_increment ))
		h=$(( wh - resize_increment ))
	done <<-EOF
	$(wmctrl -lG)
	EOF

	wmctrl -ir "$1" -e "0,$x,$y,$w,$h"
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
	active_wid=$(xprop -root _NET_ACTIVE_WINDOW)
	active_wid="${active_wid#*\# }"
	active_wid="${active_wid%,*}" # Necessary for XFCE
	while [ ${#active_wid} -lt 10 ]; do
		active_wid="0x0${active_wid#*x}"
	done
	echo "$active_wid"
}

get_active_workspace() {
	wmctrl -d |
		while IFS="[ .]" read -r number active_status _; do
			test "$active_status" = "*" && echo "$number" && break
		done
}

generate_window_list() {
	active_workspace=$(get_active_workspace)
	active_wid=$(get_active_wid)
	window_count=0
	on_click="$0"

	# Group windows by class: one entry per class, showing the title of
	# the group's active window (or its first window). Uses tab-separated
	# output: class \t wid \t is_active \t title
	grouped_windows=$(wmctrl -lx | awk -v ws="$active_workspace" -v act="$active_wid" '
		{
			wid = $1
			desk = $2
			# Don'"'"'t show the window if on another workspace (-1 = sticky)
			if (desk != ws && desk != "-1") next

			# wmctrl -lx layout: WID DESK CLASS.INSTANCE HOST TITLE...
			cls = $3
			sub(/\..*/, "", cls)

			title = ""
			for (i = 5; i <= NF; i++) title = title (i > 5 ? " " : "") $i

			if (!(cls in idx)) {
				idx[cls] = ++n
				classes[n] = cls
				gwid[n] = wid
				gtitle[n] = title
				gactive[n] = 0
				gcount[n] = 0
			}
			i = idx[cls]
			gcount[i]++
			# Prefer the active window'"'"'s title inside each class group
			if (tolower(wid) == tolower(act)) {
				gactive[i] = 1
				gwid[i] = wid
				gtitle[i] = title
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

		# Add separator unless the window is first in list
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
		printf "%s" "%{A3:$on_click slop_resize $wid:}"
		printf "%s" "%{A4:$on_click increment_size $wid:}"
		printf "%s" "%{A5:$on_click decrement_size $wid:}"
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
