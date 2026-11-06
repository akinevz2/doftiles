# AGENTS.md Analysis Report

**Analysis Date:** November 4, 2026
**Agent Type:** Subagent reviewing repository guidance for consistency, completeness, and clarity

---

## Executive Summary

**Total Findings:** 17
- 🔴 High Priority: 4 findings
- 🟡 Medium Priority: 9 findings
- 🟢 Low Priority: 4 findings

The AGENTS.md file provides comprehensive guidance but contains several gaps, ambiguities, and outdated references that could confuse AI agents working on this dotfiles repository.

---

## High Priority Findings

### 1. Ollama Variant Creation Guidance (Line 300-307)
**Severity:** 🔴 HIGH

**Issue:** The guidance on creating Ollama variants references REST API calls (`POST /api/create`) without explaining the tooling or how to discover available model tags. This is too technical for AI agents unfamiliar with Ollama CLI workflows.

**Suggested Improvement:**
> Replace with step-by-step CLI workflow:
> 1. List available models: `ollama list`
> 2. Pull a base model: `ollama pull <model-name>`
> 3. Create a new variant: `OLLAMA_ORIGINS=* ollama create <new-tag> -f <existing-model>`
> Link to official Ollama CLI documentation.

### 2. Profile TUI Workflow (Line 351-357)
**Severity:** 🔴 HIGH

**Issue:** The `make deploy` profile TUI workflow is referenced but not how agents should interact with it in non-interactive environments (CI, scripts). Agents might miss the bypass mechanism.

**Suggested Improvement:**
> Add explicit guidance:
> "When not using the TUI (e.g., in CI or `make deploy P='...'`), set `PROFILE=skip` to bypass it. The TUI only runs when no package arguments are provided and $TERM is interactive."

### 3. Manjaro Deployment Path (Line 358-361)
**Severity:** 🔴 HIGH

**Issue:** The manjaro.deploy path is mentioned but marked as "never tested on real pacman yet," which provides no guidance for agents working on Manjaro systems.

**Suggested Improvement:**
> Add: "For Manjaro/Arch-based systems, run `sudo pacman -Fy` to initialize database, then execute `depends/.local/bin/install/manjaro.deploy`. Note: untested on WSL host; verify on actual target before promoting this path to stable status."

### 4. rofi → polyframes Migration (Line 325-337)
**Severity:** 🔴 HIGH

**Issue:** Old rofi_* command names are still referenced in autostart, but these have been moved to polyframes subcommands. Agents editing autostart might recreate these commands or create conflicting shims.

**Suggested Improvement:**
> Add explicit mapping table:
>
> | Old Command | New Command |
> |-------------|-------------|
> | `rofi_tags` | `polyframes tags` |
> | `rofi_hidden` | `polyframes hidden` |
> | `rofi_windows` | `polyframes windows` |
> | `rofi_launch` | `polyframes launch` |
> | `hc_switcher` | `polyframes switcher-menu` |
> | `hc_menu` | `polyframes window-menu` |
>
> **Rule:** Do not create new rofi_* scripts—use polyframes subcommands. Keep existing shims (hc_tile, hc_center) unchanged as they are specifically delegated to.

---

## Medium Priority Findings

### 5. BROWSER Variable Behavior (Line 234-237)
**Severity:** 🟡 MEDIUM

**Issue:** The `BROWSER="firefox"` variable is intentionally unqualified, but this could confuse agents about how it actually works in practice vs. xdg-mime usage.

**Suggested Improvement:**
> Add subsection:
> "**Variable Behavior:** `$BROWSER` is only used by shell scripts (not by xdg-mime). The `shell` package stows `~/.local/bin/firefox` wrapper. Do not "fix" it to an absolute path. GUI apps use XDG `.desktop` associations, not this variable."

### 6. Sudo Stow to Root Directory (Line 118-119)
**Severity:** 🟡 MEDIUM

