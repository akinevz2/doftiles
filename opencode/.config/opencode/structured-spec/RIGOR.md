# rigor

## pairs
- add-tool <-> addNotes: src/shell/tools.ts, src/core/notes.ts
- prompt-hook <-> addEach: src/shell/hooks.ts, src/core/notes.ts
- reject <-> drain/consult: src/shell/hooks.ts, src/shell/tools.ts, src/shell/store.ts
- amend overrule/drop/add <-> rendered totals: src/shell/tools.ts
- sync push/pull <-> section parse/render/splice: src/shell/sync.ts, src/shell/agents.ts, src/core/section.ts
## invariants
- an entry path that mutates notes must be atomic (all-or-first-error); a partial
  mutation must not be reported as success.
- a rejection must survive until the model has seen it (consult drains only after
  delivery, not before).
- a push must never write an empty list over the store (the tool refuses first).
- a push changes only the marker span's content; every byte of AGENTS.md outside
  the span passes through untouched (splice, never a whole-file rewrite).
## findings
- [ ] P1 | src/shell/tools.ts:108-127 | amendContent applies overrule+drop BEFORE the
      add validates; on add error the first two mutations stay applied while the
      response renders only the error — partial amend, non-atomic, contradicts
      addNotes' ATOMIC doctrine | guard: none
- [ ] P2 | src/shell/tools.ts:87-89 | consult DRAINS pending rejections on read; a
      second consult (or an add success that re-renders) loses the rejection report
      — destructive read, rejection may never reach the model | guard: none
- [ ] P3 | src/shell/hooks.ts:14 | prompt hook uses NON-atomic addEach (partial
      writes accepted, wide notes silently kept off) while the add tool uses atomic
      store.add — two stacks for one entry path | guard: none
## waived
