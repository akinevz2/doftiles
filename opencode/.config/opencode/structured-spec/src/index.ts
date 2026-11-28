import { join } from "node:path"
import { Plugin } from "@opencode/plugin"
import { registerHooks } from "./shell/hooks.ts"
import { makeStore } from "./shell/store.ts"
import { registerTools } from "./shell/tools.ts"
import { registerSyncTool } from "./shell/sync.ts"

// setup :: Ctx -> Promise<void>
export default Plugin.define({
  id: "structured-spec",
  setup: async (ctx) => {
    const store = makeStore()
    const agentsPath = join(ctx.location.project.canonical, "AGENTS.md")
    await registerTools(ctx, store)
    await registerSyncTool({ ctx, store, agentsPath })
    await registerHooks(ctx, store)
  },
})
