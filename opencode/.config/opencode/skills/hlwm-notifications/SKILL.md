---
name: hlwm-notifications
description: >
  Spawn dunstify notifications summarizing implemented changes (especially
  after spawning an hlwm terminal for the user to test in), with
  click-to-refocus actions: refocus the spawned terminal, and a special
  "return to opencode chat" type that refocuses the opencode window. Use
  after applying changes the user will test, or whenever work completes
  while the user is away in a spawned terminal.
---

# Skill: hlwm-notifications

Desktop notifications via `dunstify`, wired into herbstluftwm so a click
refocuses the relevant window. Complements `spawn-directory`: after the
agent implements something the user asked to test in a spawned terminal,
post a notification instead of just replying into the void.

## State files

All persistent ids live in `/tmp/opencode/notifications/` (create with
`mkdir -p`). Two files:

- `chat-winid` — the opencode window the user chats from.
- `term-winid` — the most recently spawned terminal for this session.

```bash
NOTIF_DIR=/tmp/opencode/notifications; mkdir -p "$NOTIF_DIR"
CHAT_WIN="$NOTIF_DIR/chat-winid"
TERM_WIN="$NOTIF_DIR/term-winid"
```

## Rule 1 — always capture the chat window

When a user message arrives, opencode is the focused window (the user had
to type to you). Capture it cheaply so the "return to chat" action works
later, without disturbing anything:

```bash
herbstclient attr clients.focus.winid > "$CHAT_WIN" 2>/dev/null || true
```

Refresh it whenever it's plausibly stale (start of a session, after long
work phases). Do not `jumpto` here — only record.

## Rule 2 — capture the spawned terminal's winid

When using `launch_alacritty` (the spawn-directory skill), the spawned
window takes focus. Immediately after spawning, record it:

```bash
launch_alacritty -d ~/some/project
sleep 0.3   # let the WM rule machinery register the window
herbstclient attr clients.focus.winid > "$TERM_WIN"
```

Verify it's a plausible window (non-empty, not 0x0); fall back to finding
the newest Alacritty client via `herbstclient dump`/attributes if capture
is empty.

## Change-summary notifications

After implementing changes (especially ones the user will test in a
spawned terminal), post a short summary notification:

- **No timeout**: `-t 0`.
- **Never use `-r`**: omitting it gives every notification a fresh id, so
  they stack instead of overwriting the previous one.
- Keep the body a SHORT summary (1–3 lines) of what changed.

```bash
(
  choice=$(dunstify -t 0 \
    --action="focus_terminal,Focus terminal" \
    --action="back_chat,Back to opencode" \
    "imagework: build fixed" \
    "compose flags fixed; repl ready — make repl in the spawned window")
  case "$choice" in
    focus_terminal) herbstclient jumpto "$(cat "$TERM_WIN" 2>/dev/null)" ;;
    back_chat)      herbstclient jumpto "$(cat "$CHAT_WIN" 2>/dev/null)" ;;
  esac
) &
```

**Run the dunstify invocation in the background** (as above, or via a
background shell) — plain dunstify with actions blocks until the
notification is dismissed, which would stall the agent.

## The special type: "return to opencode chat"

Use this when the agent has finished (or wants feedback) and the user is
out in the spawned terminal testing. It tells the user to come back to the
chat, and clicking focuses the opencode window:

```bash
(
  dunstify -t 0 \
    --action="back_chat,Return to opencode chat" \
    "opencode: awaiting you" \
    "Feature ready for testing. Click to return to the chat window."
  herbstclient jumpto "$(cat "$CHAT_WIN" 2>/dev/null)"
) &
```

Notes:

- The action fires on **click** of the notification (dunstify prints the
  action key; here any dismissal returns to chat — acceptable, since the
  notification is only up when the user is being recalled).
- If `chat-winid` is missing (never captured), fall back to
  `herbstclient jumpto urgent` or query the OpenCode-titled client; if
  nothing is found, just skip the focus action.
- `herbstclient jumpto <winid>` focuses and raises the window; it is safe
  with a stale id that no longer exists (jumpto fails silently — guard with
  `2>/dev/null || true` if noisy).

## When to post which

| situation                                       | notification                          |
|-------------------------------------------------|---------------------------------------|
| implemented change + spawned terminal for user  | change summary (with both actions)    |
| agent needs the user back in the chat           | special "return to opencode chat"     |
| minor/noticeable completion, no terminal        | change summary only, no actions needed|
