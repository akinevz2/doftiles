# agent spec 1/2: implement the `structured-spec` opencode plugin (opencode v2)

target: opencode **v2.x.x** (`@opencode/cli`; the binary may be `opencode2` if
v1 is also installed). plugin api package: **`@opencode/plugin`**.
v1 plugins (`@opencode-ai/plugin`, returned hook objects, `tool()` helper, zod)
do NOT run in v2. do not use any of that.

you are implementing a small plugin in typescript. read this whole file before
writing code. where this file and your habits disagree, this file wins. where
this file and the installed `@opencode/plugin` types disagree, the installed
types win (see "verify first") and you report the delta.

## what it does

a per-session list of atomic notes (plain strings). the model is steered to:

1. receive the user's complete request,
2. call `consult-specification`,
3. check its draft response against every note, fix or flag what fails,
4. only then finish.

notes get into the list two ways:

- the model calls the tool `add-rigorously` (because the user asked it to), or
- the user's prompt contains a fenced block whose info string is `notes`.
  the plugin parses it in the `prompt` session hook, no model involvement.

state is in-memory, keyed by session id. no persistence, no config. the only
console output is the red overflow line described below.
(`ctx.storage` exists and could persist later. do not use it now.)

## v2 api facts this spec relies on (confirm against installed types)

source: opencode.ai/docs/build/plugins/server and .../migrate-v1.

- entrypoint: `export default Plugin.define({ id, async setup(ctx) { ... } })`
  with `import { Plugin } from "@opencode/plugin"`. `id` must be stable.
- tools: registered inside `setup` via a **synchronous** transform:
  `await ctx.tool.transform((editor) => { editor.add({ name, description,
  input: <json schema>, execute: async (input, context) => ({ content }) }) })`.
  `input` is a plain JSON schema object. `execute` receives `input` as
  `unknown`-ish and `context` with `sessionID`, `agent`, `messageID`, `id`,
  `signal`. it returns `{ content: string }`.
- hooks: `await ctx.session.hook("<name>", (event) => { ... })`. the callback
  receives ONE mutable event (no separate input/output).
  - `"prompt"`: runs once per incoming user prompt at admission. event has
    `prompt.text` (string), plus readonly session and message ids.
    prompt hooks must be retry-safe.
  - `"context"`: runs immediately before each agent-loop model request
    (including tool-driven continuations). event has readonly `sessionID`,
    `system: SystemPart[]` (parts look like `{ type: "text", text }`),
    `messages`, `tools`, `options`.
- registrations live as long as the plugin; no manual disposal needed.
- do NOT use `tool.hook("execute.before"/"execute.after")`, events, storage,
  commands, or skills transforms. not needed.

## verify first (do this before coding)

1. `opencode --version` (or `opencode2 --version`). note it.
2. `bun add @opencode/plugin` (pin to the version family matching the CLI;
   replace `"latest"` in `package.json` with the exact version afterwards).
3. open the installed types under `node_modules/@opencode/plugin/` and confirm
   the exact shapes of: `Plugin.define`, the setup context type, the tool
   editor's `add` argument, the tool `execute` context, the `prompt` and
   `context` session hook events (especially: does the `prompt` event carry
   `sessionID`? is `system` an array of `{type:"text",text}`?).
4. read opencode.ai/docs/build/plugins (overview) for plugin layout and
   discovery. local discovery is `.opencode/plugins/<dir>/index.ts`; configured
   paths in `opencode.jsonc` `"plugins"` must be directories.
5. if any signature in this spec is wrong, adapt the `shell/` layer only (never
   `core/`) and list every deviation in your final report.
6. check effective tool names with `ctx.tool.list()` in a scratch run. the host
   rewrites unsupported characters in tool names to `_`. if `add-rigorously`
   or `consult-specification` are rewritten, change only the two name constants
   in `core/render.ts` and report it.

## tooling decisions (already made, do not revisit)

- bun is the runtime, package manager, and test runner. tsc is typecheck only.
- no bundler, no build step, no `dist`. esm only. `main` points at `src/index.ts`.
- only dependency: `@opencode/plugin`. no zod, no effect, no other package.
  schemas are plain JSON schema objects; input decoding is hand-written in core.

## file layout (exactly this, no extra files)

