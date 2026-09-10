#!/bin/sh
# POLYWINS

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
focused_bg=
floating_underline=

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

# Directory of the modular hc_get-* helper scripts (also on PATH).
HC_GET="${HOME}/.local/bin"


main() {
	# If no argument passed...
	if [ -z "$2" ]; then
		generate_window_list

		# Refresh on hlwm hooks: instant updates for client focus,
		# titles, tags, urgent state etc. Frame splits/removals emit
		# no hook in hlwm 0.9.5, so the poll loop below covers those.
		(
			herbstclient --idle 2>/dev/null |
				while IFS= read -r hook; do
					case $hook in
						quit_panel) pkill -P "$$" polybar 2>/dev/null ;;
						reload) kill "$$" 2>/dev/null ;;
						*) generate_window_list ;;
					esac
				done
		) &
		listener_pid=$!

		# Layout poll: regenerate only when the frame tree signature
		# changes (split, remove, resize, layout change). Cheap — the
		# dump is tiny and hashed, not parsed.
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

		# wait on the poll loop; hook listener ends with us
		wait $poll_pid
		kill $listener_pid 2>/dev/null

	# If arguments are passed, run requested on-click function
	else
		"$@"
	fi
}



# ON-CLICK FUNCTIONS {{{ ---

# Shared group source of truth. Both the click handler (switcher) and
# the scroll handler (scroll_focus) rebuild the group through this
# function on EVERY invocation, so they always operate on the same,
# freshly-queried data. Usage: frame_clients <frame> <class>
# Prints the hc_get-clients rows (wid \t class \t minimized \t title
# \t floating \t frame) of the group in WM order — the order hc
# list_clients reports, unsorted. The frame index comes straight from
# the bar entry ("" normalized to 0 there), so empty frame indexes are
# already handled before we get here.
frame_clients() {
	frame=$1
	cls=$2
	while IFS="$(printf '\t')" read -r wid c min ttl flt f; do
		[ -z "$wid" ] || [ -z "$c" ] && continue
		[ "$c" = "$cls" ] || continue
		[ "$f" = "$frame" ] || continue
		printf "%s\t%s\t%s\t%s\t%s\t%s\n" "$wid" "$c" "$min" "$ttl" "$flt" "$f"
	done <<EOF
$(list_clients)
EOF
}

