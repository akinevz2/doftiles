# structured-spec

opencode **v2** plugin (`@opencode/plugin`, `@opencode/cli` 2.x). keeps a per-session list of atomic notes; the model must consult
the list after receiving a complete user request and verify its response against
every note before finishing.

- tools: `add-rigorously`, `invalidate-rigorously`, `consult-specification`
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
- tooling: bun (runtime, test runner) + tsc (typecheck only). no build step.

## status

specification only. there is no implementation in this folder on purpose.
hand the agent files to your local agent in this order:

1. `agent/01-plugin.md`  (implement the plugin)
2. `agent/02-global-skill.md`  (install `skill/rigorize/SKILL.md` globally, verbatim)
