import { describe, expect, test } from "bun:test"
import { decodeSyncInput } from "../src/core/decode.ts"
import { fold } from "../src/core/result.ts"

const pushed = (input: unknown): string | undefined =>
  fold<{ tag: "badDirection" }, "push" | "pull", string | undefined>(() => "err")((direction) => direction)(decodeSyncInput(input))

describe("decodeSyncInput", () => {
  test("accepts push and pull", () => {
    expect(pushed({ direction: "push" })).toBe("push")
    expect(pushed({ direction: "pull" })).toBe("pull")
  })
  test("ignores extra keys", () => {
    expect(pushed({ direction: "pull", notes: ["x"] })).toBe("pull")
  })
  test("rejects everything else", () => {
    expect(pushed({})).toBe("err")
    expect(pushed({ direction: "sync" })).toBe("err")
    expect(pushed({ direction: 1 })).toBe("err")
    expect(pushed(undefined)).toBe("err")
    expect(pushed(null)).toBe("err")
    expect(pushed([])).toBe("err")
    expect(pushed("push")).toBe("err")
  })
})
