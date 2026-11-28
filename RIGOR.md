# rigor

## pairs
- $HOME deployment <-> repo source: scripts/rigor (R18 check)
- stow package content <-> git history: scripts/rigor (R19 checks)
- commit subjects <-> automation scope: scripts/rigor (C3/C4 advisory)
## invariants
- every tracked package file's $HOME deployment must resolve inside the repo.
- every stow package must be fully tracked in git (no version-less deploys).
## findings
- [x] R18 | scripts/rigor | rm through stow folds destroyed tracked source
      (system-theme, 2026-11-28) | guard: script (fold-drift check — failing
      sample: sandbox symlink to /tmp/outside flagged; passing: repo-resolving
      link accepted; untracked-sample file flagged, false positives on
      in-package links eliminated)
- [x] R19 | scripts/rigor | version-less packages (system-theme, polkit,
      desktop-environment, filemanager-sff) deploy unversioned data |
      guard: script (no-tracked-files + untracked-in-package checks; run
      2026-11-28 flagged all four plus genuinely uncommitted work)
- [x] C1-C4 | scripts/rigor | sweep/automation-commit classes from the
      20-commit audit | guard: script (node_modules sweep check FAIL +
      generic-contribute-subject WARN advisories)
## waived
