// polyframes/debug.js — layered verbose logging for the polyframes
// modules.
//
// Logging is organized into four independent LAYERS, each toggleable
// on its own:
//
//   ui      — user interaction: bar rendering, click/scroll dispatch,
//             rofi menus, everything the user directly triggers
//   clients — client operations: enumeration, per-client attribute
//             reads, frame attribution
//   frames  — frame operations: selection lookups, flat/dotted index
//             conversion, frame tree queries
//   format  — formatting operations: grouping decisions, polybar
//             string assembly, truncation, colors
//
// Enabling layers (any combination):
//   -v / --verbose                 all layers
//   POLYFRAMES_VERBOSE=ui,frames   only those layers
//   POLYFRAMES_VERBOSE=1           all layers
//   polyframes.sh -v ui,format     (shim forwards to index.js)
//
// Output goes to /tmp/polyframes.log (append) with a layer tag:
//
//   [polyframes:ui] ...
//   [polyframes:clients] ...
//   [polyframes:frames] ...
//   [polyframes:format] ...
//
// Why a file: polybar's custom/script module captures the child's
// STDOUT as the bar line, and stderr from the herbst.service unit is
// hard to correlate with click events. A dedicated log file is always
// available and never corrupts the bar:
//
//   tail -f /tmp/polyframes.log
//
// Usage from any module:
//   const { ui, clients, frames, format } = require("./debug");
//   clients("getClients: %d clients", n);
//   frames("frameSelection(%s) -> %s", flat, win);
//   format("render: %d groups", groups.length);
//   ui("scroll_focus %s %s %s", frame, cls, dir);
"use strict";

const { format } = require("node:util");

const LAYERS = ["ui", "clients", "frames", "format"];

// Layer enablement: -v/--verbose turns everything on; the env var can
// select individual layers (comma-separated) or "1"/"all" for all.
let layerSet = null;
if (process.argv.includes("-v") || process.argv.includes("--verbose")) {
    layerSet = new Set(LAYERS);
} else {
    const raw = process.env.POLYFRAMES_VERBOSE;
    if (raw === "1" || raw === "all" || raw === "true") {
        layerSet = new Set(LAYERS);
    } else if (raw) {
        layerSet = new Set(
            raw.split(/[,\s]+/).filter((l) => LAYERS.includes(l)),
        );
    }
}

/** Enable exactly the named layers programmatically (used by tests). */
function setLayers(...names) {
    layerSet = new Set(names.filter((n) => LAYERS.includes(n)));
}

/** Enable/disable everything at once (used by tests). */
function setVerbose(on) {
    layerSet = on ? new Set(LAYERS) : new Set();
}

function isVerbose(layer) {
    if (!layerSet || layerSet.size === 0) return false;
    return layer === undefined ? true : layerSet.has(layer);
}

/** The single debug log file (append mode). Opened lazily and kept
 *  open for the process lifetime. Falls back to stderr if the file
 *  cannot be opened. */
const LOG_PATH = "/tmp/polyframes.log";
let logStream = null;
function logStreamFor() {
    if (logStream === null) {
        try {
            logStream = require("node:fs").createWriteStream(LOG_PATH,
                { flags: "a" });
            logStream.on("error", () => { logStream = undefined; });
        } catch {
            logStream = undefined; // fall back to stderr
        }
    }
    return logStream || process.stderr;
}

/** Emit one line for a layer if that layer is enabled. Goes to the
 *  debug log file (never stdout — polybar reads stdout as the bar). */
function emit(layer, fmt, args) {
    if (!layerSet || !layerSet.has(layer)) return;
    logStreamFor().write(`[polyframes:${layer}] ${format(fmt, ...args)}\n`);
}

/** printf-style debug on the "ui" layer. */
const ui = (fmt, ...args) => emit("ui", fmt, args);
/** printf-style debug on the "clients" layer. */
const clients = (fmt, ...args) => emit("clients", fmt, args);
/** printf-style debug on the "frames" layer. */
const frames = (fmt, ...args) => emit("frames", fmt, args);
/** printf-style debug on the "format" layer. */
const formatLayer = (fmt, ...args) => emit("format", fmt, args);

/** Dump a value with console.dir semantics (depth: null) if enabled.
 *  Written to the debug log file, never to stdout (polybar reads
 *  stdout as the bar line). */
function dir(layer, label, value) {
    if (!layerSet || !layerSet.has(layer)) return;
    const stream = logStreamFor();
    stream.write(`[polyframes:${layer}] ${label}:\n`);
    console.dir(value, {
        depth: null,
        colors: false,
        breakLength: 120,
        stream: {
            write: (s) => {
                stream.write(s);
                return true;
            },
        },
    });
}

module.exports = {
    LAYERS,
    ui,
    clients,
    frames,
    format: formatLayer,
    dir,
    setLayers,
    setVerbose,
    isVerbose,
};
