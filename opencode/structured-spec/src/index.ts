import { Plugin } from "@opencode/plugin"
import { registerHooks } from "./shell/hooks.ts"
import { makeStore } from "./shell/store.ts"
import { registerTools } from "./shell/tools.ts"

// setup :: Ctx -> Promise<void>
export default Plugin.define({
  id: "structured-spec",
  setup: async (ctx) => {
    const store = makeStore()
    await registerTools(ctx, store)
    await registerHooks(ctx, store)
  },
})
