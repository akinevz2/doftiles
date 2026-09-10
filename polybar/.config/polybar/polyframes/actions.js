// polyframes/actions.js — on-click handlers (ports of the polywins.sh
// click functions + polyframes-toggle). All async; every invocation
// re-queries fresh WM state.
"use strict";

const { execFile } = require("node:child_process");
const { promisify } = require("node:util");
const hc = require("./hc");
const { getClients } = require("./clients");
const { groupClients, keyOf } = require("./groups");
const { ui, clients: dbgClients } = require("./debug");

const execFileP = promisify(execFile);

// SETTINGS (kept in sync with polywins.sh / render.js defaults).
const SETTINGS = {
    char_limit: 20,
    max_windows: 15,
    forbidden_classes: "Polybar Conky Gmrun",
};

/**
 * The group's members, rebuilt fresh on every invocation — the same
 * source of truth the renderer uses. Port of frame_clients().
 * @param {string} frame flat frame index from the bar entry
 * @param {string} cls   class from the bar entry
 * @returns {Promise<import("./clients").Client[]>} WM order
 */
async function frameClients(frame, cls) {
    const clients = await getClients();
    const members = clients.filter((c) => c.cls === cls && c.frame === frame);
    ui("frameClients(frame=%s, cls=%s) -> %d members: %j",
        frame, cls, members.length, members.map((c) => c.wid));
    return members;
}

async function getActiveWid() {
    return (await hc.attr("clients.focus.winid")) ?? "";
}

/**
 * Rofi dmenu of one group's windows; selecting an entry focuses it.
 * FIXES the shell bug: pairs were built with command substitution that
 * stripped trailing newlines, collapsing all pairs onto one line so
 * the wid lookup matched garbage. Here pairs are array elements joined
 * with explicit "\n" — each display string maps to exactly one wid.
 */
async function switcher(frame, cls) {
    ui("switcher: frame=%s cls=%s", frame, cls);
    const members = await frameClients(frame, cls);
    if (members.length === 0) {
        ui("switcher: no members, aborting");
        return;
    }

    // Build display strings. Duplicate titles are intentionally NOT
    // disambiguated: the list is in WM order, so the user picks by
    // position (frame-relative index). Selection is resolved by row
    // index, never by matching the display text.
    const pairs = []; // { disp, wid }
    for (const c of members) {
        const ind = c.min ? " [min]" : c.flt ? " [flt]" : "";
        pairs.push({ disp: `${c.ttl || c.cls}${ind}`, wid: c.wid });
    }

    // Pre-select the focused window's row with a "-> " prefix.
    const activeWid = await getActiveWid();
    const selRow = pairs.findIndex((p) => p.wid === activeWid);

    const maxlen = Math.max(
        20,
        ...pairs.map((p) => (p.disp.length + 3 > 20 ? p.disp.length + 3 : 20)),
    );
    const widthEm = Math.floor((maxlen * 62) / 100) + 5;

    // Launch the shell wrapper DETACHED, fire-and-forget. The wrapper
    // builds the menu from hlwm itself, feeds rofi from a temp file
    // (guaranteed EOF — a never-EOFing stdin pipe from this long-lived
    // process leaves rofi windowless while holding the keyboard grab,
    // freezing the WM), and executes the focus change itself. No output
    // is expected back.
    spawnDetached(`${process.env.HOME}/.local/bin/hc_switcher`, [
        frame,
        cls,
        String(selRow),
        String(widthEm),
        ...pairs.map((p) => p.wid),
    ]);
}

/**
 * Focus previous/next window within one group, wraparound, including
 * minimized members. Port of scroll_focus().
 */
async function scrollFocus(frame, cls, dir) {
    ui("scrollFocus: frame=%s cls=%s dir=%s", frame, cls, dir);
    const members = await frameClients(frame, cls);
    if (members.length === 0) {
        ui("scrollFocus: no members, aborting");
        return;
    }
    const wids = members.map((c) => c.wid);
    const act = await getActiveWid();

    // Position of the active window (0 = not found -> treat as "before first").
    let pos = 0;
    for (let i = 0; i < wids.length; i += 1) {
        if (wids[i] === act) {
            pos = i + 1;
            break;
        }
    }
    const n = wids.length;
    let target;
    if (dir === "up") {
        target = pos <= 1 ? wids[n - 1] : wids[pos - 2];
    } else {
        target = pos === 0 || pos >= n ? wids[0] : wids[pos];
    }
    if (target) {
        ui("scrollFocus: active=%s pos=%d of %d -> target=%s", act, pos, n, target);
        await hc.jumpto(target);
    } else {
        ui("scrollFocus: no target resolved (pos=%d n=%d)", pos, n);
    }
}

