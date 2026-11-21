---
name: rigorize
description: Find silently broken or confusing behaviour, add guards. Use to rigorize or audit.
---

# rigorize

Security-critical task. Short steps. Stop after each stage, report in 10 lines max.

Origin: a password reset emailed "changed" while login rejected the new password.
Two paths, no shared contract, success announced before verified. Find that class of bug.

## 0. resume check
- Read RIGOR.md in the repo root.
- Also look for scripts/rigor*, tests/rigor/, lint rules named *rigor*.
- Missing -> stage 1. Present -> do the first open `- [ ]` item, continue from its stage.
- Partial work found outside RIGOR.md -> list it in RIGOR.md first.
- User lines in RIGOR.md win. Append only. Never delete or reword them. Ask on conflict.

## 1. define RIGOR.md
Ask ONE question: "which flows worry you most?" Rank by the answer.
Create RIGOR.md, every line <=96 chars:

    # rigor
    ## pairs
    - reset <-> login: <files>
    ## invariants
    - a changed password must verify at login.
    ## findings
    - [ ] R1 | file:line | what breaks | guard: lint|script|test|none
    ## waived

If tool add-rigorously exists, call it with the invariants.

## 2. analyse (low effort: grep first, read <=10 files)
Find paired paths and gaps:
- write/read pairs: create/verify, hash/compare, encode/decode, save/load, serialize/parse.
- success announced before the write is awaited or checked (email, log, toast, 200).
- drift: two normalisers (trim, case, length, charset, unicode) for one field.
- masked errors: catch-all, empty catch, ignored return, generic "invalid".
- two stacks for one feature: legacy + new, duplicated validation.
- writes never read back or asserted.
- auth, reset, payment, delete flows without an end-to-end test.
- user comms that bury the required action.
Rank by blast radius. Record <=10 findings in RIGOR.md. Do not change app code unless asked.

## 3. convert (cheapest durable guard first)
1. Linter exists -> custom rule (eslint, ruff, semgrep, clippy, ast-grep).
2. No linter -> companion script or metaprogramming that fails CI.
   (grep/AST check, generated shared contract)
3. Neither -> ask the user first. Only on a yes: one test file per finding.
   Path: tests/rigor/<id>. Discouraged.
Prove each guard: run it on a failing and a passing sample, show both.
Mark [x] only then.

## rules
- Never claim fixed without running it.
- Prefer one shared function over two copies. Propose, do not refactor unasked.
- If tool consult-specification exists, call it before the final answer.
