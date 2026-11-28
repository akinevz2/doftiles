import type { Context } from "@opencode/plugin/promise/plugin"
import { decodeSyncInput } from "../core/decode.ts"
import type { DecodeSyncError, SyncDirection } from "../core/decode.ts"
import { renderConsultation, renderDecodeSyncError, renderTotals, syncToolName } from "../core/render.ts"
import { countActive, countInactive } from "../core/notes.ts"
import { fold } from "../core/result.ts"
import type { SyncError } from "./agents.ts"
import { pullNotes, pushNotes, renderPullEmpty, renderPush, renderPushRefused, renderSyncError } from "./agents.ts"
import type { Notes } from "../core/notes.ts"
import type { PushOutcome } from "./agents.ts"
import type { Store } from "./store.ts"

const pushContent =
  (store: Store) =>
  (agentsPath: string) =>
  (sessionID: string): Promise<string> => {
    const notes = store.get(sessionID)
    if (notes.length === 0) return Promise.resolve(renderPushRefused())
    return pushNotes(agentsPath)(notes).then(
      fold<SyncError, PushOutcome, string>(renderSyncError)((outcome) => `${renderPush(outcome)}\n${renderConsultation(notes)}`),
    )
  }

const pullContent =
  (store: Store) =>
  (agentsPath: string) =>
  (sessionID: string): Promise<string> =>
    pullNotes(agentsPath).then(
      fold<SyncError, Notes, string>(renderSyncError)((file) => {
        if (file.length === 0) return renderPullEmpty()
        const merged = store.restore(sessionID, file)
        const pulled = `pulled ${file.length} note(s) from the AGENTS.md store.`
        return `${pulled}\n${renderTotals(countActive(merged))(countInactive(merged))}\n${renderConsultation(merged)}`
      }),
    )

const syncContent =
  (store: Store) =>
  (agentsPath: string) =>
  (sessionID: string) =>
  (direction: SyncDirection): Promise<string> =>
    direction === "push" ? pushContent(store)(agentsPath)(sessionID) : pullContent(store)(agentsPath)(sessionID)

// registerSyncTool :: { ctx, store, agentsPath } -> Promise<void>
//   the sync-specification tool: push serialises the session list into the
//   project's AGENTS.md section, pull deserialises it back. no namespace (one
//   would prefix the name).
export const registerSyncTool = async (deps: {
  readonly ctx: Context
  readonly store: Store
  readonly agentsPath: string
}): Promise<void> => {
  await deps.ctx.tool.transform((editor) => {
    editor.add({
      name: syncToolName,
      description:
        "synchronise this session's specification list with the active project's AGENTS.md store. `push` serialises the session list into the file's marked section (the section becomes an exact mirror of the list; refused while the list is empty so the store cannot be wiped). `pull` deserialises the file's section into the session list (for texts present in both, the file's active/overruled state wins; notes only the file has are added).",
      input: {
        type: "object",
        properties: {
          direction: {
            type: "string",
            enum: ["push", "pull"],
            description: "push: session list -> AGENTS.md. pull: AGENTS.md -> session list",
          },
        },
        required: ["direction"],
        additionalProperties: false,
      },
      execute: async (input, context) => ({
        content: await fold<DecodeSyncError, SyncDirection, Promise<string>>(
          (error) => Promise.resolve(renderDecodeSyncError(error)),
        )((direction) =>
          syncContent(deps.store)(deps.agentsPath)(context.sessionID)(direction),
        )(decodeSyncInput(input)),
      }),
    })
  })
}