/**
 * Hide/unhide a window. Port of raise_or_minimize(). Reads use
 * floating_effectively; float writes go to the floating preference.
 */
async function raiseOrMinimize(wid) {
    ui("raiseOrMinimize: wid=%s", wid);
    await hc.lock();
    try {
        const min = (await hc.attr(`clients.${wid}.minimized`)) === "true";
        const flt =
            (await hc.attr(`clients.${wid}.floating_effectively`)) === "true";
        const active = await getActiveWid();
        if (min) {
            ui("raiseOrMinimize: %s is minimized -> jumpto+unfloat", wid);
            await hc.cmd("and", ",", "compare", "tags.focus.curframe_wcount",
                "gt", "0", ",", "attr", `clients.${wid}.floating`, "true");
            await hc.jumpto(wid);
        } else if (wid === active && flt) {
            // already-focused floating window: maximize and unfloat
            ui("raiseOrMinimize: %s focused+floating -> minimize", wid);
            await hc.setAttr(`clients.${wid}.minimized`, "false");
            await hc.setAttr(`clients.${wid}.floating`, "false");
        } else if (flt) {
            ui("raiseOrMinimize: %s floating unfocused -> only focus", wid);
            await hc.raise(wid);
            await hc.jumpto(wid);
        } else if (wid === active) {
            ui("raiseOrMinimize: %s focused tiling -> float+minimize", wid);
            await hc.setAttr(`clients.${wid}.minimized`, "true");
        } else {
            ui("raiseOrMinimize: %s tiling unfocused -> focus", wid);
            await hc.jumpto(wid);
            await hc.raise(wid);
        }
    } finally {
        await hc.unlock();
    }
}

async function close(wid) {
    ui("close: wid=%s", wid);
    await hc.close(wid);
}

/**
 * Rofi menu with window operations. Port of window_ops().
 */
/**
 * Spawn a process fully detached: no stdin/stdout/stderr ties to this
 * process, own session. The child's lifetime is independent of ours —
 * used for every rofi-spawning helper so a slow/hung rofi can never
 * wedge this process (and through it, the bar).
 */
function spawnDetached(cmd, args) {
    const { spawn } = require("node:child_process");
    const child = spawn(cmd, args, {
        env: { ...process.env, DISPLAY: process.env.DISPLAY || "localhost:0.0" },
        stdio: "ignore",
        detached: true,
    });
    child.unref();
    child.on("error", (err) => ui("spawnDetached %s failed: %s", cmd, err.message));
    return child;
}

/**
 * Left-click state machine for a single-window entry.
 *   tiling (any focus)   -> float the window
 *   floating + focused   -> minimize
 *   floating + unfocused -> jumpto + raise
 *   minimized            -> unminimize; if its frame still has clients,
 *                           unfloat (join the tiling layout); if the
 *                           frame is empty, keep floating and center
 *                           the window (current size) in the frame.
 */
async function toggle(wid) {
    ui("toggle: wid=%s", wid);
    await hc.lock();
    try {
        const min = (await hc.attr(`clients.${wid}.minimized`)) === "true";
        const flt =
            (await hc.attr(`clients.${wid}.floating_effectively`)) === "true";
        const foc = (await hc.attr("clients.focus.winid")) ?? "";
        ui("toggle: wid=%s min=%s flt=%s foc=%s", wid, min, flt, foc);

        if (min) {
            await unminimizeIntoFrame(wid);
        } else if (flt && wid !== foc) {
            ui("toggle: %s floating unfocused -> jumpto+raise", wid);
            await hc.jumpto(wid);
            await hc.raise(wid);
        } else if (flt) {
            ui("toggle: %s focused floating -> minimize", wid);
            await hc.setAttr(`clients.${wid}.minimized`, "true");
        } else {
            ui("toggle: %s tiling -> float", wid);
            await hc.setAttr(`clients.${wid}.floating`, "true");
            await hc.raise(wid);
        }
    } finally {
        await hc.unlock();
    }
}

/**
 * Unminimize a window into its frame. If the frame still holds other
 * clients, unfloat it (tile). If the frame is empty, keep it floating
 * and center its CURRENT size within the frame's content_geometry.
 */
