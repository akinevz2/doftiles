// polyframes/render.js — polybar formatting (port of generate_window_list).
// Pure function: groups + settings in, bar line out.
"use strict";

const { format: dbg, dir } = require("./debug");

const DEFAULTS = {
    visible_text_color: "#eeeeee",
    focused_text_color: "#eeeeee",
    floating_text_color: "#eeeeee",
    hidden_text_color: "#888888",
    focused_underline: "#FEEF69",
    floating_underline: "",
    separator: "·",
    forbidden_classes: "Polybar Conky Gmrun",
    empty_desktop_message: "Desktop",
    char_limit: 20,
    max_windows: 15,
    char_case: "normal", // normal | upper | lower
    add_spaces: true,
};

/**
 * @param {import("./groups").Group[]} groups WM order
 * @param {string} onClick command prefix, e.g. "node /path/index.js"
 * @param {Partial<typeof DEFAULTS>} [settings]
 * @returns {string} the polybar module output line (no trailing \n)
 */
function render(groups, onClick, settings = {}) {
    const s = { ...DEFAULTS, ...settings };
    dbg("render: %d groups in, settings=%j", groups.length, s);
    const sep = `%{F${s.hidden_text_color}}${s.separator}%{F-}`;
    const forbidden = String(s.forbidden_classes).split(/\s+/).filter(Boolean);

    let out = "";
    let shown = 0; // groups actually rendered
    let total = 0; // all groups seen

    // Render order: WM order, but minimized groups are pushed to the
    // end, after the floating windows. Stable sort — relative order
    // within each bucket is preserved.
    const rank = (g) => (g.state === "min" ? 1 : 0);
    const ordered = groups
        .map((g, i) => ({ g, i }))
        .sort((a, b) => rank(a.g) - rank(b.g) || a.i - b.i)
        .map((e) => e.g);

    for (const g of ordered) {
        total += 1;
        // Defensive: skip malformed rows (empty wid/cls would blank the bar).
        if (!g.cls || !g.rep) {
            dbg("render: skip malformed group %j", g);
            continue;
        }
        // Forbidden classes are hidden entirely.
        if (forbidden.includes(g.cls)) {
            dbg("render: skip forbidden class %s", g.cls);
            continue;
        }
        // Past max_windows: count only.
        if (shown >= s.max_windows) {
            dbg("render: group %s/%s past max_windows (%d), counting only",
                g.frame, g.cls);
            continue;
        }

        let name = g.title || g.cls;
        if (s.char_case === "lower") name = name.toLowerCase();
        else if (s.char_case === "upper") name = name.toUpperCase();
        if (name.length > s.char_limit) {
            name = `${name.slice(0, s.char_limit - 1)}…`;
        }
        if (s.add_spaces) name = ` ${name} `;

        // Color by state: focused (gold underline) / floating / visible /
        // minimized (dark gray). A group whose class is not the frame's
        // selected client's class is not shown on screen — dim it like
        // minimized windows. This is per-frame (via isVisible), so it
        // stays correct when focus moves between frames.
        let color = s.visible_text_color;
        let underline = "";
        if (g.isActive === 1 && g.state !== "min") {
            color = s.focused_text_color;
            underline = s.focused_underline;
        } else if (g.state === "flt") {
            color = s.floating_text_color;
            underline = s.floating_underline;
        } else if (g.state === "min") {
            color = s.hidden_text_color;
        } else if (g.state === "tiling" && !g.isVisible) {
            color = s.hidden_text_color;
        }
        let left = `%{F${color}}`;
        let right = "%{F-}";
        if (underline) {
            left += "%{+u}%{u" + underline + "}";
            right = "%{-u}" + right;
        }
        name = `${left}${name}${right}`;

        if (shown !== 0) out += sep;

        // On-click actions. A1: lone window -> raise_or_minimize; group ->
        // switcher scoped to frame + class. Frame/class are quoted so
        // polybar passes them as separate argv items.
        // A2 (right): hc_menu rofi menu on the representative window.
        // A3 (middle): minimize without floating (unminimize+menu when
        // already minimized).
        if (g.count === 1) {
            out += `%{A1:${onClick} raise_or_minimize ${g.rep}:}`;
        }
        if (g.count > 1) {
            out += `%{A1:${onClick} switcher ${g.frame} "${g.cls}":}`;
        }
        // A2 (right): minimize without floating (unminimize+menu when
        // already minimized).
        // A3 (middle): hc_menu rofi menu on the representative window.
        out += `%{A2:${onClick} minimize ${g.rep}:}`;
        out += `%{A3:${onClick} menu ${g.rep}:}`;
        out += `%{A4:${onClick} scroll_focus ${g.frame} "${g.cls}" up:}`;
        out += `%{A5:${onClick} scroll_focus ${g.frame} "${g.cls}" down:}`;
        out += name;
        out += "%{A}%{A}%{A}%{A}%{A}";

        shown += 1;
    }

    if (total > s.max_windows) out += `+${total - s.max_windows}`;
    if (total === 0) {
        // Empty desktop: left click launches the rofi_tags workspace
        // switcher (all tags, scroll to cycle, click to jump).
        out += `%{A1:rofi_tags:}${s.empty_desktop_message}%{A}`;
    }
    dbg("render: shown=%d total=%d, bar length=%d", shown, total, out.length);
    dir("format", "bar", out);
    return out;
}

module.exports = { render, DEFAULTS };