import { describe, expect, test } from "bun:test"
import type { NoteError } from "../src/core/notes.ts"
import {
  maxLineWidth,
  overflowPrefix,
  overflowSuffix,
  plain,
  red,
  renderAdded,
  renderConsultation,
  renderDecodeError,
  renderDirective,
  renderNoteError,
  renderOverflow,
  renderOverflowLines,
  renderRejections,
} from "../src/core/render.ts"

const wide = (length: number): string => "x".repeat(length)

const linesOf = (text: string): readonly string[] => text.split("\n")

describe("plain and red", () => {
  test("plain is the identity and carries no ansi", () => {
    expect(plain("note")).toBe("note")
    expect(plain("\u001b[31mnote")).toBe("\u001b[31mnote")
    expect(plain("note").includes("\u001b")).toBe(false)
  })

  test("red wraps only the given text", () => {
    expect(red("note")).toBe("\u001b[31mnote\u001b[0m")
  })
})

describe("renderOverflow", () => {
  test("the spec example", () => {
    expect(renderOverflow(plain)("never write wide specification")).toBe(
      "overflowing spec: [never write wide specification] is too damn wide",
    )
  })

  test("a 200-character overflow is truncated with ... to a 96-character plain line", () => {
    const line = renderOverflow(plain)(wide(200))
    expect(line).toHaveLength(maxLineWidth)
    expect(line.endsWith("...")).toBe(false)
    expect(line.endsWith("] is too damn wide")).toBe(true)
    expect(line.slice(overflowPrefix.length, overflowPrefix.length + 3)).toBe("xxx")
  })

  test("red paints only the overflow", () => {
    const line = renderOverflow(red)("note")
    expect(line.startsWith(`${overflowPrefix}\u001b[31m`)).toBe(true)
    expect(line.endsWith(`\u001b[0m${overflowSuffix}`)).toBe(true)
  })
})

describe("renderNoteError", () => {
  test("empty", () => {
    expect(renderNoteError({ tag: "empty" })).toBe("rejected: a note must not be empty. nothing was added.")
  })

  test("tooLong: overflow line then reword line, every line at most 96 characters", () => {
    const text = renderNoteError({ tag: "tooLong", note: wide(97), overflow: wide(97) })
    const lines = linesOf(text)
    expect(lines).toHaveLength(2)
    expect(lines.at(1)).toBe(
      "nothing was added. ask the user to reword this note, or propose a shorter rewording yourself.",
    )
    expect(lines.map((line) => line.length).every((length) => length <= maxLineWidth)).toBe(true)
  })
})

describe("renderOverflowLines", () => {
  test("only tooLong errors contribute lines", () => {
    const wide = { tag: "tooLong", note: "n", overflow: "never write wide specification" } as const
    expect(renderOverflowLines([{ tag: "empty" }, wide])).toEqual([
      "overflowing spec: [never write wide specification] is too damn wide",
    ])
  })
})

describe("renderConsultation", () => {
  test("empty", () => {
    expect(renderConsultation([])).toBe("specification is empty. there is nothing to verify.")
  })

  test("two notes, exact wording", () => {
    const text = renderConsultation(["first note", "second note"])
    expect(linesOf(text)).toEqual([
      "specification: 2 note(s). check your draft response against every note before you finish.",
      "1. first note",
      "2. second note",
      "for each note: verify it against the facts of this conversation and the code you have actually read. if a note is not met or cannot be verified, fix the response or say so plainly. never claim a note is satisfied without checking it.",
    ])
  })
})

describe("renderRejections", () => {
  test("empty list is the empty string", () => {
    expect(renderRejections([])).toBe("")
  })

  test("header plus lines, every line at most 96 characters", () => {
    const text = renderRejections(["overflowing spec: [x] is too damn wide"])
    const lines = linesOf(text)
    expect(lines.at(1)).toBe(
      "rejected from the user's notes block, not added. ask the user to reword each, or suggest one:",
    )
    expect(lines.map((line) => line.length).every((length) => length <= maxLineWidth)).toBe(true)
  })
})

describe("renderDirective", () => {
  test("nothing to say", () => {
    expect(renderDirective({ notes: 0, rejected: 0 })).toBeUndefined()
  })

  test("notes only", () => {
    expect(renderDirective({ notes: 2, rejected: 0 })).toBe(
      "a specification list with 2 note(s) exists for this session. once you have fully read the user's request, and before you finalise your response, call the consult-specification tool and verify your response against every note.",
    )
  })

  test("rejected only", () => {
    expect(renderDirective({ notes: 0, rejected: 1 })).toBe(
      "the user's notes block had 1 note(s) rejected as too wide. call the consult-specification tool, then ask the user to reword them or suggest rewordings, before you finalise your response.",
    )
  })

  test("both", () => {
    expect(renderDirective({ notes: 1, rejected: 2 })).toBe(
      "a specification list with 1 note(s) exists for this session. once you have fully read the user's request, and before you finalise your response, call the consult-specification tool and verify your response against every note. 2 note(s) from the user's notes block were rejected as too wide; the tool will say which.",
    )
  })
})

describe("renderAdded and renderDecodeError", () => {
  test("exact wording", () => {
    expect(renderAdded({ added: 2, total: 3 })).toBe("added 2 note(s). specification now holds 3.")
    expect(renderDecodeError({ tag: "notStringArray" })).toBe(
      'rejected: add-rigorously expects { "notes": string[] }. nothing was added.',
    )
  })
})

describe("line width property", () => {
  test("every line of every rejection message is at most 96 characters", () => {
    const emptyError: NoteError = { tag: "empty" }
    const tooLong97: NoteError = { tag: "tooLong", note: wide(97), overflow: wide(97) }
    const tooLong200: NoteError = { tag: "tooLong", note: wide(200), overflow: wide(200) }
    const errors: readonly NoteError[] = [emptyError, tooLong97, tooLong200]
    const messages = [renderNoteError(tooLong97), renderNoteError(tooLong200), renderRejections(renderOverflowLines(errors))]
    const lengths = messages.flatMap(linesOf).map((line) => line.length)
    expect(lengths.every((length) => length <= maxLineWidth)).toBe(true)
  })
})
