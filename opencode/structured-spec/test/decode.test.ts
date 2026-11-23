import { describe, expect, test } from "bun:test"
import { decodeAmendInput, decodeNotesInput } from "../src/core/decode.ts"
import type { DecodeAmendError, DecodeError } from "../src/core/decode.ts"
import { err, ok } from "../src/core/result.ts"

const notStringArray: DecodeError = { tag: "notStringArray" }
const malformed: DecodeAmendError = { tag: "malformed" }

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

describe("decodeAmendInput", () => {
  test("accepts any combination of the three keys", () => {
    expect(decodeAmendInput({ drop: ["a"], overrule: ["b"], notes: ["c"] })).toEqual(
      ok({ notes: ["c"], drop: ["a"], overrule: ["b"] }),
    )
    expect(decodeAmendInput({ drop: ["a"] })).toEqual(ok({ notes: [], drop: ["a"], overrule: [] }))
    expect(decodeAmendInput({ overrule: ["a"] })).toEqual(ok({ notes: [], drop: [], overrule: ["a"] }))
    expect(decodeAmendInput({ notes: ["a"] })).toEqual(ok({ notes: ["a"], drop: [], overrule: [] }))
  })

  test("an empty object is malformed", () => {
    expect(decodeAmendInput({})).toEqual(err(malformed))
    expect(decodeAmendInput({ drop: [], overrule: [], notes: [] })).toEqual(err(malformed))
  })

  test("rejects everything else", () => {
    expect(decodeAmendInput(undefined)).toEqual(err(malformed))
    expect(decodeAmendInput(null)).toEqual(err(malformed))
    expect(decodeAmendInput([])).toEqual(err(malformed))
    expect(decodeAmendInput({ drop: "a" })).toEqual(err(malformed))
    expect(decodeAmendInput({ drop: [1] })).toEqual(err(malformed))
    expect(decodeAmendInput({ drop: ["a"], notes: 42 })).toEqual(err(malformed))
  })

  test("ignores extra keys", () => {
    expect(decodeAmendInput({ drop: ["a"], extra: 42 })).toEqual(ok({ notes: [], drop: ["a"], overrule: [] }))
  })
})
