import { err, ok, fold } from "./result.ts"
import type { Result } from "./result.ts"
export type Note = { readonly text: string; readonly active: boolean }
export type Notes = readonly Note[]
export const maxNoteLength = 96
export type NoteError =
  | { readonly tag: "empty" }
  | { readonly tag: "tooLong"; readonly note: string; readonly overflow: string }
// emptyNotes :: Notes
export const emptyNotes: Notes = []
// normalise :: string -> string   (trims; collapses whitespace runs to one space)
export const normalise = (note: string): string => note.trim().replace(/\s+/g, " ")
type Split = { readonly head: readonly string[]; readonly overflow: readonly string[] }
const nextSplit = (state: Split, word: string): Split => {
  const candidate = state.head.length === 0 ? word : `${state.head.join(" ")} ${word}`
  const take = state.overflow.length === 0 && candidate.length <= maxNoteLength
  const head = take ? [...state.head, word] : state.head
  const overflow = take ? state.overflow : [...state.overflow, word]
  return { head, overflow }
}
// splitOverflow :: string -> { head: string; overflow: string }   (input already normalised)
export const splitOverflow = (note: string): { head: string; overflow: string } => {
  const split = note.split(" ").reduce<Split>(nextSplit, { head: [], overflow: [] })
  return { head: split.head.join(" "), overflow: split.overflow.join(" ") }
}
const emptyFailure = (note: string): Result<NoteError, string> | undefined =>
  note.length === 0 ? err({ tag: "empty" }) : undefined
const wideFailure = (note: string): Result<NoteError, string> | undefined =>
  note.length > maxNoteLength
    ? err({ tag: "tooLong", note, overflow: splitOverflow(note).overflow })
    : undefined
// validate :: string -> Result NoteError string
//   normalises first; empty -> err empty; length > maxNoteLength -> err tooLong
export const validate = (raw: string): Result<NoteError, string> => {
  const note = normalise(raw)
  return emptyFailure(note) ?? wideFailure(note) ?? ok(note)
}
const firstFailure = (validated: readonly Result<NoteError, string>[]): NoteError | undefined =>
  validated
    .map((result) => fold((error: NoteError): NoteError | undefined => error)((): undefined => undefined)(result))
    .find((error) => error !== undefined)
const okResults = (validated: readonly Result<NoteError, string>[]): readonly string[] =>
  validated.flatMap(
    fold<NoteError, string, readonly string[]>(() => [])((value) => [value]),
  )
const errorResults = (validated: readonly Result<NoteError, string>[]): readonly NoteError[] =>
  validated.flatMap(
    fold<NoteError, string, readonly NoteError[]>((error) => [error])(() => []),
  )
const dedupeStrings = (texts: readonly string[]): readonly string[] =>
  texts.reduce<readonly string[]>((kept, text) => (kept.includes(text) ? kept : [...kept, text]), [])

const merge = (notes: Notes, text: string): Notes => {
  const index = notes.findIndex((note) => note.text === text)
  if (index < 0) return [...notes, { text, active: true }]
  return notes.map((note, at) => (at === index ? { ...note, active: true } : note))
}
const mergeAll = (notes: Notes, texts: readonly string[]): Notes => texts.reduce(merge, notes)
// addNotes :: Notes -> readonly string[] -> Result NoteError Notes
//   ATOMIC. validates ALL incoming first; appends in order, deduped, or the FIRST error.
//   a text already present but inactive is re-activated instead of duplicated.
export const addNotes =
  (notes: Notes) =>
  (raw: readonly string[]): Result<NoteError, Notes> => {
    const validated = raw.map(validate)
    const failure = firstFailure(validated)
    return failure === undefined ? ok(mergeAll(notes, okResults(validated))) : err(failure)
  }
// addEach :: Notes -> readonly string[] -> { notes: Notes; errors: readonly NoteError[] }
//   NON-ATOMIC. valid notes appended as in addNotes; one error per invalid note
export const addEach =
  (notes: Notes) =>
  (raw: readonly string[]): { notes: Notes; errors: readonly NoteError[] } => {
    const validated = raw.map(validate)
    return { notes: mergeAll(notes, okResults(validated)), errors: errorResults(validated) }
  }
export type DropOutcome = { readonly notes: Notes; readonly dropped: number; readonly missing: readonly string[] }
export type OverruleOutcome = {
  readonly notes: Notes
  readonly overruled: number
  readonly missing: readonly string[]
}
// dropNotes :: Notes -> readonly string[] -> DropOutcome
//   removes EVERY note whose text matches a query (any state). queries unmatched by
//   any note are reported in `missing` (deduped, input order). nothing is validated:
//   a query that is empty or too wide simply matches nothing.
export const dropNotes =
  (notes: Notes) =>
  (raw: readonly string[]): DropOutcome => {
    const queries = dedupeStrings(raw.map(normalise))
    const kept = notes.filter((note) => !queries.includes(note.text))
    const missing = queries.filter((query) => !notes.some((note) => note.text === query))
    return { notes: kept, dropped: notes.length - kept.length, missing }
  }
// overruleNotes :: Notes -> readonly string[] -> OverruleOutcome
//   marks EVERY matching active note inactive, keeping its text for reference.
//   queries unmatched by any note are reported in `missing` (deduped, input order).
export const overruleNotes =
  (notes: Notes) =>
  (raw: readonly string[]): OverruleOutcome => {
    const queries = dedupeStrings(raw.map(normalise))
    let overruled = 0
    const next = notes.map((note) => {
      if (!note.active || !queries.includes(note.text)) return note
      overruled += 1
      return { ...note, active: false }
    })
    const missing = queries.filter((query) => !notes.some((note) => note.text === query))
    return { notes: next, overruled, missing }
  }
// countActive :: Notes -> number
export const countActive = (notes: Notes): number => notes.filter((note) => note.active).length
// countInactive :: Notes -> number
export const countInactive = (notes: Notes): number => notes.length - countActive(notes)
// absorbNotes :: Notes -> Notes -> Notes
//   merges the durable store into the session list (file first): a text present
//   in both takes the FILE's active flag; session-only and file-only texts keep
//   their own flag; order is session order then unseen file order.
export const absorbNotes = (file: Notes) => (session: Notes): Notes => {
  const stored = (note: Note): Note => {
    const match = file.find((other) => other.text === note.text)
    return match === undefined ? note : { text: note.text, active: match.active }
  }
  const unseen = file.filter((note) => !session.some((other) => other.text === note.text))
  return [...session.map(stored), ...unseen]
}
const blockPattern = /```notes[ \t]*\n([\s\S]*?)```/g
const bulletPattern = /^[ \t]*[-*][ \t](.*)$/gm
// parseBlocks :: string -> readonly string[]
//   raw notes from every fenced block whose info string is exactly `notes`
export const parseBlocks = (text: string): readonly string[] =>
  [...text.matchAll(blockPattern)].flatMap((block) =>
    [...(block.at(1) ?? "").matchAll(bulletPattern)].flatMap((bullet) => [bullet.at(1) ?? ""]),
  )
