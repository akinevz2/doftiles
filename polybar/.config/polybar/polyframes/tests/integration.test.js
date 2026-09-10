// tests/integration.test.js — live-WM integration tests.
//
// Each test creates a fresh hlwm tag, spawns real windows (Alacritty
// as window class 1, Byobu as window class 2 — via
// `alacritty --class Byobu -e byobu` since byobu itself is not a
// window manager client), arranges the requested frame layout, and
// exercises the polyframes submodules (clients, frames, groups,
// render) against the live WM. No interactivity: rofi is never
// invoked; actions are tested only through their pure/grouping
// building blocks.
//
// Layout permutations covered:
//   1. default max root split (single unsplit root frame, max layout)
//   2. default grid root split (single unsplit root frame, grid layout)
//   3. 2-frame split, both frames showing the same window class
//   4. 2-frame split, frames showing different window classes
//   5. up to 4 frame splits
//
// Run: npm test (from polyframes/) — requires the live WM on
// DISPLAY=localhost:0.0.
"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");

const hc = require("../hc");
const { getClients } = require("../clients");
const { frameSelection, flatToDotted } = require("../frames");
const { groupClients, keyOf } = require("../groups");
const { render } = require("../render");

const TAG = "pf_integration_test";
const CLASS1 = "Alacritty";
const CLASS2 = "Byobu";
const SPAWN_WAIT_MS = 4000; // alacritty + byobu startup

// --- helpers ---------------------------------------------------------

function sleep(ms) {
    return new Promise((r) => setTimeout(r, ms));
}

/** Create a fresh empty tag and switch to it. */
async function makeTag() {
    await hc.cmd("add", TAG);
    await hc.cmd("use", TAG);
    const clients = await hc.listClients({ tag: TAG });
    assert.equal(clients.length, 0, "fresh tag must be empty");
}

/** Switch away and merge the test tag back into the previous tag. */
async function cleanupTag(prevTag) {
    await hc.cmd("use", prevTag(prevTag.name));
    // placeholder, replaced below
}
function prevTag() { return { name: "work" }; }

async function teardown() {
    // Kill every window on the test tag, then merge it away.
    await hc.cmd("use", "work");
    const wids = await hc.listClients({ tag: TAG });
    for (const wid of wids) {
        await hc.cmd("close", wid);
    }
    await sleep(300);
    await hc.cmd("merge_tag", TAG);
}

/** Spawn a window of the given class on the focused (test) tag. */
async function spawnWindow(cls) {
    const before = new Set(await hc.listClients({ tag: TAG }));
    if (cls === CLASS1) {
        await hc.cmd("spawn", "alacritty");
    } else if (cls === CLASS2) {
        await hc.cmd("spawn", "alacritty", "--class", CLASS2, "-e", "byobu");
    } else {
        throw new Error(`unknown class ${cls}`);
    }
    // Wait until exactly one new client appears on the tag.
    for (let i = 0; i < 40; i += 1) {
        await sleep(250);
        const now = await hc.listClients({ tag: TAG });
        const fresh = now.filter((w) => !before.has(w));
        if (fresh.length === 1) {
            const c = await getClients();
            const row = c.find((x) => x.wid === fresh[0]);
            if (row && row.cls === cls) return fresh[0];
        }
    }
    throw new Error(`spawn ${cls}: no window appeared on ${TAG}`);
}

/** Kill a window and wait for it to disappear. */
async function killWindow(wid) {
    await hc.cmd("close", wid);
    for (let i = 0; i < 20; i += 1) {
        await sleep(200);
        const now = await hc.listClients({ tag: TAG });
        if (!now.includes(wid)) return;
    }
    throw new Error(`window ${wid} did not close`);
}

/** Set the root frame's layout algorithm. */
async function setLayout(name) {
    await hc.cmd("set_layout", name);
}

/** Split the focused frame. dir: horizontal|vertical */
async function split(dir, fraction = 0.5) {
    await hc.cmd("split", dir, String(fraction));
}

/** Focus a neighbour frame (left/right/up/down). */
async function focusDir(dir) {
    await hc.cmd("focus", dir);
}

/**
 * Split the focused frame and move `wid` into the new (second) child
 * via hlwm `bring` — the reliable way to distribute windows across
 * frames (a bare `split` keeps all clients in the first child).
 */
async function splitOff(dir, wid, fraction = 0.5) {
    await split(dir, fraction);
    await focusDir(dir === "horizontal" ? "right" : "down");
    await hc.cmd("bring", wid);
    return frameOf(wid);
}

/** Focus a specific window (brings its frame into view). */
async function focusWindow(wid) {
    await hc.cmd("jumpto", wid);
}

/** The flat parent_frame.index of a window. */
async function frameOf(wid) {
    const idx = await hc.attr(`clients.${wid}.parent_frame.index`);
    return idx === null ? "-1" : idx;
}

// --- the test suite ---------------------------------------------------

