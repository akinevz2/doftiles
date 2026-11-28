# structured-spec

opencode **v2** plugin (`@opencode/plugin`, `@opencode/cli` 2.x). keeps a per-session list of atomic notes; the model must consult
the list after receiving a complete user request and verify its response against
every note before finishing.

- tools: `add-rigorously`, `invalidate-rigorously`, `consult-specification`,
  `sync-specification`
- notes can also arrive in the user's message as a fenced block:

      ```notes
      - never touch the migrations directory
      - every public function gets a test
      ```

- `invalidate-rigorously` amends the list. `drop` removes the matching note
  text outright (the fact was wrong); `overrule` deactivates the matching
  notes but keeps their text for reference (the fact is superseded);
  `notes` adds replacements in the same call. matching is by the exact note
  text as `consult-specification` shows it. re-adding an overruled note's
  text re-activates it.
- `sync-specification` synchronises the session list with the active
  project's `AGENTS.md` store (resolved once at setup from the plugin
  context's project directory). `direction: "push"` serialises the list
  into the file's marked section (an exact mirror; refused while the list
  is empty so the store cannot be wiped); `direction: "pull"` deserialises
  the section into the list (for texts present in both, the file's
  active/overruled state wins; notes only the file has are added). the
  section is delimited by `<!-- structured-spec:start -->` /
  `<!-- structured-spec:end -->` markers; a note line is `- [ ] text`
  (active) or `- [x] text` (overruled), and a bare `- text` bullet is read
  as active, so hand edits survive. a missing `AGENTS.md` or section is an
  empty store, not an error.
- tooling: bun (runtime, test runner) + tsc (typecheck only). no build step.

## status

implemented and live (2026-11-28):

- the plugin is wired into the `plugins` array of `opencode.jsonc` — its tools
  (`add-rigorously`, `invalidate-rigorously`, `consult-specification`,
  `sync-specification`) load in every opencode session.
- `bun run check` passes: `tsc --noEmit` clean + `bun test` 24/24
  (`test/absorb.test.ts`, `test/decode.test.ts`, `test/section.test.ts`).
- step 2 is done as well: `skill/rigorize/SKILL.md` is installed globally
  (the `rigorize` skill).
- the agent files below remain as the implementation record:

1. `agent/01-plugin.md`  (implement the plugin)
2. `agent/02-global-skill.md`  (install `skill/rigorize/SKILL.md` globally, verbatim)
