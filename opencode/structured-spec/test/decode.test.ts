import { describe, expect, test } from "bun:test"
import { decodeNotesInput } from "../src/core/decode.ts"
import type { DecodeError } from "../src/core/decode.ts"
import { err, ok } from "../src/core/result.ts"

const notStringArray: DecodeError = { tag: "notStringArray" }

describe("decodeNotesInput", () => {
  test("accepts an object whose notes is an array of strings", () => {
    expect(decodeNotesInput({ notes: ["a"] })).toEqual(ok(["a"]))
  })

  test("ignores extra keys", () => {
    expect(decodeNotesInput({ notes: ["a"], extra: 42 })).toEqual(ok(["a"]))
  })

  test("rejects everything else", () => {
    const notArray = notStringArray
    expect(decodeNotesInput({})).toEqual(err(notArray))
    expect(decodeNotesInput({ notes: "a" })).toEqual(err(notStringArray))
    expect(decodeNotesInput({ notes: [1] })).toEqual(err(notStringArray))
    expect(decodeNotesInput(undefined)).toEqual(err(notStringArray))
    expect(decodeNotesInput(null)).toEqual(err(notStringArray))
    expect(decodeNotesInput([])).toEqual(err(notStringArray))
  })
})
