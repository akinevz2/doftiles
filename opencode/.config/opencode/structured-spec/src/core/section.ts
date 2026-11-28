import { normalise, emptyNotes } from "./notes.ts"
import type { Note, Notes } from "./notes.ts"
import { err, ok } from "./result.ts"
import type { Result } from "./result.ts"

export const startMarker = "<!-- structured-spec:start -->"
export const endMarker = "<!-- structured-spec:end -->"
export const sectionHeading = "## Rigorous reminders (structured-spec)"

export type SectionError = { readonly tag: "unterminated" }

const markerRow = (marker: string) => (row: string): boolean => row.trim() === marker
const bulletRow = /^[ \t]*[-*][ \t]+(?:\[([ xX])\][ \t]+)?(.*)$/

// parseRow :: string -> readonly Note[]
//   `- [ ] text` is active, `- [x] text` (any case) is overruled, a bare
//   `- text` bullet is active; every other row contributes nothing.
const parseRow = (row: string): readonly Note[] => {
  const match = bulletRow.exec(row)
  const mark = match?.at(1)
  const text = normalise(match?.at(2) ?? "")
  return text.length === 0 ? [] : [{ text, active: mark === undefined || mark === " " }]
}

// parseSection :: string -> Result SectionError Notes
//   the first start..end marker span becomes notes (one per bullet row);
//   every other row in the span (heading, blank, prose) is ignored. a start
//   marker with no end marker is err unterminated. no span at all is ok empty.
export const parseSection = (document: string): Result<SectionError, Notes> => {
  const rows = document.split("\n")
  const start = rows.findIndex(markerRow(startMarker))
  if (start < 0) return ok(emptyNotes)
  const end = rows.slice(start + 1).findIndex(markerRow(endMarker))
  return end < 0 ? err({ tag: "unterminated" }) : ok(rows.slice(start + 1, start + 1 + end).flatMap(parseRow))
}

// renderSection :: Notes -> string
//   the full marked section: start marker, heading, one checkbox row per note
//   in list order, end marker. no trailing newline; the splice owns separators.
export const renderSection = (notes: Notes): string =>
  [startMarker, sectionHeading, "", ...notes.map((note) => `- [${note.active ? " " : "x"}] ${note.text}`), endMarker].join("\n")

const gapOf = (document: string): string => {
  if (document.endsWith("\n\n")) return ""
  return document.endsWith("\n") ? "\n" : "\n\n"
}

const appendSection = (document: string) => (section: string): string =>
  document.trim().length === 0 ? `${section}\n` : `${document}${gapOf(document)}${section}\n`

const joinRows = (rows: readonly string[]): string => {
  const joined = rows.join("\n")
  return joined.length === 0 || joined.endsWith("\n") ? joined : `${joined}\n`
}

// spliceSection :: string -> string -> string
//   `section` replaces the first marker span in `document`; a document without
//   a span gets the section appended (one blank line first); an empty document
//   is just the section. the result always ends with exactly one newline.
//   an unterminated span passes through unchanged (parseSection reports it).
export const spliceSection = (section: string) => (document: string): string => {
  const rows = document.split("\n")
  const start = rows.findIndex(markerRow(startMarker))
  if (start < 0) return appendSection(document)(section)
  const end = rows.slice(start + 1).findIndex(markerRow(endMarker))
  if (end < 0) return document
  return joinRows([...rows.slice(0, start), section, ...rows.slice(start + 2 + end)])
}
