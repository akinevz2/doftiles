import type { Context } from "@opencode/plugin/promise/plugin"
import { decodeAmendInput, decodeNotesInput } from "../core/decode.ts"
import type { DecodeAmendError, DecodeError } from "../core/decode.ts"
import { countActive, countInactive } from "../core/notes.ts"
import type { NoteError, Notes } from "../core/notes.ts"
import { fold } from "../core/result.ts"
import {
  addToolName,
  amendToolName,
  consultToolName,
  renderAdded,
  renderAmend,
  renderConsultation,
  renderDecodeAmendError,
  renderDecodeError,
  renderNoteError,
  renderRejections,
} from "../core/render.ts"
import { reportErrors } from "./report.ts"
import type { Store } from "./store.ts"

// registerTools :: (Ctx, Store) -> Promise<void>
//   one transform, three tools; no namespace (one would prefix the names)
export const registerTools = async (ctx: Context, store: Store): Promise<void> => {
  await ctx.tool.transform((editor) => {
    editor.add({
      name: addToolName,
      description:
        "add atomic reminders to this session's specification list. each note must be one short, self-contained, checkable statement (at most 96 characters). use when the user asks you to remember, enforce, or keep in mind specific requirements. re-adding an overruled note's text re-activates it.",
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
      name: amendToolName,
      description:
        "invalidate previous reminders in this session's specification list. `drop` REMOVES the matching note text (the fact was wrong); `overrule` deactivates the matching notes but keeps their text for reference (the fact is superseded); `notes` adds replacements in the same call. matching is by the exact note text as consult-specification shows it.",
      input: {
        type: "object",
        properties: {
          notes: {
            type: "array",
            items: { type: "string" },
            description: "replacement reminders to add in the same call",
          },
          drop: {
            type: "array",
            items: { type: "string" },
            description: "exact texts of notes to remove outright",
          },
          overrule: {
            type: "array",
            items: { type: "string" },
            description: "exact texts of notes to keep for reference but deactivate",
          },
        },
        additionalProperties: false,
      },
      execute: async (input, context) => ({
        content: fold<DecodeAmendError, { notes: readonly string[]; drop: readonly string[]; overrule: readonly string[] }, string>(
          renderDecodeAmendError,
        )(amendContent(store)(context.sessionID))(decodeAmendInput(input)),
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
    const before = countActive(store.get(sessionID))
    return fold<NoteError, Notes, string>((error: NoteError): string => {
      reportErrors([error])
      return renderNoteError(error)
    })((kept) => addedContent(sessionID, before, kept))(store.add(sessionID, raw))
  }

const addedContent = (sessionID: string, before: number, kept: Notes): string =>
  `${renderAdded({ added: countActive(kept) - before, total: countActive(kept), inactive: countInactive(kept) })}\n${renderConsultation(kept)}`

const amendContent =
  (store: Store) =>
  (sessionID: string) =>
  (input: { notes: readonly string[]; drop: readonly string[]; overrule: readonly string[] }): string => {
    const overruled = input.overrule.length === 0 ? undefined : store.overrule(sessionID, input.overrule)
    const dropped = input.drop.length === 0 ? undefined : store.drop(sessionID, input.drop)
    const added = input.notes.length === 0 ? undefined : store.add(sessionID, input.notes)
    if (added?.tag === "err") {
      reportErrors([added.error])
      return renderNoteError(added.error)
    }
    const current = store.get(sessionID)
    return `${renderAmend({
      dropped: dropped?.dropped ?? 0,
      overruled: overruled?.overruled ?? 0,
      missing: [...(overruled?.missing ?? []), ...(dropped?.missing ?? [])],
      total: countActive(current),
      inactive: countInactive(current),
    })}\n${renderConsultation(current)}`
  }