```
src/
  index.ts          shell: the single (default) export
  core/
    fn.ts           pipe, absurd
    result.ts       Result, ok, err, fold
    notes.ts        Notes + pure note operations
    decode.ts       decodeNotesInput (the only place `unknown` is allowed)
    render.ts       pure text rendering + the two tool-name constants
  shell/
    ref.ts          the one mutable cell (IORef analogue)
    store.ts        session store built on ref + core/notes
    report.ts       the one console effect (red overflow lines)
    tools.ts        registerTools
    hooks.ts        registerHooks
test/
  notes.test.ts
  decode.test.ts
  render.test.ts
```

`core/` imports nothing except other `core/` files. `shell/` may import `core/`
and `@opencode/plugin`. `core/` never sees opencode types.

## code style (non-negotiable)

write this as if a haskell programmer fluent in typescript had to keep it tidy.
functional core, imperative shell. boring, total, small.

### forbidden

`let`, `var`, `class`, `this`, `enum`, `namespace`, `any`, type assertions
(`as X`) except `as const`, non-null `!`, `null` (use `undefined`),
`for`/`while`/`do`, `forEach`, `push`/`splice`/`sort`/`reverse` on shared data
(copy first), `throw` anywhere except `absurd`, `try/catch` anywhere,
optional-chain chains longer than one hop, nested ternaries, `switch` without
exhaustive `absurd`, comments other than the signature comments below,
`default` exports except in `src/index.ts` (the host requires it there),
`unknown` outside `core/decode.ts`, `new` outside `shell/ref.ts` and the one
map-copy helper in `shell/store.ts`.

sanctioned host-boundary effects, nothing else: `event.system.push(...)` in the
`context` hook (the host hands you a mutable draft), the `Ref` update in
`shell/ref.ts`, and `console.error` in `shell/report.ts`.

### required

- `const` arrow functions; one-expression bodies where clean, else a block with
  a single `return` at the end.
- every parameter and return type annotated on exported functions.
- `readonly` everywhere: `readonly string[]`, `Readonly<Record<...>>`,
  `ReadonlyMap`. never mutate an argument.
- discriminated unions with a `tag` field for anything with more than one shape;
  exhaustive matching through `absurd`.
- failure is a value: `Result<E, A>`. core never throws. tool `execute`
  functions always return `{ content: string }`; errors are rendered into the
  string, never thrown to the host.
- functions at most 8 lines, at most 2 parameters (take a record for more).
  files at most 80 lines.
- compose with `pipe` when a value flows through 3+ steps; otherwise call
  directly.
- names: verbs for functions (`addNotes`, `parseBlocks`), nouns for values. no
  abbreviations except `xs`, `ok`, `err`, `fn`. never `utils`, `helpers`,
  `manager`, `service`, `handler`.
- every exported function carries exactly one signature comment directly above
  it, haskell-style, e.g.
  `// addNotes :: Notes -> readonly string[] -> Result NoteError Notes`
  these are the only comments in the codebase.
- formatting: 2 spaces, no semicolons, double quotes, trailing commas, 80
  columns, named exports (except `index.ts`). `import type` for types.

## core modules, exact contracts

### `core/fn.ts`

```ts
// pipe :: a -> (a -> b) -> ... -> z       (overloads for 2, 3, 4 functions)
// absurd :: never -> never                (the only `throw` in the codebase)
```

### `core/result.ts`

```ts
export type Result<E, A> =
  | { readonly tag: "err"; readonly error: E }
  | { readonly tag: "ok"; readonly value: A }
// ok :: a -> Result e a
// err :: e -> Result e a
// fold :: (e -> b) -> (a -> b) -> Result e a -> b
```

### `core/notes.ts`

```ts
export type Notes = readonly string[]
export const maxNoteLength = 96
export type NoteError =
  | { readonly tag: "empty" }
  | {
      readonly tag: "tooLong"
      readonly note: string
      readonly overflow: string
    }

// emptyNotes :: Notes
// normalise :: string -> string
//   trims; collapses every run of whitespace (incl. newlines) to one space
// splitOverflow :: string -> { head: string; overflow: string }
//   input is an already-normalised note. head is the longest prefix made of
//   WHOLE words (single-space separated) with length <= maxNoteLength.
//   overflow is every remaining word joined by single spaces ("" if none).
//   a single first word longer than maxNoteLength gives head "" and overflow
//   = that word and everything after it. invariant: when overflow is
//   non-empty, head + " " + overflow === input (or just overflow if head is "").
// validate :: string -> Result NoteError string
//   normalises first; empty -> err empty; length > maxNoteLength -> err tooLong
//   with `overflow` from splitOverflow (so overflow is never ""); a note of
//   exactly 96 characters is valid, 97 is not.
// addNotes :: Notes -> readonly string[] -> Result NoteError Notes
//   ATOMIC. validates ALL incoming first; if any fails, returns the FIRST
//   error and changes nothing. otherwise appends in order, dropping any note
//   already present (case-sensitive, after normalisation) and any duplicate
//   within the batch. first-appearance order preserved. idempotent: this is
//   what makes the prompt hook retry-safe.
// addEach :: Notes -> readonly string[] ->
//            { notes: Notes; errors: readonly NoteError[] }
//   NON-ATOMIC. validates each raw note on its own. valid ones are appended as
//   in addNotes (dedupe, order); each invalid one contributes its NoteError,
//   in input order. idempotent for the same reason as addNotes.
// parseBlocks :: string -> readonly string[]
//   extracts raw notes from every fenced block whose info string is exactly
//   `notes` (grammar below). total: text without blocks -> [].
```