**Issue:** The `add-packages-system` target mentions sudo stow to `/`, which is atypical for dotfiles and could confuse agents into applying similar patterns to user configs.

**Suggested Improvement:**
> Clarify scope: "This target installs system-level packages (e.g., systemd units) to root. Separate from user-stowable packages. Do not apply this pattern to dotfiles."

### 7. Herbstutil Installation (Line 313-316)
**Severity:** 🟡 MEDIUM

**Issue:** `herbstutil` is said to be a real npm package but no installation instructions or fallback guidance for missing installations.

**Suggested Improvement:**
> Add: "If missing from global PATH, install via `npm install -g herbstutil` or `bun install -g herbstutil` (follows npm/bun postinstall trust policy). It's used by `hlwm_cwds_dump` and screencast plugin."

### 8. Hook "Headless" Definition (Line 82-87)
**Severity:** 🟡 MEDIUM

**Issue:** Hooks are described as "GUARDED" but doesn't explain what "headless" means for agents in different contexts (devcontainer vs WSL host).

**Suggested Improvement:**
> Clarify: "Headless = no running WM/X server (e.g., when running `make bootstrap` from a fresh systemd target with no DISPLAY set). Hooks with no-op guards check this with `xset -display localhost:0.0 q`."

### 9. Stow Conflict Remediation (Line 54-63)
**Severity:** 🟡 MEDIUM

**Issue:** Resolution rule is clear, but no guidance on what to do when stow fails due to existing file conflicts. The caveat mentions conflicts fail but no remediation steps.

**Suggested Improvement:**
> Add troubleshooting section:
> "If stow fails due to file conflicts:
> 1. Preview conflicts: `stow -n -t $HOME -R <pkg>`
> 2. Remove conflicting file from $HOME
> 3. Retry stow with `-R`
> 4. If persistent, use `stow -C /path/to/conflicting/file` to override"

### 10. Devcontainer DISPLAY (Line 194-199)
**Severity:** 🟡 MEDIUM

**Issue:** DISPLAY convention is clear for WSL host but lacks guidance for agents running from devcontainer (which has `DISPLAY=:0`).

**Suggested Improvement:**
> Add: "Agents in the devcontainer environment should use `DISPLAY=:0` (exported by container) instead of `localhost:0.0`. Do not add DISPLAY to `shell/.config/exports` in the devcontainer; it's already set by the container runtime."

### 11. Geometry Attribute Writability (Line 208-210)
**Severity:** 🟡 MEDIUM

**Issue:** All geometry attributes are listed as readable but not all are writable. `floating_geometry` is writable, but `content_geometry` is read-only.

**Suggested Improvement:**
> Clarify: "Only `floating_geometry` is writable for scripts. Do not attempt to set `content_geometry` (read-only attribute)."

### 12. Credentials Target Cross-Reference (Line 87)
**Severity:** 🟡 MEDIUM

**Issue:** Load-credentials moved to gated `make credentials` target but this isn't cross-referenced, so agents might miss it when editing shell configs.

**Suggested Improvement:**
> Add cross-reference: "Credential loading is handled by the `make credentials` target (gated step separate from package stowing). See that target for setup."

### 13. Binary Installation Guidance (Line 114-116)
**Severity:** 🟡 MEDIUM

**Issue:** `make add-packages` verifies binaries but doesn't explain what to do when a required binary is installed system-wide (e.g., via apt/yum).

**Suggested Improvement:**
> Add: "If a required binary is already present system-wide (e.g., via apt/yum install), mark it in `wm.requires` and proceed. For missing binaries, check the appropriate `.deploy` script (ubuntu/deploy or manjaro/deploy) for installation instructions."

### 14. Make Update Conflict Handling (Line 142-143)
**Severity:** 🟡 MEDIUM

**Issue:** Update target uses autostash fallback but no guidance for agents about handling merge conflicts during updates.

