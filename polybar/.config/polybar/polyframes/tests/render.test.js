// tests/render.test.js — top-down behaviour spec for the polyframes bar
// renderer. The first test is the user-facing contract, stated
// declaratively; the following tests pin down the concrete pieces that
// contract is built from.
"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const { render } = require("../render");
const { groupClients, keyOf } = require("../groups");

// Deterministic fixture: two frames, each with two tiled windows of the
// same class, plus one floating and one minimized window.
const CLIENTS = [
    { wid: "0xa1", cls: "code", min: false, ttl: "editor", flt: false, frame: "0" },
    { wid: "0xa2", cls: "code", min: false, ttl: "diff", flt: false, frame: "0" },
    { wid: "0xb1", cls: "Alacritty", min: false, ttl: "shell", flt: false, frame: "1" },
    { wid: "0xb2", cls: "Alacritty", min: false, ttl: "logs", flt: false, frame: "1" },
    { wid: "0xf1", cls: "pavucontrol", min: false, ttl: "volume", flt: true, frame: "-1" },
    { wid: "0xm1", cls: "Alacritty", min: true, ttl: "hidden", flt: false, frame: "1" },
];

// Frame selection lookup stub: frame 0 shows 0xa2, frame 1 shows 0xb1.
const selFn = async (flat) => (flat === "0" ? "0xa2" : flat === "1" ? "0xb1" : null);

const ONCLICK = "node index.js";

