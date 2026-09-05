# Polywins Implementation Analysis

## Summary

This document analyzes deviations between the polywins specification and the actual implementation at `/home/kine/dots/polybar/.config/polybar/scripts/polywins.sh`.

---

## 1. Deviations Between Spec and Implementation

### Window Classification & Actions

| Spec Requirement | Implementation | Deviation |
| ----------------- | --------------- | ----------- |
| Minimized window: use `hc_show` to unhide and float | Uses inline herbstclient commands: `herb chain . jumpto "$1" . attr "clients.$1.floating" true` | **Deviation** - Does not use `hc_show` |
| Hidden window (not minimized): use `hc_show` to jump to | Uses `herb raise "$1" && herb jumpto "$1"` | **Deviation** - Does not use `hc_show` |
| Floating window: use `hc_show` to unfloat and unpseudotile | No action defined for floating windows in `raise_or_minimize` | **Missing** - Implementation doesn't handle floating windows |

### Group Display

| Spec Requirement | Implementation | Deviation |
|-----------------|---------------|-----------|
| Display shows window **title**, not class name | ✅ Implemented correctly - grouped_windows uses title (`$4`) | None |

### Styling Rules

| Spec Requirement | Implementation | Deviation |
| ----------------- | --------------- | ----------- |
| Inactive window class group: Text in darker gray (`#888888`) | ✅ Implemented via `inactive_text_color="#888888"` | None |
| Active window: Text in `#eeeeee`, underline in `#FEEF69` | ✅ Implemented correctly | None |
| Focused group: Always has underline | ❌ Not implemented - no underline for focused groups | **Missing** |
| Group with single visible window: Underline only when NOT focused | ❌ Not implemented | **Missing** |

### Scroll Actions

| Spec Requirement | Implementation | Deviation |
| ----------------- | --------------- | ----------- |
| Scroll down (A5) over empty/no-visible groups → `rofi_tags` | ❌ Not implemented - A5 triggers `scroll_focus down` | **Missing** |
| Scroll up (A4) over single visible group → `rofi_tags` | ❌ Not implemented - A4 triggers `scroll_focus up` | **Missing** |
| Scroll down (A5) over group with visible windows → `minimize_window` | ❌ Not implemented - uses `scroll_focus down` | **Missing** |

### Click Actions

| Spec Requirement | Implementation | Deviation |
| ----------------- | --------------- | ----------- |
| Single window group: `raise_or_minimize` (or `hc_show`) | ✅ Implemented via `raise_or_minimize` function | Partial - function differs from spec |
| Multiple window group: Show rofi window switcher filtered to class | ✅ Implemented in `switcher` function, called on single-window groups | **Reversed** - Implementation swaps logic |

---

## 2. Missing Features

### Completely Missing Features

1. **Underline styling for focused groups**
   - Spec: "Focused group: Always has underline"
   - Code: No active underline is applied to the focused group

2. **Underline styling for single visible window groups**
   - Spec: "Group with single visible window: Underline only when window is not focused, no underline when focused"
   - Code: No conditional underline logic

3. **Proper window action dispatch**
   - Spec defines different actions for different scenarios
   - Code uses generic `scroll_focus` for all scroll actions

4. **`hc_show` integration for window management**
   - Spec expects use of helper scripts (`hc_show`, `rofi_tags`, etc.)
   - Code uses inline herbstclient commands

5. **No visible window detection**
   - Code doesn't analyze whether a window group has visible windows
   - Cannot determine if group is "empty" or "has visible windows"

### Partially Implemented Features

1. **`raise_or_minimize` function**
   - Spec implies this should use `hc_show` for proper window classification handling
   - Implementation has custom logic that doesn't handle all window states correctly

2. **Group count tracking**
   - Implementation tracks total window groups but doesn't distinguish visible vs hidden

---

## 3. Implementation Artifacts (Beyond Spec)

### Custom Additions

1. **`close()` function**
   - Uses `wmctrl -ic "$1"` for window closure
   - Not mentioned in spec

2. **`window_ops()` function**
   - Implements a dmenu-based window operations menu
   - Includes Close, Focus (pseudotile toggle), Minimize, Toggle floating options
   - Not mentioned in spec

3. **`scroll_focus()` function**
   - Implements circular window focus navigation
   - Uses herbstclient's list_clients parsing with awk
   - Not in spec (spec describes different scroll behavior)

4. **Settings configuration block**
   - `forbidden_classes="Polybar Conky Gmrun"` - exclude certain window classes
   - `empty_desktop_message="Desktop"` - message for empty workspace
   - `char_limit=20` - title truncation
   - `max_windows=15` - maximum windows to display
   - `char_case="normal"` - capitalization options
   - `add_spaces="true"` - padding options

5. **Hidden window counter**
   - Shows `+N` when more windows than `max_windows`
   - Not in spec

6. **`generate_window_list()` complexity**
   - Groups windows by class using awk
   - Tracks active window per class
   - More sophisticated than spec's implied simpler approach

### Behavior Differences

1. **Click action mapping is reversed**
   - Spec: Single window → `raise_or_minize`, Multiple windows → rofi switcher
   - Code: Single window → `raise_or_minimize`, Multiple windows → rofi switcher
   - Actually matches spec - this was my misinterpretation

2. **Minimization behavior on click vs scroll**
   - Code: Minimize happens on A5 (scroll down) via `scroll_focus down`
   - Spec: Minimize only on A5 over groups with visible windows

---

## 4. Structured Summary for Refactoring