# Open a rofi switcher containing only the windows of one group,
# identified by frame index + class. Selecting an entry focuses that
# window (jumpto + raise only — no minimize/toggle semantics).
switcher() {
	frame=$1
	cls=$2
	tab=$(printf '\t')
	# \x01 pair separator between display string and wid in $pairs
	us=$(printf '\001')
	# Vertical list of the group's windows, rebuilt fresh via
	# frame_clients (same source as scroll_focus). Display strings are
	# the titles plus a [min]/[flt] state tag when needed; duplicates
	# get a " ·N" suffix so each display maps to exactly one wid
	# (plain grep -F matching, no awk).
	wids=
	pairs=
	count=0
	while IFS="$tab" read -r wid c min ttl flt f; do
		if [ "$min" = "true" ]; then
			ind=" [min]"
		elif [ "$flt" = "true" ]; then
			ind=" [flt]"
		else
			ind=""
		fi
		disp=${ttl:-$cls}$ind
		# disambiguate duplicate titles: " ·2", " ·3", ...
		n=2
		while printf "%s" "$pairs" | grep -Fq "$disp$us"; do
			disp="${ttl:-$cls}$ind ·$n"
			n=$(( n + 1 ))
		done
		count=$(( count + 1 ))
		wids="$wids $wid"
		pairs="$pairs$(printf "%s%s%s\n" "$disp" "$us" "$wid")"
	done <<EOF
$(frame_clients "$frame" "$cls")
EOF
	[ -z "$wids" ] && return 0
        # Pre-select the focused window's row: its line number in the
        # pairs stream (grep -n on the wid field) minus one.
        active_wid=$(get_active_wid)
        sel_row=$(printf "%s" "$pairs" |
                grep -nF "$us$active_wid" | cut -d: -f1)
        sel_row=${sel_row:-0}
        sel_row=$(( sel_row - 1 ))
        # Focused window's row gets a '-> ' prefix indicator; matching
        # strips the prefix so the choice maps back to the plain pairs.
        if [ "$sel_row" -gt 0 ]; then
                markup_pairs=$(printf "%s" "$pairs" | sed "$(( sel_row + 1 ))s/^/-> /")
        else
                markup_pairs=$pairs
        fi
        # Size the rofi window to its content: rofi has no auto-width,
        # so measure the longest display line (including the '-> '
        # prefix) with a plain shell loop (here-doc, not a pipeline —
        # the counter must survive) and convert to em (Ubuntu Mono
        # advance ≈ 0.62em per char) plus prompt/padding/border.
        maxlen=0
        while IFS= read -r line; do
                [ "${#line}" -gt "$maxlen" ] && maxlen=${#line}
        done <<EOF
$(printf "%s" "$markup_pairs" | cut -d"$us" -f1)
EOF
        [ "$maxlen" -lt 20 ] && maxlen=20
        width_em=$(( maxlen * 62 / 100 + 5 ))
        choice=$(printf "%s" "$markup_pairs" | cut -d"$us" -f1 |
                rofi -dmenu -i -auto-select -l "$count" -selected-row "$sel_row" \
                        -theme ~/.config/rofi/window-switcher.rasi \
                        -theme-str "window { width: ${width_em}em; }" \
                        -p "$cls")
        [ -z "$choice" ] && return 0
        # strip the indicator prefix before matching
        choice=${choice#"-> "}
        wid=$(printf "%s" "$pairs" | grep -F "$choice$us" | cut -d"$us" -f2)
        [ -z "$wid" ] && return 0
        # Focus the window only: jumpto handles unminimizing and
        # raising implicitly, without any minimize/toggle semantics
        herb jumpto "$wid"
        herb raise "$wid"
}

# Hide/unhide a window: unminimize if hidden,
# minimize if focused, otherwise just raise it.
# State READS use floating_effectively (also true for pseudotiled /
# fullscreen windows, which behave like floating); WRITES go to the
# floating preference attribute.
raise_or_minimize() {
	herb lock
	if [ "$(herb attr "clients.$1.minimized" 2>/dev/null)" = "true" ]; then
		herb jumpto "$1"
		herb and , compare tags.focus.curframe_wcount lt 1 , attr clients.$1.floating false
	elif [ "$1" = "$(get_active_wid)" ] && \
	     [ "$(herb attr "clients.$1.floating_effectively" 2>/dev/null)" = "true" ]; then
		# already-focused floating window: minimize instead of
		# toggling float off
		herb set_attr "clients.$1.minimized" true
	elif [ "$(herb attr "clients.$1.floating_effectively" 2>/dev/null)" = "true" ]; then
		herb set_attr "clients.$1.floating" false
		herb raise "$1"
		herb jumpto "$1"
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
	herb close "$1"
}

# Focus the previous/next window within one group (frame + class),
# including hidden (minimized) members. Called with:
#   scroll_focus <frame> <class> <up|down>
# Rebuilds the group via frame_clients — the same fresh data the click
# handler (switcher) uses.
scroll_focus() {
	frame=$1
	cls=$2
	dir=$3
	act=$(get_active_wid)
	# collect the group's wids in WM order
	wids=
	while IFS="$(printf '\t')" read -r wid c min ttl flt f; do
		wids="$wids $wid"
	done <<EOF
$(frame_clients "$frame" "$cls")
EOF
	[ -z "$wids" ] && return 0

	# find position of the active window (default: before the first)
	pos=0
	i=0
	for w in $wids; do
		i=$(( i + 1 ))
		[ "$w" = "$act" ] && pos=$i && break
	done

	n=$(set -- $wids; echo $#)
	if [ "$dir" = "up" ]; then
		# previous with wraparound: before act, or last if act is first
		if [ "$pos" -le 1 ]; then
			pos=$n
		else
			pos=$(( pos - 1 ))
		fi
	else
		# next with wraparound: after act, or first if act is last
		if [ "$pos" -ge "$n" ] || [ "$pos" -eq 0 ]; then
			pos=1
		else
			pos=$(( pos + 1 ))
		fi
	fi
	target=$(set -- $wids; eval "echo \${$pos}")
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

separator="%{F$hidden_text_color}$separator%{F-}"

# Build the polybar format strings for one window state.
# Usage: format_for <text_color> <underline_color>
# Sets $left_fmt / $right_fmt
format_for() {
	left_fmt="%{F$1}"
	right_fmt="%{F-}"
	if [ -n "$2" ]; then
		left_fmt="${left_fmt}%{+u}%{u$2}"
		right_fmt="%{-u}${right_fmt}"
	fi
}

get_active_wid() {
	herb attr clients.focus.winid 2>/dev/null
}

# Emit every window on the focused tag in WM order, enriched, one per
# line: winid \t class \t minimized \t title \t effectively_floating \t frame
list_clients() {
        "$HC_GET/hc_get-clients"
}

generate_window_list() {
	active_wid=$(get_active_wid)
	window_count=0
	on_click="$0"
	tab=$(printf '\t')

	# Build a map of each frame's *visible* window: hlwm tracks a
	# per-frame selection (the focused client within that frame), so a
	# group's representative window is the frame's selection — not the
	# globally focused one. Emitted as "frame \t visible-wid" lines.
	rows=$(list_clients)
	# Everything below runs strictly in WM order (the order hc
	# list_clients reports winids in) — no sorting anywhere. Groups:
	#   tiled   -> key "frame|<frame>|<class>"  (multi-window group)
	#   min/flt -> key "minflt|<wid>"           (single-window group)
	# Group size = how many rows share the key (grep -c, exact match).
	us=$(printf '\001')
	tab=$(printf '\t')
	# per-frame visible window map: "frame \t visible-wid" lines.
	# Frames are deduped in plain shell to preserve WM order.
	frame_visible_map=
	seen_frames=
	while IFS= read -r fr; do
		[ -n "$fr" ] || continue
		case "$seen_frames" in
			*"$fr"$us*) ;;
			*) seen_frames="$seen_frames$fr$us"
			   vis=$("$HC_GET/hc_get-frame-selection" "$fr" 2>/dev/null) &&
			       frame_visible_map="$frame_visible_map$fr\t$vis\n"
			   ;;
		esac
	done <<EOF
$(printf "%s\n" "$rows" | cut -f6)
EOF

	# One group key per client row, in WM order — the source of truth
	# for group sizes (counted later with grep -c -x -F).
	# Non-framed windows (frame field = -1, no parent_frame object)
	# form their own single-window group; they must never be coerced
	# into frame 0.
	keys=$(printf "%s\n" "$rows" | while IFS="$tab" read -r wid cls min ttl flt frame; do
		[ -z "$wid" ] || [ -z "$cls" ] && continue
		if [ "$min" = "true" ] || [ "$flt" = "true" ]; then
			printf "minflt|%s\n" "$wid"
		elif [ "$frame" = "-1" ]; then
			printf "unframed|%s\n" "$wid"
		else
			printf "frame|%s|%s\n" "$frame" "$cls"
		fi
	done)

	# First-wins dedup in WM order: each key emits one bar entry. The
	# frame's visible window (from the map) represents a tiled group;
	# minflt groups keep their own window. is_active marks the group
	# holding the global focus.
	seen=
	grouped_windows=
	while IFS="$tab" read -r wid cls min ttl flt frame; do
		[ -z "$wid" ] || [ -z "$cls" ] && continue
		if [ "$min" = "true" ]; then
			state="min"
		elif [ "$flt" = "true" ]; then
			state="flt"
		else
			state="tiling"
		fi
		if [ "$state" = "tiling" ] && [ "$frame" != "-1" ]; then
			key="frame|$frame|$cls"
		elif [ "$state" = "tiling" ]; then
			key="unframed|$wid"
		else
			key="minflt|$wid"
		fi
		case "$seen" in
			*"$key"$us*) continue ;;
		esac
		seen="$seen$key$us"
		# representative: the frame's visible window if it belongs to
		# this group (same class), else the first row's window
		rep=$wid
		if [ "$state" = "tiling" ] && [ "$frame" != "-1" ]; then
			vis=$(printf "%s" "$frame_visible_map" | grep -F "$frame$tab" | cut -f2)
			[ -n "$vis" ] && rep=$vis
		fi
		count=$(printf "%s\n" "$keys" | grep -cxF "$key")
		is_active=0
		if [ "$key" = "minflt|$active_wid" ] || [ "$key" = "unframed|$active_wid" ]; then
			is_active=1
		else
			f=$(herb attr "clients.$active_wid.parent_frame.index" 2>/dev/null) || f=""
			[ -n "$f" ] || f=-1
			c=$(herb attr "clients.$active_wid.class" 2>/dev/null)
			[ "$key" = "frame|$f|$c" ] && is_active=1
		fi
		grouped_windows="$grouped_windows$(printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\n" \
			"$frame" "$cls" "$rep" "$is_active" "$count" "${ttl:-$cls}" "$state")\n"
	done <<EOF
$rows
EOF
	grouped_windows=$(printf "$grouped_windows")

	# Format each window group one by one
	while IFS="$(printf '\t')" read -r frame cls wid is_active win_count title state; do
		# Skip malformed rows (a client that vanished mid-refresh
		# leaves an empty class; matching it against forbidden_classes
		# would swallow every group and blank the bar)
		[ -z "$cls" ] || [ -z "$wid" ] && continue
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

		# Color by window status:
		#   focused  — bright gray + gold underline
		#   floating — bright gray, no underline
		#   visible  — bright gray
		#   min/hidden — dark gray, no underline
		if [ "$is_active" = "1" ] && [ "$state" != "min" ]; then
			format_for "$focused_text_color" "$focused_underline"
		elif [ "$state" = "flt" ]; then
			format_for "$floating_text_color" "$floating_underline"
		elif [ "$state" = "min" ]; then
			format_for "$hidden_text_color" ""
		else
			format_for "$visible_text_color" ""
		fi
		w_name="${left_fmt}${w_name}${right_fmt}"

		# Add separator unless the group is first in list
		if [ "$window_count" != 0 ]; then
			printf "%s" "$separator"
		fi

		# Add on-click action Polybar formatting
		# Left click: switch straight to a lone window; otherwise open
		# the group switcher scoped to this frame + class group
		if [ "$win_count" = "1" ]; then
			printf "%s" "%{A1:$on_click raise_or_minimize $wid:}"
		else
			printf "%s" "%{A1:$on_click switcher $frame \"$cls\":}"
		fi
		printf "%s" "%{A2:$on_click close $wid:}"
		printf "%s" "%{A3:$on_click window_ops $wid:}"
		printf "%s" "%{A4:$on_click scroll_focus $frame \"$cls\" up:}"
		printf "%s" "%{A5:$on_click scroll_focus $frame \"$cls\" down:}"
		# Print the final window name
		printf "%s" "$w_name"
		printf "%s" "%{A}%{A}%{A}%{A}%{A}"

		window_count=$(( window_count + 1 ))
	done <<EOF
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