import { err, ok, fold } from "./result.ts"
import type { Result } from "./result.ts"
export type Notes = readonly string[]
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
const dedupe =
  (existing: readonly string[]) =>
  (incoming: readonly string[]): readonly string[] => {
    const step = (kept: readonly string[], note: string): readonly string[] =>
      kept.includes(note) ? kept : [...kept, note]
    return incoming.reduce(step, existing)
  }
// addNotes :: Notes -> readonly string[] -> Result NoteError Notes
//   ATOMIC. validates ALL incoming first; appends in order, deduped, or the FIRST error
export const addNotes =
  (notes: Notes) =>
  (raw: readonly string[]): Result<NoteError, Notes> => {
    const validated = raw.map(validate)
    const failure = firstFailure(validated)
    return failure === undefined ? ok(dedupe(notes)(okResults(validated))) : err(failure)
  }
// addEach :: Notes -> readonly string[] -> { notes: Notes; errors: readonly NoteError[] }
//   NON-ATOMIC. valid notes appended as in addNotes; one error per invalid note
export const addEach =
  (notes: Notes) =>
  (raw: readonly string[]): { notes: Notes; errors: readonly NoteError[] } => {
    const validated = raw.map(validate)
    return { notes: dedupe(notes)(okResults(validated)), errors: errorResults(validated) }
  }
const blockPattern = /```notes[ \t]*\n([\s\S]*?)```/g
const bulletPattern = /^[ \t]*[-*][ \t](.*)$/gm
// parseBlocks :: string -> readonly string[]
//   raw notes from every fenced block whose info string is exactly `notes`
export const parseBlocks = (text: string): readonly string[] =>
  [...text.matchAll(blockPattern)].flatMap((block) =>
    [...(block.at(1) ?? "").matchAll(bulletPattern)].flatMap((bullet) => [bullet.at(1) ?? ""]),
  )
