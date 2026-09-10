// polyframes/hc.js — thin async wrapper around herbstclient.
// No side effects on require. Node >= 18, CommonJS, no deps.
"use strict";

const { execFile } = require("node:child_process");
const { promisify } = require("node:util");
const { clients: dbg } = require("./debug");

const execFileP = promisify(execFile);

// DISPLAY is localhost:0.0 on this WSL2 host (repo convention).
function env() {
    return { ...process.env, DISPLAY: process.env.DISPLAY || "localhost:0.0" };
}

/**
 * Run `herbstclient <args...>`. Resolves { stdout } on success.
 * herbstclient exits nonzero on missing objects / errors — treat as
 * soft failure: resolve null instead of throwing.
 * @param {...string} args
 * @returns {Promise<{stdout: string} | null>}
 */
async function cmd(...args) {
    const t0 = Date.now();
    try {
        const { stdout } = await execFileP("herbstclient", args, {
            env: env(),
            timeout: 5000,
        });
        dbg("cmd %j -> ok (%dms, %d bytes)", args, Date.now() - t0, stdout.length);
        if (stdout.length <= 200) dbg("  stdout: %j", stdout.trimEnd());
        return { stdout };
    } catch (err) {
        dbg("cmd %j -> FAIL (%dms): %s", args, Date.now() - t0,
            err && err.code !== undefined ? `exit ${err.code}` : err.message);
        return null;
    }
}

/**
 * Read an object attribute. Returns the trimmed string, or null when
 * the object/attribute does not exist (herbstclient nonzero exit).
 * @param {string} path e.g. "clients.focus.winid"
 * @returns {Promise<string|null>}
 */
async function attr(path) {
    const r = await cmd("attr", path);
    if (r === null) return null;
    const s = r.stdout.trim();
    return s === "" ? null : s;
}

/**
 * Write an attribute: set_attr <path> <value>
 */
async function setAttr(path, value) {
    return cmd("set_attr", path, String(value));
}

/**
 * Toggle an attribute: attr <path> toggle
 */
async function toggleAttr(path) {
    return cmd("attr", path, "toggle");
}

/**
 * list_clients. Options: { tag, frame } — tag is a tag NAME, frame is
 * the FLAT frame index (an object path is silently ignored by hlwm and
 * would return ALL tag clients — never pass dotted paths here).
 * Returns array of winid strings (WM order, never sorted).
 */
async function listClients({ tag, frame } = {}) {
    const args = ["list_clients"];
    if (tag !== undefined) args.push(`--tag=${tag}`);
    if (frame !== undefined) args.push(`--frame=${frame}`);
    const r = await cmd(...args);
    if (r === null) {
        dbg("listClients %j -> [] (wm failure)", { tag, frame });
        return [];
    }
    const wids = r.stdout.split("\n").map((s) => s.trim()).filter(Boolean);
    dbg("listClients %j -> %d wids: %j", { tag, frame }, wids.length, wids);
    return wids;
}

/**
 * dump — the layout tree as a single string, or null on failure.
 */
async function dump() {
    const r = await cmd("dump");
    return r === null ? null : r.stdout;
}

// Convenience wrappers for the commands used by the actions.
const jumpto = (wid) => cmd("jumpto", wid);
const raise = (wid) => cmd("raise", wid);
const close = (wid) => cmd("close", wid);
const lock = () => cmd("lock");
const unlock = () => cmd("unlock");

module.exports = {
    cmd,
    attr,
    setAttr,
    toggleAttr,
    listClients,
    dump,
    jumpto,
    raise,
    close,
    lock,
    unlock,
};