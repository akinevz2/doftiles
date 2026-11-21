import type { Context } from "@opencode/plugin/promise/plugin"
import { decodeNotesInput } from "../core/decode.ts"
import type { DecodeError } from "../core/decode.ts"
import type { NoteError, Notes } from "../core/notes.ts"
import { fold } from "../core/result.ts"
import {
  addToolName,
  consultToolName,
  renderAdded,
  renderConsultation,
  renderDecodeError,
  renderNoteError,
  renderRejections,
} from "../core/render.ts"
import { reportErrors } from "./report.ts"
import type { Store } from "./store.ts"

// registerTools :: (Ctx, Store) -> Promise<void>
//   one transform, two tools; no namespace (one would prefix the names)
export const registerTools = async (ctx: Context, store: Store): Promise<void> => {
  await ctx.tool.transform((editor) => {
    editor.add({
      name: addToolName,
      description:
        "add atomic reminders to this session's specification list. each note must be one short, self-contained, checkable statement (at most 96 characters). use when the user asks you to remember, enforce, or keep in mind specific requirements.",
      input: {
        type: "object",
        properties: {
          notes: {
            type: "array",
            items: { type: "string" },
            description: "atomic reminders, one statement each",
          },
        },
        required: ["notes"],
        additionalProperties: false,
      },
      execute: async (input, context) => ({
        content: fold<DecodeError, readonly string[], string>(renderDecodeError)(addContent(store)(context.sessionID))(
          decodeNotesInput(input),
        ),
      }),
    })
    editor.add({
      name: consultToolName,
      description:
        "read this session's specification list. call it after you have received the user's complete request and before you finalise your response, then verify your response against every note.",
      input: { type: "object", properties: {}, additionalProperties: false },
      execute: async (_input, context) => {
        const lines = store.drain(context.sessionID)
        return { content: `${renderConsultation(store.get(context.sessionID))}${renderRejections(lines)}` }
      },
    })
  })
}

const addContent =
  (store: Store) =>
  (sessionID: string) =>
  (raw: readonly string[]): string => {
    const before = store.get(sessionID).length
    return fold<NoteError, Notes, string>((error: NoteError): string => {
      reportErrors([error])
      return renderNoteError(error)
    })((kept) => addedContent(sessionID, before, kept))(store.add(sessionID, raw))
  }

const addedContent = (sessionID: string, before: number, kept: Notes): string =>
  `${renderAdded({ added: kept.length - before, total: kept.length })}\n${renderConsultation(kept)}`
