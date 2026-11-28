import { describe, expect, test } from "bun:test"
import { absorbNotes, countActive, countInactive } from "../src/core/notes.ts"
import type { Notes } from "../src/core/notes.ts"

const notes = (rows: readonly [string, boolean][]): Notes => rows.map(([text, active]) => ({ text, active }))

describe("absorbNotes", () => {
  test("a text present in both takes the file's active flag, both ways", () => {
    const file = notes([["binding", true], ["stale", false]])
    const session = notes([["binding", false], ["stale", true]])
    expect(absorbNotes(file)(session)).toEqual(notes([["binding", true], ["stale", false]]))
  })
  test("session-only notes keep their own flag and come first", () => {
    const file = notes([["from file", true]])
    const session = notes([["session only", true], ["session overruled", false]])
    expect(absorbNotes(file)(session)).toEqual(
      notes([["session only", true], ["session overruled", false], ["from file", true]]),
    )
  })
  test("file-only notes are appended in file order", () => {
    const file = notes([["first", true], ["second", false]])
    expect(absorbNotes(file)([])).toEqual(file)
  })
  test("pulling the same file twice is stable", () => {
    const file = notes([["binding", true], ["stale", false]])
    const once = absorbNotes(file)(notes([["session only", true]]))
    expect(absorbNotes(file)(once)).toEqual(once)
  })
  test("an empty file leaves the session untouched", () => {
    const session = notes([["kept", true], ["kept overruled", false]])
    expect(absorbNotes([])(session)).toEqual(session)
  })
})

describe("countActive and countInactive", () => {
  test("they split the total", () => {
    const session = notes([["a", true], ["b", false], ["c", true]])
    expect(countActive(session)).toBe(2)
    expect(countInactive(session)).toBe(1)
  })
})
