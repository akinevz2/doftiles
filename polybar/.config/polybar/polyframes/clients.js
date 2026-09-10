// polyframes/clients.js — port of hc_get-clients.
// Returns every client on the focused tag in WM order, enriched.
"use strict";

const hc = require("./hc");
const { clients: dbg, dir } = require("./debug");

/**
 * @typedef {Object} Client
 * @property {string} wid   window id
 * @property {string} cls   window class
 * @property {boolean} min  minimized
 * @property {string} ttl   title (tabs/newlines flattened, falls back to class)
 * @property {boolean} flt  floating_effectively
 * @property {string} frame flat frame index, or "-1" when unframed
 */

/**
 * Frame attribution, exactly as hc_get-clients:
 *  - parent_frame object missing entirely -> "-1"
 *  - parent_frame.index = "" (single unsplit root frame) -> "-1"
 *    (tiling.root is semantically NOT tiling.root.0)
 *  - otherwise the index verbatim ("0", "1", "00", ...)
 * @param {string} wid
 * @returns {Promise<string>}
 */
async function frameOf(wid) {
    const idx = await hc.attr(`clients.${wid}.parent_frame.index`);
    const frame = idx === null ? "-1" : idx;
    dbg("frameOf(%s) -> %s%s", wid, frame,
        idx === null ? " (missing/empty parent_frame -> unframed)" : "");
    return frame;
}

/**
 * @returns {Promise<Client[]>} WM order, never sorted. Empty array on
 * any WM failure (fail soft).
 */
async function getClients() {
    dbg("getClients: querying focused tag");
    const tag = await hc.attr("tags.focus.name");
    if (tag === null) {
        dbg("getClients: no focused tag (wm unreachable) -> []");
        return [];
    }
    const wids = await hc.listClients({ tag });
    dbg("getClients: tag=%s, %d wids", tag, wids.length);
    const clients = await Promise.all(
        wids.map(async (wid) => {
            const [cls, min, ttl, flt, frame] = await Promise.all([
                hc.attr(`clients.${wid}.class`),
                hc.attr(`clients.${wid}.minimized`),
                hc.attr(`clients.${wid}.title`),
                hc.attr(`clients.${wid}.floating_effectively`),
                frameOf(wid),
            ]);
            // Defensive: skip rows with no wid/class (client vanished
            // mid-refresh; an empty class would swallow every group later).
            if (wid === "" || cls === null) {
                dbg("getClients: skipping vanished client wid=%j", wid);
                return null;
            }
            // Flatten tabs/newlines in titles so rows stay parseable.
            const cleanTitle = (ttl ?? "").replace(/[\t\n]/g, " ").trim();
            return {
                wid,
                cls,
                min: min === "true",
                ttl: cleanTitle || cls,
                flt: flt === "true",
                frame,
            };
        })
    );
    const result = clients.filter(Boolean);
    dbg("getClients: %d clients (skipped %d vanished)",
        result.length, clients.length - result.length);
    dir("clients", "clients", result);
    return result;
}

module.exports = { getClients, frameOf };