// polyframes/index.js — entrypoint.
//   node index.js            -> bar line + hook listener + layout poll
//   node index.js --once     -> one-shot bar line print, no listeners
//   node index.js -v [args]  -> verbose logging (stderr; see debug.js).
//                               -v/--verbose may appear anywhere and is
//                               stripped before action dispatch. Layer
//                               selection via POLYFRAMES_VERBOSE=ui,clients,
//                               frames,format (comma-separated).
//   node index.js <action> [args...]
//       switcher <frame> <class>
//       scroll_focus <frame> <class> <up|down>
//       raise_or_minimize <wid>
//       close <wid>
//       window_ops <wid>
//       toggle <wid>
"use strict";

const { spawn } = require("node:child_process");
const { createHash } = require("node:crypto");
const hc = require("./hc");
const { getClients } = require("./clients");
const { groupClients } = require("./groups");
const { render } = require("./render");
const actions = require("./actions");
const { ui, isVerbose } = require("./debug");

// Click actions must run through the JS shim, because polybar's
// environment does not include the nvm node bin dir. NOTE: the shim is
// ~/.config/polybar/scripts/polyframes.sh — NOT ~/.local/bin/polyframes.sh,
// which is the legacy shell implementation (stowed from herbst/.local/bin).
const SELF = `bash ${process.env.HOME}/.local/bin/polyframes.sh`;

async function printBar() {
    ui("printBar: start");
    const clients = await getClients();
    const activeWid = (await hc.attr("clients.focus.winid")) ?? "";
    ui("printBar: activeWid=%s", activeWid || "(none)");
    const groups = await groupClients(clients, activeWid);
    const bar = render(groups, SELF);
    ui("printBar: writing %d-byte bar line", bar.length);
    process.stdout.write(bar + "\n");
}

/**
 * Hook listener: regenerate on hlwm hooks (instant updates for focus,
 * titles, tags, urgent). Frame splits/removals emit no hook in hlwm
 * 0.9.5 — the poll loop covers those. quit_panel/reload terminate us.
 */
function startHookListener() {
    const child = spawn("herbstclient", ["--idle"], {
        env: { ...process.env, DISPLAY: process.env.DISPLAY || "localhost:0.0" },
        stdio: ["ignore", "pipe", "ignore"],
    });
    ui("hookListener: started (pid %d)", child.pid);
    let buf = "";
    child.stdout.on("data", async (chunk) => {
        buf += chunk.toString();
        let idx;
        while ((idx = buf.indexOf("\n")) !== -1) {
            const hook = buf.slice(0, idx).trim();
            buf = buf.slice(idx + 1);
            if (!hook) continue;
            ui("hook: %s", hook);
            if (hook === "quit_panel") {
                ui("hook: quit_panel -> exiting");
                child.kill();
                process.exit(0);
            } else if (hook === "reload") {
                ui("hook: reload -> exiting");
                process.exit(0);
            } else {
                await printBar().catch(() => { });
            }
        }
    });
    child.on("error", (err) => ui("hook listener error: %s", err.message));
    child.on("exit", (code) => ui("hook listener exited (code %s)", code));
    return child;
}

/**
 * Layout poll: regenerate only when the frame tree signature changes
 * (split, remove, resize, layout change). The dump is hashed, not parsed.
 */
function startLayoutPoll(intervalMs = 1000) {
    let sig = "";
    ui("layoutPoll: started (interval %dms)", intervalMs);
    const timer = setInterval(async () => {
        const d = await hc.dump();
        const newSig = d === null ? "" : createHash("md5").update(d).digest("hex");
        if (newSig !== sig) {
            ui("layoutPoll: signature changed (%s -> %s), regenerating",
                sig.slice(0, 8) || "(none)", newSig.slice(0, 8) || "(none)");
            sig = newSig;
            await printBar().catch(() => { });
        }
    }, intervalMs);
    return timer;
}

async function main(argv) {
    // Strip -v/--verbose anywhere in argv; it only enables logging and
    // must never reach action dispatch.
    const verboseIdx = argv.findIndex((a) => a === "-v" || a === "--verbose");
    if (verboseIdx !== -1) {
        argv = argv.slice(0, verboseIdx).concat(argv.slice(verboseIdx + 1));
        ui("verbose mode enabled via argv (-v); layers=%j",
            isVerbose() ? "all" : "none");
    }
    ui("main: argv=%j verbose=%s", argv, isVerbose());

    // One-shot bar line print.
    if (argv[0] === "--once") {
        ui("main: --once mode");
        await printBar();
        return;
    }
    // No args: bar line + listeners (like polywins.sh main()).
    if (argv.length === 0) {
        ui("main: daemon mode (bar + hook listener + layout poll)");
        await printBar();
        startHookListener();
        startLayoutPoll();
        return; // listeners keep the event loop alive
    }
    // Dispatch to on-click actions.
    const [fn, ...args] = argv;
    ui("main: dispatching action=%s args=%j", fn, args);
    const table = {
        switcher: actions.switcher,
        scroll_focus: actions.scrollFocus,
        raise_or_minimize: actions.raiseOrMinimize,
        close: actions.close,
        toggle: actions.toggle,
        minimize: actions.minimize,
        menu: actions.menu,
    };
    const handler = table[fn];
    if (!handler) {
        process.stderr.write(`unknown action: ${fn}\n`);
        process.exitCode = 1;
        return;
    }
    await handler(...args);
    ui("main: action %s done", fn);
}

main(process.argv.slice(2)).catch((err) => {
    process.stderr.write(`${err && err.stack ? err.stack : err}\n`);
    process.exitCode = 1;
});