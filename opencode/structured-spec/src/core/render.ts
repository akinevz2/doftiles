import type { DecodeError } from "./decode.ts"
import type { NoteError, Notes } from "./notes.ts"
export const addToolName = "add-rigorously"
export const consultToolName = "consult-specification"
export const maxLineWidth = 96
export const overflowPrefix = "overflowing spec: ["
export const overflowSuffix = "] is too damn wide"
export const rewordLine =
  "nothing was added. ask the user to reword this note, or propose a shorter rewording yourself."
// plain :: string -> string
export const plain = (text: string): string => text
// red :: string -> string
export const red = (text: string): string => `\u001b[31m${text}\u001b[0m`
// renderOverflow :: (string -> string) -> string -> string
//   the plain line (prefix + shown + suffix) is at most maxLineWidth characters
export const renderOverflow =
  (paint: (text: string) => string) =>
  (overflow: string): string => {
    const budget = maxLineWidth - overflowPrefix.length - overflowSuffix.length
    const shown = overflow.length > budget ? `${overflow.slice(0, budget - 3)}...` : overflow
    return `${overflowPrefix}${paint(shown)}${overflowSuffix}`
  }
// renderNoteError :: NoteError -> string
export const renderNoteError = (error: NoteError): string =>
  error.tag === "empty"
    ? "rejected: a note must not be empty. nothing was added."
    : `${renderOverflow(plain)(error.overflow)}\n${rewordLine}`
// renderOverflowLines :: readonly NoteError[] -> readonly string[]
export const renderOverflowLines = (errors: readonly NoteError[]): readonly string[] =>
  errors.flatMap((error) =>
    error.tag === "tooLong" ? [renderOverflow(plain)(error.overflow)] : [],
  )
// renderConsultation :: Notes -> string
export const renderConsultation = (notes: Notes): string =>
  notes.length === 0
    ? "specification is empty. there is nothing to verify."
    : [
        `specification: ${notes.length} note(s). check your draft response against every note before you finish.`,
        notes.map((note, index) => `${index + 1}. ${note}`).join("\n"),
        "for each note: verify it against the facts of this conversation and the code you have actually read. if a note is not met or cannot be verified, fix the response or say so plainly. never claim a note is satisfied without checking it.",
      ].join("\n")
const rejectionHeader =
  "rejected from the user's notes block, not added. ask the user to reword each, or suggest one:"
// renderRejections :: readonly string[] -> string
export const renderRejections = (lines: readonly string[]): string =>
  lines.length === 0 ? "" : ["", rejectionHeader, ...lines].join("\n")
// renderDirective :: { notes: number; rejected: number } -> string | undefined
export const renderDirective = (counts: { readonly notes: number; readonly rejected: number }): string | undefined => {
  const base = counts.notes > 0 ? consultDirective(counts.notes) : rejectedOnly(counts.rejected)
  const tail = counts.notes > 0 && counts.rejected > 0 ? ` ${rejectedTail(counts.rejected)}` : ""
  return base === undefined ? undefined : `${base}${tail}`
}
const consultDirective = (notes: number): string =>
  `a specification list with ${notes} note(s) exists for this session. once you have fully read the user's request, and before you finalise your response, call the ${consultToolName} tool and verify your response against every note.`
const rejectedOnly = (rejected: number): string | undefined =>
  rejected > 0
    ? `the user's notes block had ${rejected} note(s) rejected as too wide. call the ${consultToolName} tool, then ask the user to reword them or suggest rewordings, before you finalise your response.`
    : undefined
const rejectedTail = (rejected: number): string =>
  `${rejected} note(s) from the user's notes block were rejected as too wide; the tool will say which.`
// renderAdded :: { added: number; total: number } -> string
export const renderAdded = (counts: { readonly added: number; readonly total: number }): string =>
  `added ${counts.added} note(s). specification now holds ${counts.total}.`
// renderDecodeError :: DecodeError -> string
export const renderDecodeError = (error: DecodeError): string =>
  `rejected: ${addToolName} expects { "notes": string[] }. nothing was added.`
