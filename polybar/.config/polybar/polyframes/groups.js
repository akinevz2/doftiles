// polyframes/groups.js — port of polyframes-groups.
// Group every client on the focused tag into bar entries.
// Pure function over the clients array; frame-selection lookups are
// injectable (defaults to frames.js).
"use strict";

const { frameSelection } = require("./frames");
const { format: dbg, dir } = require("./debug");

/**
 * @typedef {Object} Group
 * @property {string} frame    flat frame index, "-1" for unframed
 * @property {string} cls      window class
 * @property {string} rep      representative wid (frame's selected
 *                             client for tiled groups, else own wid)
 * @property {0|1} isActive    group holds the globally focused window
 * @property {number} count    windows sharing the group key
 * @property {string} title    representative title (falls back to class)
 * @property {"min"|"flt"|"tiling"} state
 */

/**
 * Group key for one client row (same rules as polyframes-groups):
 *   min=true or flt=true -> "minflt|<wid>"  (solo)
 *   frame === "-1"       -> "unframed|<wid>" (solo)
 *   else                 -> "frame|<frame>|<class>"
 */
function keyOf(c) {
    if (c.min || c.flt) return `minflt|${c.wid}`;
    if (c.frame === "-1") return `unframed|${c.wid}`;
    return `frame|${c.frame}|${c.cls}`;
}

/**
 * @param {import("./clients").Client[]} clients WM order, never sorted
 * @param {string} [activeWid] globally focused winid ("" if unknown)
 * @param {(flatIndex: string) => Promise<string|null>} [selFn]
 *        injectable frame-selection lookup (for testing)
 * @returns {Promise<Group[]>} one group per key, first-wins dedup, in
 *   WM order. Rows with empty wid/cls are skipped.
 */
async function groupClients(clients, activeWid = "", selFn = frameSelection) {
    const rows = clients.filter((c) => c.wid && c.cls);
    dbg("groupClients: %d/%d rows usable", rows.length, clients.length);

    // Key stream = source of truth for group sizes.
    const keys = rows.map(keyOf);
    const countOf = (key) => keys.filter((k) => k === key).length;

    const seen = new Set();
    const groups = [];
    for (const c of rows) {
        const key = keyOf(c);
        if (seen.has(key)) continue;
        seen.add(key);

        const state = c.min ? "min" : c.flt ? "flt" : "tiling";

        // Representative: the frame's selected client for tiled frame
        // groups, else the window itself.
        let rep = c.wid;
        if (key.startsWith("frame|")) {
            const vis = await selFn(c.frame);
            if (vis) rep = vis;
            dbg("groupClients: key=%s rep=%s (frame selection: %s)",
                key, rep, vis ?? "none, fell back to first row");
        }

        // Active: the group holding the globally focused window — compare
        // the focused window's own key, computed the same way.
        const active = rows.find((r) => r.wid === activeWid);
        const isActive = active !== undefined && keyOf(active) === key ? 1 : 0;

        // Title must come from the REPRESENTATIVE window (the frame's
        // visible client), not from the first row of the group — the
        // rep can be any member, so resolve its row in the clients
        // array. Falls back to the class when the rep vanished
        // mid-refresh.
        const repRow = rows.find((r) => r.wid === rep);

        groups.push({
            frame: c.frame,
            cls: c.cls,
            rep,
            isActive,
            count: countOf(key),
            title: (repRow && repRow.ttl) || c.cls,
            state,
        });
        dbg("groupClients: + group key=%s count=%d active=%d",
            key, countOf(key), isActive);
    }
    dir("format", "groups", groups);
    return groups;
}

module.exports = { groupClients, keyOf };