#### grammar for a notes block

````
```notes
- first atomic reminder
- second atomic reminder
* a star bullet also works
continuation lines (no bullet) are ignored
```
````

- opening fence: three backticks immediately followed by `notes`, optional
  spaces, newline. `notesfoo` and `note` do not match.
- closing fence: three backticks.
- each line whose first non-space characters are `- ` or `* ` yields one raw
  note (rest of the line; `validate` normalises it).
- every other line inside the block (blank, prose) is ignored.
- any number of blocks per message; all parsed, in order.
- implement with one `matchAll` for blocks and one `flatMap` over lines with a
  second small regex. no manual index walking.

### `core/decode.ts`

```ts
export type DecodeError = { readonly tag: "notStringArray" }
// decodeNotesInput :: unknown -> Result DecodeError (readonly string[])
//   accepts an object whose `notes` property is an array of strings (extra
//   keys ignored). anything else -> err notStringArray. this is the only
//   function in the codebase allowed to take `unknown`. no assertions: narrow
//   with typeof / Array.isArray / small type-predicate helpers.
```

### `core/render.ts`

exact wording below; do not paraphrase, the wording is part of the behaviour.

```ts
export const addToolName = "add-rigorously"
export const consultToolName = "consult-specification"
```

```ts
// renderConsultation :: Notes -> string
```

non-empty (n = length):

```
specification: <n> note(s). check your draft response against every note before you finish.
1. <note>
2. <note>
...
for each note: verify it against the facts of this conversation and the code you have actually read. if a note is not met or cannot be verified, fix the response or say so plainly. never claim a note is satisfied without checking it.
```

empty:

```
specification is empty. there is nothing to verify.
```

```ts
export const maxLineWidth = 96
export const overflowPrefix = "overflowing spec: ["
export const overflowSuffix = "] is too damn wide"
export const rewordLine =
  "nothing was added. ask the user to reword this note, or propose a shorter rewording yourself."
// plain :: string -> string          (identity)
// red :: string -> string            (wraps in "\u001b[31m" ... "\u001b[0m")
// renderOverflow :: (string -> string) -> string -> string
```

`renderOverflow paint overflow` builds
`overflowPrefix + paint(shown) + overflowSuffix`, where `shown` is `overflow`
cut so the PLAIN line (ignoring any ansi codes) is at most `maxLineWidth`
characters: budget = `maxLineWidth - overflowPrefix.length - overflowSuffix.length`
(59). if `overflow.length` exceeds the budget, `shown` is the first
`budget - 3` characters followed by `...`; otherwise `shown` is `overflow`.
derive the budget from the constants, never hardcode 59. only the overflow
words are painted, never the prefix or suffix.

example, with a note whose overflow is `never write wide specification`:

```
overflowing spec: [never write wide specification] is too damn wide
```

```ts
// renderNoteError :: NoteError -> string
```

- empty -> `rejected: a note must not be empty. nothing was added.`
- tooLong -> `renderOverflow(plain, overflow)` + newline + `rewordLine`.
  every line of every message this module produces is at most 96 characters.

```ts
// renderOverflowLines :: readonly NoteError[] -> readonly string[]
```
for each `tooLong` error, `renderOverflow(plain, overflow)`; other tags yield
nothing.

```ts
// renderRejections :: readonly string[] -> string
```
empty list -> `""`. otherwise a newline, the header, a newline, then the lines
joined by newlines. header (exact):
`rejected from the user's notes block, not added. ask the user to reword each, or suggest one:`

```ts
// renderDirective :: { notes: number; rejected: number } -> string | undefined
```

- `notes = 0` and `rejected = 0` -> `undefined`.
- `notes > 0` -> exactly (tool name from the constant):

```
a specification list with <notes> note(s) exists for this session. once you have fully read the user's request, and before you finalise your response, call the consult-specification tool and verify your response against every note.
```

