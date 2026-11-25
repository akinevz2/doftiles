# agent spec 2/2: install the global `rigorize` skill

do this only after `01-plugin.md` is done and its definition of done is met.

target: opencode **v2.x.x** (`@opencode/cli`).

## intent

`skill/rigorize/SKILL.md` (in this repo) is a finished, deliberately terse
skill. it must reach the user's global opencode config byte for byte. you are
the courier, not the editor.

## do

1. read the v2 skills documentation (start at opencode.ai/docs, find the skills
   page; the v2 plugin docs show project skills at
   `.opencode/skills/<name>/SKILL.md`) and confirm:
   - the global skills directory for v2 (v1 used `~/.config/opencode/skill/`;
     v2 may use `skills/` plural or accept both). use the one the v2 docs name;
     if both are documented use the plural `skills/`. if the docs do not say,
     check what `opencode skill list` (or the closest cli command) reports, and
     state in the report how you decided.
   - the required frontmatter fields and constraints (expected: `name`
     lowercase alphanumeric with single hyphens and equal to the directory name;
     `description` 1 to 1024 characters).
2. create `<skills dir>/rigorize/` and copy `skill/rigorize/SKILL.md` into it
   unchanged (`cp`, not retyped).
3. diff the copy against the source. it must be identical.
4. start opencode v2 in a scratch directory and confirm a skill named
   `rigorize` is listed and loadable. if the host shows no list, say so instead
   of guessing.
5. dry run: in a scratch git repo with no `RIGOR.md`, ask the agent to
   "rigorize this project". confirm it (a) checks for `RIGOR.md`, (b) asks the
   single question about worrying flows, (c) stops after stage 1 and reports.
   do not continue past stage 1 in the dry run.

## only if the docs force it

if the docs require a different frontmatter shape, change ONLY the frontmatter
and report the exact diff. never touch the body.

## do not

- do not edit the skill body, shorten it, reformat it, or "improve" it. it is
  sized for small, heavily quantized models; every extra line costs context.
- do not edit `opencode.json`, permissions, or any other skill.
- do not add files next to `SKILL.md`.
- do not copy the plugin source into the skills directory.

## report

state: the exact path installed, the frontmatter constraints found (with doc
location), the diff result, whether the skill was listed, and the dry-run
outcome for each of (a) (b) (c). do not report success you did not observe.