test("polyframes outputs a set of labels grouped by frame and window class that has actionable left, right, and middle mouse button click handlers, as well as a scroll handler", async () => {
    const groups = await groupClients(CLIENTS, "0xa2", selFn);
    const bar = render(groups, ONCLICK);

    // One label per group: frame 0 (code), frame 1 (Alacritty),
    // floating pavucontrol, minimized Alacritty — first-wins dedup in
    // WM order.
    const labels = bar.split("%{F#888888}·%{F-}").map((s) => s.trim());
    assert.equal(labels.length, 4, `expected 4 labels, got: ${bar}`);

    // Each label carries all five action slots: A1 (left), A2 (right),
    // A3 (middle), A4/A5 (scroll up/down) — plus their matching %{A}
    // closers.
    for (const label of labels) {
        assert.match(label, /%{A1:/, "left-click handler missing");
        assert.match(label, /%{A2:/, "right-click handler missing");
        assert.match(label, /%{A3:/, "middle-click handler missing");
        assert.match(label, /%{A4:.*up:}/, "scroll-up handler missing");
        assert.match(label, /%{A5:.*down:}/, "scroll-down handler missing");
        assert.equal((label.match(/%{A}/g) || []).length, 5, "unclosed action slots");
    }
});

test("grouping: one label per (frame, class) pair; tiled group's representative is the frame's selected client", async () => {
    const groups = await groupClients(CLIENTS, "0xa2", selFn);
    const tiled = groups.filter((g) => g.state === "tiling");

    assert.deepEqual(
        tiled.map((g) => [g.frame, g.cls, g.rep, g.count]),
        [
            ["0", "code", "0xa2", 2], // frame 0's selection, not the first row
            ["1", "Alacritty", "0xb1", 2],
        ],
    );
});

test("grouping: minimized and floating windows are their own solo labels", async () => {
    const groups = await groupClients(CLIENTS, "", selFn);
    const solo = groups.filter((g) => g.state !== "tiling");

    assert.deepEqual(
        solo.map((g) => [g.state, g.rep, g.count]),
        [
            ["flt", "0xf1", 1],
            ["min", "0xm1", 1], // min window keeps its own wid
        ],
    );
});

test("grouping: unsplit root (frame -1) means every window is its own label", async () => {
    const unsplit = CLIENTS.map((c) => ({ ...c, frame: "-1" }));
    const groups = await groupClients(unsplit, "", selFn);
    assert.equal(groups.length, unsplit.length, "unsplit root must not merge windows into one group");
    assert.ok(groups.every((g) => g.frame === "-1" && g.count === 1));
});

test("left click: lone window raises/minimizes itself; multi-window group opens the frame+class switcher", async () => {
    const groups = await groupClients(CLIENTS, "", selFn);
    const bar = render(groups, ONCLICK);

    // The minimized Alacritty is a solo label -> A1 carries its wid.
    assert.match(bar, /%{A1:node index\.js raise_or_minimize 0xm\d+:}/);
    // Tiled groups -> A1 carries frame + quoted class.
    assert.match(bar, /%{A1:node index\.js switcher 0 "code":}/);
    assert.match(bar, /%{A1:node index\.js switcher 1 "Alacritty":}/);
});

test("right click minimizes without floating; middle click opens hc_menu", async () => {
    const groups = await groupClients(CLIENTS, "", selFn);
    const bar = render(groups, ONCLICK);

    assert.match(bar, /%{A2:node index\.js minimize 0xa2:}/);
    assert.match(bar, /%{A3:node index\.js menu 0xa2:}/);
});

test("scroll handlers are scoped to the label's frame and class, with explicit direction", async () => {
    const groups = await groupClients(CLIENTS, "", selFn);
    const bar = render(groups, ONCLICK);

    assert.match(bar, /%{A4:node index\.js scroll_focus 0 "code" up:}/);
    assert.match(bar, /%{A5:node index\.js scroll_focus 0 "code" down:}/);
    assert.match(bar, /%{A4:node index\.js scroll_focus 1 "Alacritty" up:}/);
});

test("the globally focused window's label is visually distinguished (focused format)", async () => {
    const groups = await groupClients(CLIENTS, "0xb1", selFn); // focus inside frame 1
    const bar = render(groups, ONCLICK);

    // Focused label gets the gold underline; others do not.
    // NOTE: the label title is the REPRESENTATIVE's title (frame 0's
    // selection is 0xa2 = "diff", not the first row's "editor").
    const labels = bar.split("%{F#888888}·%{F-}");
    const alacrittyTiling = labels.find((l) => l.includes("shell"));
    const codeLabel = labels.find((l) => l.includes("diff"));
    assert.match(alacrittyTiling, /%{u#FEEF69}/, "focused group lacks underline");
    assert.doesNotMatch(codeLabel, /%{\+u}/, "unfocused group must not be underlined");
});

test("minimized labels render dimmed and without underline", async () => {
    const groups = await groupClients(CLIENTS, "", selFn);
    const bar = render(groups, ONCLICK);
    const minLabel = bar.split("%{F#888888}·%{F-}").find((l) => l.includes("%{F#888888}"));
    assert.ok(minLabel, "no dimmed label found");
    assert.doesNotMatch(minLabel, /%{\+u}/);
});

test("forbidden classes are never rendered", async () => {
    const groups = await groupClients(
        [{ wid: "0xp", cls: "Polybar", min: false, ttl: "bar", flt: false, frame: "-1" }],
        "",
        selFn,
    );
    assert.equal(render(groups, ONCLICK), "");
});

test("empty desktop renders the placeholder message with a rofi_tags click handler", () => {
    assert.equal(render([], ONCLICK), "%{A1:rofi_tags:}Desktop%{A}");
});

test("titles are truncated to char_limit with an ellipsis", async () => {
    const groups = await groupClients(
        [{ wid: "0xl", cls: "X", min: false, ttl: "a".repeat(50), flt: false, frame: "-1" }],
        "",
        selFn,
    );
    const bar = render(groups, ONCLICK);
    assert.match(bar, /a{19}…/);
});

test("more groups than max_windows renders a +N overflow indicator", async () => {
    const many = Array.from({ length: 20 }, (_, i) => ({
        wid: `0x${i}`, cls: `c${i}`, min: false, ttl: `t${i}`, flt: false, frame: "-1",
    }));
    const groups = await groupClients(many, "", selFn);
    const bar = render(groups, ONCLICK);
    assert.match(bar, /\+5$/); // 20 groups, 15 shown
});

test("group keys follow the minflt/unframed/frame taxonomy", () => {
    assert.equal(keyOf(CLIENTS[0]), "frame|0|code");
    assert.equal(keyOf({ ...CLIENTS[0], frame: "-1" }), "unframed|0xa1");
    assert.equal(keyOf({ ...CLIENTS[0], min: true }), "minflt|0xa1");
    assert.equal(keyOf({ ...CLIENTS[0], flt: true }), "minflt|0xa1");
});