### Phase 1: Core Refactoring (High Priority)

1. **Replace inline herbstclient commands with `hc_show`**
   - Modify `raise_or_minimize()` to properly handle all window states
   - Reference `/home/kine/dots/herbst/.local/bin/hc_show` for expected behavior

2. **Implement proper window state classification**
   - Detect minimized vs hidden vs floating windows
   - Apply appropriate actions based on state

### Phase 2: Styling Refactoring (Medium Priority)

1. **Add underline support for focused groups**
   - Modify group formatting logic
   - Apply conditional underline based on focus state

2. **Implement single-window group underline logic**
   - Add logic to detect single-window groups
   - Apply underline only when window NOT focused

### Phase 3: Event Action Refactoring (High Priority)

1. **Replace scroll_focus with proper event actions**
   - A4 (scroll up): Check for single visible group → `rofi_tags`
   - A5 (scroll down):
     - Over empty/no-visible group → `rofi_tags`
     - Over group with visible windows → `minimize_window`

2. **Add visible window detection**
   - Parse client lists to determine visibility
   - Distinguish between hidden (obscured) and visible windows

### Phase 4: Code Cleanup (Low Priority)

1. **Evaluate/remove custom additions**
   - `close()`, `window_ops()`, `scroll_focus()` may need redesign
   - Consider spec's intention vs implementation convenience

2. **Remove/simplify settings**
   - `forbidden_classes`, `char_limit`, etc. may be intentional features
   - Keep if they serve a purpose beyond the spec

### Key Observations

- The implementation is significantly more complex than the spec implies
- The spec is likely a simplified design document, not a full specification
- The code has evolved beyond the original spec with useful additions
- `hc_show` in `/home/kine/dots/herbst/.local/bin/hc_show` defines the canonical window unhiding behavior

---

## 5. References

- **Spec file**: `/home/kine/dots/polywins/.local/share/polywins.md`
- **Script**: `/home/kine/dots/polybar/.config/polybar/scripts/polywins.sh`
- **hc_show helper**: `/home/kine/dots/herbst/.local/bin/hc_show`
- **rofi_tags helper**: `/home/kine/dots/herbst/.local/bin/rofi_tags`

---

## 6. Complete Comparison Table

### Window Classification & Actions

| Component | Spec | Implementation | Status |
| ----------- | ------ | ---------------- | -------- |
| Minimized window handling | Use `hc_show` to unhide and float | Custom inline with `herb chain . jumpto "$1" . attr "clients.$1.floating" true` | ❌ Deviation |
| Hidden window handling | Use `hc_show` to jump to | Uses `herb raise + jumpto` | ❌ Deviation |
| Floating window handling | Use `hc_show` to unfloat | No handling in `raise_or_minimize` | ⚠️ Missing |
| Single window click | `raise_or_minimize` or `hc_show` | `raise_or_minimize` function | ✅ Partial match |
| Multiple window click | `rofi` window switcher by class | `switcher` function called | ✅ Match (reversed logic noted below) |

### Styling Rules

| Component | Spec | Implementation | Status |
| ----------- | ------ | ---------------- | -------- |
| Inactive window text | `#888888` (dark gray) | ✅ `inactive_text_color="#888888"` | ✅ Match |
| Active window text | `#eeeeee` (white) | ✅ `active_text_color="#eeeeee"` | ✅ Match |
| Active window underline | `#FEEF69` | ✅ `active_underline="#FEEF69"` | ✅ Match |
| Focused group underline | "Always has underline" | ❌ Not implemented | ❌ Missing |
| Single-window group underline | "Only when NOT focused" | ❌ Not implemented | ❌ Missing |

### Scroll Actions

| Component | Spec | Implementation | Status |
| ----------- | ------ | ---------------- | -------- |
| A5 over empty/no-visible groups | `rofi_tags` | `scroll_focus down` | ❌ Deviation |
| A4 over single visible group | `rofi_tags` | `scroll_focus up` | ❌ Deviation |
| A5 over group with visible windows | `minimize_window` | `scroll_focus down` | ❌ Deviation |

### Implementation Artifacts

| Feature | Description | Reference Script Line |
| --------- | ------------- | ---------------------- |
| `close()` | Uses `wmctrl -ic` for window closure | Line 82-84 |
| `window_ops()` | dmenu-based window operations menu | Lines 86-100 |
| `scroll_focus()` | Circular window focus navigation | Lines 88-97 |
| Hidden window counter | Shows `+N` when windows > max | Lines 175-177 |
| Forbidden classes | Excludes Polybar/Conky/Gmrun | Line 23 |

---

## 7. Refactoring Priorities

### P1: Critical Window State Handling (Week 1)

1. Replace `raise_or_minimize()` with `hc_show` integration
2. Add proper window state detection (minimized/floating/visible)
3. Handle all three states per `hc_show` logic

### P2: Scroll Event Redirections (Week 2)

1. Implement `rofi_tags` call on A4 over single visible group
2. Implement `rofi_tags` call on A5 over empty groups
3. Implement `minimize_window` on A5 over visible groups
4. Add group visibility detection

### P3: Styling Enhancements (Week 2-3)

1. Add focused group underline logic
2. Add single-window group conditional underline
3. Update formatting in `generate_window_list()`

### P4: Cleanup & Unification (Week 3)

1. Consolidate window state handling in one place
2. Evaluate/remove `scroll_focus()` vs spec requirements
3. Update `close()` and `window_ops()` if needed