- `notes = 0` and `rejected > 0` -> exactly:

```
the user's notes block had <rejected> note(s) rejected as too wide. call the consult-specification tool, then ask the user to reword them or suggest rewordings, before you finalise your response.
```

- if `notes > 0` and `rejected > 0`, append one space and exactly:
  `<rejected> note(s) from the user's notes block were rejected as too wide; the tool will say which.`

```ts
// renderAdded :: { added: number; total: number } -> string
```
`added <added> note(s). specification now holds <total>.`
(`added` = `after.length - before.length`.)

```ts
// renderDecodeError :: DecodeError -> string
```
`rejected: add-rigorously expects { "notes": string[] }. nothing was added.`

## shell modules, exact contracts

### `shell/ref.ts`

```ts
export type Ref<A> = { value: A }
// newRef :: a -> Ref a
// readRef :: Ref a -> a
// modifyRef :: Ref a -> (a -> a) -> void
```
the only module that assigns to a property.

### `shell/store.ts`

```ts
export type Store = {
  readonly get: (sessionID: string) => Notes
  readonly add: (
    sessionID: string,
    raw: readonly string[],
  ) => Result<NoteError, Notes>
  readonly addEach: (
    sessionID: string,
    raw: readonly string[],
  ) => readonly NoteError[]
  readonly reject: (sessionID: string, lines: readonly string[]) => void
  readonly pending: (sessionID: string) => readonly string[]
  readonly drain: (sessionID: string) => readonly string[]
}
// makeStore :: () -> Store
```
backed by two refs: `Ref<ReadonlyMap<string, Notes>>` for notes and
`Ref<ReadonlyMap<string, readonly string[]>>` for rejection lines the model has
not been told about yet. `add` uses `addNotes` (atomic, for the tool);
`addEach` uses core `addEach` (for the prompt hook), stores the valid notes and
returns the errors. `reject` appends lines. `pending` reads them. `drain`
returns them and clears them. map updates copy the old map (`new Map(old)`,
then `set`) inside one 3-line helper.

### `shell/report.ts`

```ts
// reportErrors :: readonly NoteError[] -> void
```
for each `tooLong` error: `console.error(renderOverflow(red, overflow))`.
nothing for other tags. this is the user-facing, coloured copy of the error;
the model never receives ansi codes. the plugin runs inside the opencode
server process, so during the smoke test find out where this line actually
appears (tui, server log, stderr) and report it. do not add another output
channel.

### `shell/tools.ts`

```ts
// registerTools :: (Ctx, Store) -> Promise<void>
```
one `ctx.tool.transform` call, two `editor.add` calls. no `namespace` (a
namespace would prefix the names).

- `add-rigorously`
  - description (exact): `add atomic reminders to this session's specification list. each note must be one short, self-contained, checkable statement (at most 96 characters). use when the user asks you to remember, enforce, or keep in mind specific requirements.`
  - input schema:
    `{ type: "object", properties: { notes: { type: "array", items: { type: "string" }, description: "atomic reminders, one statement each" } }, required: ["notes"], additionalProperties: false }`
  - do NOT put `maxLength` in the json schema: the host would reject with its
    own generic message before our code runs. the 96 limit lives in core only.
  - execute: `decodeNotesInput(input)` then `store.add(context.sessionID, notes)`
    through `Result`; render with the core functions. success content is
    `renderAdded(...)` + newline + `renderConsultation(newNotes)`. failures are
    `renderDecodeError` / `renderNoteError`; on a `NoteError`, also call
    `reportErrors([error])`. always `{ content }`.
- `consult-specification`
  - description (exact): `read this session's specification list. call it after you have received the user's complete request and before you finalise your response, then verify your response against every note.`
  - input schema: `{ type: "object", properties: {}, additionalProperties: false }`
  - execute: take `store.drain(context.sessionID)` first, then content is
    `renderConsultation(store.get(id)) + renderRejections(lines)`. always
    `{ content }`.

### `shell/hooks.ts`

```ts
// registerHooks :: (Ctx, Store) -> Promise<void>
```

- `ctx.session.hook("prompt", ...)`: `parseBlocks(event.prompt.text)`; if
  non-empty, `errors = store.addEach(event.sessionID, raw)`, then
  `reportErrors(errors)`, then
  `store.reject(event.sessionID, renderOverflowLines(errors))`. valid notes in a
  block are kept even when a sibling is too wide. never edit `event.prompt`,
  never interrupt the user's prompt. if the installed event does not expose a
  session id, say so in the report and stop; do not invent a workaround.