test("integration: default max root split (unsplit root, max layout)", async (t) => {
    await makeTag();
    try {
        const w1 = await spawnWindow(CLASS1);
        const w2 = await spawnWindow(CLASS2);
        await setLayout("max");

        // Layout: single root frame, both windows in it.
        const dump = await hc.dump();
        assert.match(dump, /^\(clients max:/, "expected unsplit max root");

        // clients.js: unsplit root -> every window frame "-1"
        const clients = await getClients();
        assert.equal(clients.length, 2);
        assert.ok(clients.every((c) => c.frame === "-1"),
            "unsplit root must map to frame -1, got: " +
            clients.map((c) => c.frame).join(","));

        // groups.js: one solo label per window (accessibility contract).
        const active = await hc.attr("clients.focus.winid") ?? "";
        const groups = await require("../groups").groupClients(clients, active);
        assert.equal(groups.length, 2);
        assert.ok(groups.every((g) => g.frame === "-1" && g.count === 1));

        // frames.js: no-arg selection tracks the root frame's selection.
        const sel = await frameSelection();
        assert.ok(sel === w1 || sel === w2, `root selection ${sel} must be one of the windows`);
        await focusWindow(w2);
        assert.equal(await frameSelection(), w2,
            "root selection must follow the focused window");
        // Flat index "0" must NOT be normalized to "" — with an unsplit
        // root there is no frame 0, so the lookup must fail softly.
        assert.equal(await frameSelection("0"), null,
            "frame 0 does not exist in an unsplit root");
    } finally {
        await teardown();
    }
});

test("integration: default grid root split (unsplit root, grid layout)", async (t) => {
    await makeTag();
    try {
        const w1 = await spawnWindow(CLASS1);
        const w2 = await spawnWindow(CLASS2);
        await setLayout("grid");

        const dump = await hc.dump();
        assert.match(dump, /^\(clients grid:/, "expected unsplit grid root");

        const clients = await getClients();
        assert.ok(clients.every((c) => c.frame === "-1"));

        // frameSelection with no arg still resolves the visible window.
        await focusWindow(w2);
        assert.equal(await frameSelection(), w2);
        await focusWindow(w1);
        assert.equal(await frameSelection(), w1);
    } finally {
        await teardown();
    }
});

test("integration: 2-frame split, both frames showing the same window class", async (t) => {
    await makeTag();
    try {
        const w1 = await spawnWindow(CLASS1);
        const w2 = await spawnWindow(CLASS1);
        await setLayout("max");
        // Split and move w2 into the new frame via bring.
        await splitOff("horizontal", w2);

        // Both windows now sit in separate frames with the same class.
        const f1 = await frameOf(w1);
        const f2 = await frameOf(w2);
        assert.notEqual(f1, f2, "windows must be in different frames");
        assert.deepEqual([f1, f2].sort(), ["0", "1"]);

        // clients.js: real frame indices, not -1.
        const clients = await getClients();
        const frames = clients.map((c) => c.frame).sort();
        assert.deepEqual(frames, ["0", "1"]);

        // groups.js: two groups (same class, different frames), each
        // with count 1 — frame+class keys must not merge across frames.
        const active = await hc.attr("clients.focus.winid") ?? "";
        const groups = await require("../groups").groupClients(clients, active);
        assert.equal(groups.length, 2);
        assert.ok(groups.every((g) => g.cls === CLASS1 && g.count === 1));
        assert.deepEqual(groups.map((g) => g.frame).sort(), ["0", "1"]);

        // frames.js: each frame's selection is its own window.
        assert.equal(await frameSelection(f1), w1);
        assert.equal(await frameSelection(f2), w2);

        // Focus the other window; per-frame selections must follow.
        await focusWindow(w2);
        assert.equal(await frameSelection(f2), w2);
        assert.equal(await frameSelection(f1), w1, "frame 1's selection must not leak into frame 0");
    } finally {
        await teardown();
    }
});

test("integration: 2-frame split, frames showing different window classes", async (t) => {
    await makeTag();
    try {
        const w1 = await spawnWindow(CLASS1);
        const w2 = await spawnWindow(CLASS2);
        await setLayout("max");
        await splitOff("horizontal", w2);

        const f1 = await frameOf(w1);
        const f2 = await frameOf(w2);
        assert.notEqual(f1, f2);

        const clients = await getClients();
        const active = await hc.attr("clients.focus.winid") ?? "";
        const groups = await require("../groups").groupClients(clients, active);

        // Two groups, one per class, each count 1.
        assert.equal(groups.length, 2);
        const byCls = Object.fromEntries(groups.map((g) => [g.cls, g]));
        assert.ok(byCls[CLASS1] && byCls[CLASS2]);
        assert.equal(byCls[CLASS1].count, 1);
        assert.equal(byCls[CLASS2].count, 1);

        // Representatives are the frame selections (the windows themselves).
        assert.equal(await frameSelection(byCls[CLASS1].frame), byCls[CLASS1].rep);
        assert.equal(await frameSelection(byCls[CLASS2].frame), byCls[CLASS2].rep);

        // render.js: two labels, each with the full action set.
        const bar = require("../render").render(groups, "node index.js");
        const labels = bar.split(/%{F#888888}·%{F-}/);
        assert.equal(labels.length, 2);
        for (const label of labels) {
            assert.match(label, /%{A1:node index\.js raise_or_minimize 0x[0-9a-f]+:}/,
                "count==1 groups use raise_or_minimize");
            assert.match(label, /%{A4:node index\.js scroll_focus [01] "/);
        }
    } finally {
        await teardown();
    }
});

test("integration: 4-frame split (nested), flat indices and per-frame selection", async (t) => {
    await makeTag();
    try {
        // Four windows: two of each class.
        const w1 = await spawnWindow(CLASS1);
        const w2 = await spawnWindow(CLASS2);
        const w3 = await spawnWindow(CLASS1);
        const w4 = await spawnWindow(CLASS2);
        await setLayout("max");

        // Build 4 leaf frames: split root, then split each child.
        // splitOff moves w2 into the new frame each time, guaranteeing
        // one window per leaf.
        await splitOff("horizontal", w2);          // frames: 0(w1) 1(w2)
        await focusDir("left");                    // focus frame 0
        await splitOff("vertical", w3);            // 0.0(w1) 0.1(w3) 1(w2)
        await focusDir("right");                   // focus frame 1 (w2)
        await splitOff("vertical", w4);            // 0.0 0.1 1.0(w2) 1.1(w4)

        const dump = await hc.dump();
        // 4 leaf frames = 3 split nodes.
        assert.equal((dump.match(/split /g) || []).length, 3, `expected 4-frame tree, got ${dump}`);

        // Every window is in a leaf frame with a real flat index.
        const clients = await getClients();
        assert.equal(clients.length, 4);
        const frames = clients.map((c) => c.frame);
        for (const f of frames) {
            assert.notEqual(f, "-1", "no window may be unframed in a split tree");
            assert.match(f, /^[01]+$/, `flat index ${f} must be digits only`);
        }

        // flatToDotted: "00" -> "0.0" etc. (verified hlwm semantics).
        assert.equal(flatToDotted("00"), "0.0");
        assert.equal(flatToDotted("11"), "1.1");
        assert.equal(flatToDotted("0"), "0");

        // frames.js: selection lookups work for every nested frame and
        // always return a window that actually lives in that frame.
        for (const c of clients) {
            const sel = await frameSelection(c.frame);
            assert.ok(sel, `frame ${c.frame} must have a selection`);
            const selFrame = await frameOf(sel);
            assert.equal(selFrame, c.frame,
                `selection of frame ${c.frame} must be a member of that frame`);
        }

        // groups.js: same-class windows in different frames stay in
        // separate groups (frame is part of the key).
        const active = await hc.attr("clients.focus.winid") ?? "";
        const groups = await require("../groups").groupClients(clients, active);
        assert.equal(groups.length, 4, "4 frames -> 4 groups regardless of class collision");
        assert.ok(groups.every((g) => g.count === 1));

        // Focus each window in turn; its frame's selection must track it.
        for (const wid of [w1, w2, w3, w4]) {
            await focusWindow(wid);
            const f = await frameOf(wid);
            assert.equal(await frameSelection(f), wid);
        }
    } finally {
        await teardown();
    }
});

test("integration: 3-frame split with two windows in one frame (grouped label)", async (t) => {
    await makeTag();
    try {
        const w1 = await spawnWindow(CLASS1);
        const w2 = await spawnWindow(CLASS1);
        const w3 = await spawnWindow(CLASS2);
        await setLayout("max");
        await splitOff("horizontal", w3); // frame 0: w1,w2 | frame 1: w3

        const clients = await getClients();
        const active = await hc.attr("clients.focus.winid") ?? "";
        const groups = await require("../groups").groupClients(clients, active);

        // Frame 0 holds two same-class windows -> one grouped label
        // (count 2, A1 = switcher); frame 1 holds the solo Byobu.
        assert.equal(groups.length, 2);
        const grouped = groups.find((g) => g.count === 2);
        const solo = groups.find((g) => g.count === 1);
        assert.ok(grouped && solo);
        assert.equal(grouped.cls, CLASS1);
        assert.equal(solo.cls, CLASS2);

        // The grouped label's representative is the frame's selection.
        const f0 = await frameOf(w1);
        assert.equal(grouped.frame, f0);
        assert.equal(await frameSelection(f0), grouped.rep);
        assert.ok([w1, w2].includes(grouped.rep));

        // Render: the grouped label gets the switcher action.
        const bar = require("../render").render(groups, "node index.js");
        assert.match(bar, new RegExp(`%{A1:node index\\.js switcher ${f0} "${CLASS1}":}`));
    } finally {
        await teardown();
    }
});
