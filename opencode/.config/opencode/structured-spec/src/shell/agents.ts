import { countInactive } from "../core/notes.ts"
import type { Notes } from "../core/notes.ts"
import { parseSection, renderSection, spliceSection } from "../core/section.ts"
import type { SectionError } from "../core/section.ts"
import { fold, err, ok } from "../core/result.ts"
import type { Result } from "../core/result.ts"
import { readText, writeText } from "./file.ts"
import type { ReadError, WriteError } from "./file.ts"

export type SyncError =
  | { readonly tag: "read"; readonly reason: string }
  | { readonly tag: "write"; readonly reason: string }
  | { readonly tag: "unterminated" }
export type PushOutcome = { readonly written: number; readonly inactive: number; readonly released: number }

// documentOf :: Result ReadError string -> Result SyncError string
//   a missing file is an empty document; only an unreadable one is an error
const documentOf = (stored: Result<ReadError, string>): Result<SyncError, string> => {
  if (stored.tag === "err") {
    if (stored.error.tag === "notFound") return ok("")
    return err({ tag: "read", reason: stored.error.reason })
  }
  return ok(stored.value)
}

// sectionOf :: string -> Result SyncError Notes
const sectionOf = (document: string): Result<SyncError, Notes> =>
  fold<SectionError, Notes, Result<SyncError, Notes>>(() => err({ tag: "unterminated" }))(ok)(parseSection(document))

const releasedFrom = (oldNotes: Notes) => (notes: Notes): number =>
  oldNotes.filter((note) => !notes.some((other) => other.text === note.text)).length

// pushNotes :: string -> Notes -> Promise (Result SyncError PushOutcome)
//   serialises the session list into the file's section, creating AGENTS.md
//   when missing. the section becomes an exact mirror of the list; released
//   counts the old section's notes the list no longer has.
export const pushNotes =
  (path: string) =>
  async (notes: Notes): Promise<Result<SyncError, PushOutcome>> => {
    const document = await readText(path).then(documentOf)
    if (document.tag === "err") return document
    const parsed = parseSection(document.value)
    if (parsed.tag === "err") return err({ tag: "unterminated" })
    const section = spliceSection(renderSection(notes))(document.value)
    const written = await writeText(path)(section)
    if (written.tag === "err") return err({ tag: "write", reason: written.error.reason })
    return ok({ written: notes.length, inactive: countInactive(notes), released: releasedFrom(parsed.value)(notes) })
  }

// pullNotes :: string -> Promise (Result SyncError Notes)
//   deserialises the file's section; a missing file or section is ok empty
export const pullNotes = async (path: string): Promise<Result<SyncError, Notes>> => {
  const document = await readText(path).then(documentOf)
  if (document.tag === "err") return document
  return sectionOf(document.value)
}

// renderSyncError :: SyncError -> string
export const renderSyncError = (error: SyncError): string => {
  if (error.tag === "read") return `sync failed: AGENTS.md could not be read (${error.reason}). nothing changed.`
  if (error.tag === "write") return `sync failed: AGENTS.md could not be written (${error.reason}). the store is untouched.`
  return "sync failed: the structured-spec section has a start marker but no end marker. fix the markers in AGENTS.md and retry. nothing changed."
}

// renderPushRefused :: () -> string
export const renderPushRefused = (): string =>
  "refusing to push: this session's list is empty and a push would wipe the AGENTS.md store. pull first if you meant to load the store."

// renderPullEmpty :: () -> string
export const renderPullEmpty = (): string =>
  "the AGENTS.md store holds no notes yet; nothing was pulled. push writes this session's list into it."

// renderPush :: PushOutcome -> string
export const renderPush = (outcome: PushOutcome): string => {
  const lines = [`wrote ${outcome.written} note(s) (${outcome.inactive} overruled) to the AGENTS.md store.`]
  if (outcome.released > 0)
    lines.push(`${outcome.released} store note(s) are not in this session's list; they are no longer in the file.`)
  return lines.join("\n")
}