- `ctx.session.hook("context", ...)`: `renderDirective({ notes:
  store.get(id).length, rejected: store.pending(id).length })` with
  `id = event.sessionID`; if `undefined`, do nothing; otherwise
  `event.system.push({ type: "text", text })` exactly once. register for
  `context` ONLY (not compaction, generate, title).

### `src/index.ts`

```ts
import { Plugin } from "@opencode/plugin"

// setup :: Ctx -> Promise<void>
export default Plugin.define({
  id: "structured-spec",
  setup: async (ctx) => {
    const store = makeStore()
    await registerTools(ctx, store)
    await registerHooks(ctx, store)
  },
})
```
this is the ONLY export of the file; do not re-export anything from it.

## tests (bun:test, pure core only)

- `notes.test.ts`: `normalise` trims and collapses whitespace/newlines;
  `splitOverflow` (a 96-char note -> overflow ""; a 100-char note of short
  words -> head <= 96 chars, ends on a whole word, `head + " " + overflow`
  equals the input; the spec example splits as head `...and you must` /
  overflow `never write wide specification` when padded so "must" ends at or
  before column 96 and "never" would cross it; a single 120-char word -> head
  "" and overflow is that word);
  `validate` (empty -> `empty`, 97 chars -> `tooLong` with non-empty
  overflow, 96 -> ok); `addNotes` (appends in order; adding the same batch
  twice equals once; dedupes within a batch; one invalid note rejects the whole
  batch, list unchanged); `addEach` (valid notes kept, one error per invalid
  note in input order, idempotent);
  `parseBlocks` (no blocks -> `[]`; mixed `-`/`*` bullets; non-bullet lines
  ignored; two blocks in order; `notesfoo` does not match; indented bullets
  match; a plain ```ts block is ignored).
- `decode.test.ts`: accepts `{ notes: ["a"] }`; rejects `{}`, `{ notes: "a" }`,
  `{ notes: [1] }`, `undefined`, `null`, `[]`; ignores extra keys.
- `render.test.ts`: exact-string assertions for every render function (both
  empty and 2-note forms of consultation; all four directive cases).
  `renderOverflow`: exact string for the `never write wide specification`
  example; a 200-char overflow is truncated so the plain line is exactly
  96 chars and ends with `...`; `red` wraps only the overflow (check the
  ansi bytes sit inside the brackets); `plain` output contains no `\u001b`.
  property: every line of `renderNoteError` and `renderRejections` output is at
  most 96 characters. (the directive and consultation text are model-facing
  prose and are not bound by this.)
- no tests for `shell/`, no mocks. if the shell needs a mock to be tested,
  logic leaked into it; move the logic to `core/`.

## definition of done

in order:

1. `bun run check` passes, zero errors, zero warnings.
2. no file over 80 lines, no function over 8 lines, no forbidden construct
   (grep for `let `, `class `, `any`, `forEach`, `for (`, `throw`, ` as `;
   only `absurd` may throw).
3. smoke test in a scratch directory (not this repo): create
   `.opencode/plugins/structured-spec/index.ts` containing exactly
   `export { default } from "<absolute path to this repo>/src/index.ts"`,
   start opencode v2 there and confirm: the plugin appears in the active plugin
   list with id `structured-spec`; both tools are listed (check effective
   names); a prompt containing a ```notes block makes `consult-specification`
   list those notes; `add-rigorously` with a 100-character note returns the
   exact two-line rejection (overflow line, then the reword line), and the same
   overflow line appears in red on the console; a prompt with a ```notes block
   holding one valid note and one 100-character note keeps the valid one,
   prints the red line, and `consult-specification` then lists the valid note
   plus the rejection header and overflow line (once; a second call no longer
   shows it); with notes present, the model is told (via the system directive)
   to consult before finishing.
4. report: files created, installed `@opencode/plugin` version, every signature
   deviation from this spec, effective tool names, and anything you chose not
   to implement. do not report success you did not observe.

## known limits (do not fix, just keep in mind)

- sub-agent sessions have their own session ids, so they start with an empty
  list. parent notes are not inherited.
- the directive is injected on every agent-loop model request while notes
  exist, including tool-driven continuations. that is intended.
- state is lost when the server restarts.

## scope fence

do not add: persistence, config or plugin options, environment variables,
any logging beyond the red overflow line, extra tools, extra hooks, commands, a skill registration, a cli, a
build step, a linter/formatter dependency, or abstractions "for later". if you
think something is missing, say so in the report instead of building it.
