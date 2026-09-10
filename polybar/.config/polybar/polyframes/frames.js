// polyframes/frames.js — port of hc_get-frame-selection.
// Prints the winid of a frame's currently selected (visible) client.
"use strict";

const hc = require("./hc");
const { frames: dbg } = require("./debug");

/**
 * Convert a FLAT frame index ("0", "00", "010") to the dotted object
 * path segment ("0", "0.0", "0.1.0"). Each digit is one child choice;
 * the object path inserts a dot between every digit.
 * @param {string} flat
 * @returns {string} dotted path segment ("" for the empty index)
 */
function flatToDotted(flat) {
    const dotted = String(flat)
        .split("")
        .map((d) => (/\d/.test(d) ? d : ""))
        .filter((d) => d !== "")
        .join(".");
    dbg("flatToDotted(%j) -> %j", flat, dotted);
    return dotted;
}

/**
 * Frame selection lookup.
 *
 * Semantics (verified against hlwm):
 *  - flatToDotted is used ONLY for the attr path: "00" -> root.0.0
 *    (root.00 does not exist). "0" stays "0" — a real index, never
 *    normalized to "".
 *  - list_clients --frame expects the FLAT index verbatim; an object
 *    path is silently ignored there and returns ALL tag clients.
 *  - No argument -> tags.focus.tiling.root.selection (the root frame
 *    itself, only meaningful in an unsplit layout).
 *
 * @param {string} [flatIndex] flat frame index, e.g. "0", "00", "010"
 * @returns {Promise<string|null>} winid, or null when the frame is
 *   empty / the WM is unreachable.
 */
async function frameSelection(flatIndex) {
    const idx = flatIndex === undefined ? "" : String(flatIndex);
    const dotted = idx === "" ? "" : flatToDotted(idx);
    const path =
        dotted === ""
            ? "tags.focus.tiling.root.selection"
            : `tags.focus.tiling.root.${dotted}.selection`;
    dbg("frameSelection(%j): attr path=%s", idx, path);
    const sel = await hc.attr(path);
    if (sel === null) {
        dbg("frameSelection(%j): no selection attr (empty frame?) -> null", idx);
        return null;
    }
    const selNum = Number.parseInt(sel, 10);
    if (!Number.isInteger(selNum)) {
        dbg("frameSelection(%j): non-integer selection %j -> null", idx, sel);
        return null;
    }
    const wids = await hc.listClients({ frame: idx });
    const win = wids[selNum];
    dbg("frameSelection(%j): selection=%d of %d clients -> %s",
        idx, selNum, wids.length, win ?? "null (out of range)");
    return win === undefined ? null : win;
}

module.exports = { frameSelection, flatToDotted };