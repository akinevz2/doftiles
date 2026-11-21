import { describe, expect, test } from "bun:test"
import { addEach, addNotes, emptyNotes, maxNoteLength, normalise, parseBlocks, splitOverflow, validate } from "../src/core/notes.ts"
import { err, ok } from "../src/core/result.ts"
import type { Result } from "../src/core/result.ts"
import { fold } from "../src/core/result.ts"
import type { NoteError, Notes } from "../src/core/notes.ts"

describe("normalise", () => {
  test("trims and collapses whitespace and newlines", () => {
    expect(normalise("  keep  it \n\n short \t tidy  ")).toBe("keep it short tidy")
  })
})

describe("splitOverflow", () => {
  test("a 96-character note leaves no overflow", () => {
    const note = "ab ".repeat(31) + "abc"
    expect(note).toHaveLength(maxNoteLength)
    expect(splitOverflow(note)).toEqual({ head: note, overflow: "" })
  })

  test("a 100-character note of short words ends on a whole word", () => {
    const note = normalise("word token note ".repeat(8))
    const split = splitOverflow(note)
    expect(note.length).toBeGreaterThan(maxNoteLength)
    expect(split.head.length).toBeLessThanOrEqual(maxNoteLength)
    expect(split.head.endsWith(" ")).toBe(false)
    expect(`${split.head} ${split.overflow}`).toBe(note)
  })

  test("the spec example splits before 'never'", () => {
    const note = normalise(
      "alpha bravo charlie delta echo foxtrot golf hotel india juliet kilo lima mike ox and you must never write wide specification",
    )
    const split = splitOverflow(note)
    expect(split.overflow).toBe("never write wide specification")
    expect(split.head.endsWith("must")).toBe(true)
    expect(`${split.head} ${split.overflow}`).toBe(note)
  })

  test("a single long word gives empty head and full overflow", () => {
    const word = "a".repeat(120)
    expect(splitOverflow(word)).toEqual({ head: "", overflow: word })
  })
})

describe("validate", () => {
  test("empty is rejected", () => {
    expect(validate("   ")).toEqual(err({ tag: "empty" }))
  })

  test("97 characters is too long with a non-empty overflow", () => {
    const note = "w".repeat(97)
    expect(validate(note)).toEqual(err({ tag: "tooLong", note, overflow: note }))
  })

  test("96 characters is accepted", () => {
    const note = "w".repeat(96)
    expect(validate(note)).toEqual(ok(note))
  })
})

describe("addNotes", () => {
  test("appends in order", () => {
    expect(addNotes(["one"])(["two", "three"])).toEqual(ok(["one", "two", "three"]))
  })

  test("adding the same batch twice equals once", () => {
    const first = addNotes(emptyNotes)(["a", "b"])
    const again = fold<NoteError, Notes, Result<NoteError, Notes>>(
      (): Result<NoteError, Notes> => err({ tag: "empty" }),
    )((kept) => addNotes(kept)(["a", "b"]))(first)
    expect(again).toEqual(first)
  })

  test("dedupes within the batch, first appearance order kept", () => {
    expect(addNotes(emptyNotes)(["b", "a", "b", "a"])).toEqual(ok(["b", "a"]))
  })

  test("one invalid note rejects the whole batch, list unchanged", () => {
    const wide = "x".repeat(97)
    expect(addNotes(["kept"])(["fine", wide, "more"])).toEqual(err({ tag: "tooLong", note: wide, overflow: wide }))
  })
})

describe("addEach", () => {
  test("valid notes are kept and errors arrive in input order", () => {
    const wide = "x".repeat(97)
    const outcome = addEach(emptyNotes)(["fine", wide, "", "more"])
    expect(outcome.notes).toEqual(["fine", "more"])
    expect(outcome.errors).toEqual([{ tag: "tooLong", note: wide, overflow: wide }, { tag: "empty" }])
  })

  test("idempotent", () => {
    const once = addEach(emptyNotes)(["a", "b"])
    expect(addEach(once.notes)(["a", "b"])).toEqual({ notes: once.notes, errors: [] })
  })
})

describe("parseBlocks", () => {
  test("text without blocks yields nothing", () => {
    expect(parseBlocks("just prose\nmore prose")).toEqual([])
  })

  test("mixed bullets, non-bullet lines ignored, indented bullets match", () => {
    const text = "before\n```notes\n- first atomic reminder\n* second\n  - indented\ncontinuation line\n```\nafter"
    expect(parseBlocks(text)).toEqual(["first atomic reminder", "second", "indented"])
  })

  test("two blocks in order", () => {
    const text = "```notes\n- one\n```\nmiddle\n```notes\n- two\n```"
    expect(parseBlocks(text)).toEqual(["one", "two"])
  })

  test("notesfoo does not match", () => {
    expect(parseBlocks("```notesfoo\n- one\n```")).toEqual([])
  })

  test("a plain ts block is ignored", () => {
    expect(parseBlocks("```ts\nconst x = 1\n```")).toEqual([])
  })
})