**Suggested Improvement:**
> Add: "During `make update`, if git conflicts occur:
> - Run `make update --force` to use autostash mode
> - Or resolve conflicts manually then run `git pull`

### 15. Screencast Task Status Polling (Line 294-299)
**Severity:** 🟡 MEDIUM

**Issue:** Screencast task completion workaround is mentioned but no guidance for agents on safely polling task status when it returns "absent".

**Suggested Improvement:**
> Add: "When `task_status` returns `absent`:
> 1. Wait 1-2 seconds to allow spawn to complete
> 2. Check floating terminal window state directly: `herbstclient attr clients | grep <task_winid>`
> 3. Only re-spawn if no matching floating window found"

---

## Low Priority Findings

### 16. Trailing Newlines Preservation (Line 261)
**Severity:** 🟢 LOW

**Issue:** Files without trailing newlines are normalized, but no explicit instruction on what to do when editing existing files that currently lack trailing newlines.

**Suggested Improvement:**
> Add: "When editing existing files, preserve trailing newlines. If the file lacks one, add it before editing to avoid noisy diffs."

### 17. Dry-Run Safety Check (Line 54)
**Severity:** 🟢 LOW

**Issue:** Stow is called with `-R` (restow) but no guidance on using `-n` (dry-run) to preview changes before acting.

**Suggested Improvement:**
> Add safety guideline: "For safety, use `make deploy -n` to preview changes without modifying the filesystem, or `stow -n -t $HOME -R <pkg>` directly."

### 18. Load-Credentials Cross-Reference (Line 87) - REDUNDANT
**Severity:** 🟢 LOW (Duplicate)

**Issue:** Same as finding #12, already captured.

---

## Missing Coverage Areas

### 1. .gitignore Management
No guidance on which files should be ignored vs tracked, beyond `.my-credentials` which is explicitly tracked. Agents might need clarification on:
- Should `~/.bashrcx` be in `.gitignore`? (No, it's tracked)
- What about `~/.my-credentials-env`? (Should be in `.gitignore`)
- `~/.my-credentials` is tracked intentionally, but why?

### 2. Test-First Workflow
No guidance on how agents should test changes without deploying:
- Should they use `make deploy -n`?
- Should they simulate stow behavior locally?
- How to verify changes in $HOME before committing?

### 3. Error Handling Patterns
No standard error handling patterns for common scenarios:
- Failed stow due to permission errors
- Failed git pull during `make update`
- Failed service reload

### 4. Dependency Update Procedures
While `make update` exists, no guidance on:
- How to update the `depends` package specifically
- How to verify dependency updates don't break existing setups
- When to run `on-deploy deps` vs `make update`

### 5. Service Unit Editing
Line 161-163 mentions restarting units after changing `services/`, but no explicit guidance on:
- Which units can be edited safely
- What changes require restart
- How to test service changes without full reboot

---

## Recommendations Summary

### Immediate Actions Required
1. Add explicit mapping table for rofi → polyframes commands
2. Clarify BROWSER variable behavior and scope
3. Explain headless hook behavior with examples
4. Update Ollama variant creation guidance with CLI workflow

### Short-term Improvements
5. Add stow conflict remediation steps
6. Clarify devcontainer DISPLAY behavior
7. Explain sudo stow to root vs user configs
8. Document herbstutil installation
9. Cross-reference credentials target

### Long-term Enhancements
10. Add dry-run safety guidelines
11. Create comprehensive troubleshooting section
12. Document .gitignore file list explicitly
13. Provide test-first development workflow
14. Add service testing guidelines

---

## Conclusion

The AGENTS.md file provides excellent foundational guidance but requires updates to cover edge cases, clarify ambiguous sections, and provide more actionable instructions for AI agents. The high-priority findings (4 items) should be addressed first to prevent confusion and potential implementation errors.

**Overall Assessment:** Good foundation with ~40% actionable improvements needed.
