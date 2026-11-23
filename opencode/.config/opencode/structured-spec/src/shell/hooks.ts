import type { Context } from "@opencode/plugin/promise/plugin"
import { parseBlocks } from "../core/notes.ts"
import { renderDirective, renderOverflowLines } from "../core/render.ts"
import { reportErrors } from "./report.ts"
import type { Store } from "./store.ts"

// registerHooks :: (Ctx, Store) -> Promise<void>
//   prompt: parse ```notes blocks, keep the valid, reject and report the wide ones.
//   context: inject the directive once per model request while there is anything to say.
export const registerHooks = async (ctx: Context, store: Store): Promise<void> => {
  await ctx.session.hook("prompt", (event) => {
    const raw = parseBlocks(event.prompt.text)
    if (raw.length === 0) return
    const errors = store.addEach(event.sessionID, raw)
    reportErrors(errors)
    store.reject(event.sessionID, renderOverflowLines(errors))
  })
  await ctx.session.hook("context", (event) => {
    const text = renderDirective({
      notes: store.get(event.sessionID).filter((note) => note.active).length,
      rejected: store.pending(event.sessionID).length,
    })
    if (text !== undefined) event.system.push({ type: "text", text })
  })
}