async function unminimizeIntoFrame(wid) {
    ui("unminimizeIntoFrame: wid=%s", wid);
    const frame = (await hc.attr(`clients.${wid}.parent_frame.index`)) ?? "";
    const wids = await hc.listClients(
        frame === "" ? {} : { frame }
    );
    const others = wids.filter((w) => w !== wid);
    if (others.length > 0) {
        ui("unminimizeIntoFrame: frame %j has %d other clients -> tile", frame, others.length);
        await hc.setAttr(`clients.${wid}.minimized`, "false");
        await hc.setAttr(`clients.${wid}.floating`, "false");
        await hc.jumpto(wid);
        await hc.raise(wid);
        return;
    }
    // Empty frame: unminimize, stay floating, center current size.
    ui("unminimizeIntoFrame: frame %j empty -> center floating", frame);
    await hc.setAttr(`clients.${wid}.minimized`, "false");
    await hc.setAttr(`clients.${wid}.floating`, "true");
    await centerInFrame(wid, frame);
    await hc.jumpto(wid);
    await hc.raise(wid);
}

/**
 * Center a window (keeping its current size) inside a frame's
 * content_geometry. Geometry format: WxH+X+Y.
 */
async function centerInFrame(wid, frame) {
    const dotted = frame === "" ? "" : require("./frames").flatToDotted(frame);
    const basePath = dotted === ""
        ? "tags.focus.tiling.root"
        : `tags.focus.tiling.root.${dotted}`;
    const fg = await hc.attr(`${basePath}.content_geometry`);
    const m = fg ? fg.match(/^(\d+)x(\d+)([+-]\d+)([+-]\d+)$/) : null;
    if (!m) {
        ui("centerInFrame: cannot parse frame geometry %j, skipping", fg);
        return;
    }
    const [, fw, fh, fx, fy] = m.map(Number);
    // Prefer floating_geometry (authoritative while floating); fall
    // back to content_geometry when it is stale/zero.
    let wg = await hc.attr(`clients.${wid}.floating_geometry`);
    let wm = wg ? wg.match(/^(\d+)x(\d+)/) : null;
    if (!wm || wm[1] === "0" || wm[2] === "0") {
        wg = await hc.attr(`clients.${wid}.content_geometry`);
        wm = wg ? wg.match(/^(\d+)x(\d+)/) : null;
    }
    if (!wm) {
        ui("centerInFrame: cannot parse window geometry %j, skipping", wg);
        return;
    }
    const ww = Number(wm[1]);
    const wh = Number(wm[2]);
    const wx = fx + Math.floor((fw - ww) / 2);
    const wy = fy + Math.floor((fh - wh) / 2);
    ui("centerInFrame: frame %dx%d%+d%+d, win %dx%d -> +%d+%d",
        fw, fh, fx, fy, ww, wh, wx, wy);
    await hc.setAttr(`clients.${wid}.floating_geometry`,
        `${ww}x${wh}+${wx}+${wy}`);
}

/**
 * Middle click: minimize without touching the floating preference.
 * On an already-minimized window: unminimize, center it (current
 * size) in its frame, and open hc_menu on it — the fast path to
 * "Close" that still allows cancelling.
 *
 * NOTE: deliberately lock-free — this branch spawns hc_menu/rofi, and
 * holding a hlwm lock across a rofi spawn risks a leaked
 * monitors_locked (the unlock can time out while rofi holds the
 * grab), which freezes the WM.
 */
async function minimize(wid) {
    ui("minimize: wid=%s", wid);
    const min = (await hc.attr(`clients.${wid}.minimized`)) === "true";
    if (!min) {
        await hc.setAttr(`clients.${wid}.minimized`, "true");
        await hc.setAttr(`clients.${wid}.floating`, "true");
        return;
    }
    // await unminimizeIntoFrame(wid);
    await hc.setAttr(`clients.${wid}.minimized`, "false");
    await menu(wid);
}

/**
 * Right click: launch the hc_menu rofi script for this window.
 * hc_menu resolves the visible client itself when no wid is given,
 * but we always pass the wid so the menu operates on exactly the
 * window whose title the bar label shows.
 */
async function menu(wid) {
    ui("menu: wid=%s", wid);
    const { spawn } = require("node:child_process");
    const child = spawn(
        `${process.env.HOME}/.local/bin/hc_menu`, [String(wid)],
        {
            env: { ...process.env, DISPLAY: process.env.DISPLAY || "localhost:0.0" },
            stdio: "ignore",
            detached: true,
        },
    );
    child.unref();
    child.on("error", (err) => ui("menu: spawn failed: %s", err.message));
}

module.exports = {
    frameClients,
    getActiveWid,
    switcher,
    scrollFocus,
    raiseOrMinimize,
    close,
    toggle,
    minimize,
    menu,
    unminimizeIntoFrame,
    centerInFrame,
    SETTINGS,
    keyOf,
    groupClients,
};