import { describe, expect, test } from "bun:test"
import { emptyNotes } from "../src/core/notes.ts"
import type { Notes } from "../src/core/notes.ts"
import { err, ok } from "../src/core/result.ts"
import { endMarker, parseSection, renderSection, spliceSection, startMarker, sectionHeading } from "../src/core/section.ts"
import type { SectionError } from "../src/core/section.ts"

const notes = (rows: readonly [string, boolean][]): Notes => rows.map(([text, active]) => ({ text, active }))
const parsed = (document: string): Notes => {
  const result = parseSection(document)
  return result.tag === "ok" ? result.value : emptyNotes
}
const failed = (document: string): SectionError | undefined => {
  const result = parseSection(document)
  return result.tag === "err" ? result.error : undefined
}
const full = (body: readonly string[]): string => [startMarker, ...body, endMarker].join("\n")

describe("parseSection", () => {
  test("a document without a span is empty", () => {
    expect(parsed("# AGENTS.md\n\nsome prose\n")).toEqual([])
    expect(parsed("")).toEqual([])
  })
  test("active, overruled, bare and star bullets; other rows ignored", () => {
    const document = full([
      sectionHeading,
      "",
      "- [ ] first atomic reminder",
      "- [x] superseded reminder",
      "- [X] also overruled",
      "- bare bullet note",
      "* star bullet note",
      "a continuation line",
      "",
      "some prose",
    ])
    expect(parsed(document)).toEqual(
      notes([
        ["first atomic reminder", true],
        ["superseded reminder", false],
        ["also overruled", false],
        ["bare bullet note", true],
        ["star bullet note", true],
      ]),
    )
  })
  test("empty bullets and checkbox-less rows contribute nothing", () => {
    expect(parsed(full(["-", "- [ ] ", "## heading"]))).toEqual([])
  })
  test("a start marker with no end marker is unterminated", () => {
    expect(failed(`${startMarker}\n- [ ] lonely\n`)).toEqual({ tag: "unterminated" })
  })
  test("the first span wins when two exist", () => {
    const document = `${full(["- [ ] first"])}\nmiddle\n${full(["- [ ] second"])}`
    expect(parsed(document)).toEqual(notes([["first", true]]))
  })
  test("markers are matched after trimming their row", () => {
    expect(parsed(`  ${startMarker}  \n- [ ] indented\n  ${endMarker}  `)).toEqual(notes([["indented", true]]))
  })
})

describe("renderSection", () => {
  test("exact shape: markers, heading, blank line, one row per note, no trailing newline", () => {
    expect(renderSection(notes([["kept", true], ["gone", false]]))).toBe(
      [startMarker, sectionHeading, "", "- [ ] kept", "- [x] gone", endMarker].join("\n"),
    )
  })
  test("empty list renders the bare section", () => {
    expect(parsed(renderSection([]))).toEqual([])
  })
  test("round-trip: render then parse is the identity up to nothing", () => {
    const source = notes([
      ["first atomic reminder", true],
      ["superseded reminder", false],
      ["star bullet note", true],
    ])
    expect(parsed(renderSection(source))).toEqual(source)
  })
})

describe("spliceSection", () => {
  test("replaces the span and preserves the surrounding document", () => {
    const document = `# AGENTS.md\n\nbefore\n\n${renderSection(notes([["old", true]]))}\n\nafter\n`
    const next = spliceSection(renderSection(notes([["new", true]])))(document)
    expect(next).toBe(`# AGENTS.md\n\nbefore\n\n${renderSection(notes([["new", true]]))}\n\nafter\n`)
  })
  test("appends with one blank line to a document without a span", () => {
    expect(spliceSection(renderSection(emptyNotes))("# AGENTS.md\n")).toBe(`# AGENTS.md\n\n${renderSection([])}\n`)
    expect(spliceSection("S")("# AGENTS.md")).toBe(`# AGENTS.md\n\nS\n`)
  })
  test("an empty document becomes just the section with a final newline", () => {
    expect(spliceSection("S")("")).toBe("S\n")
  })
  test("the result ends with exactly one newline", () => {
    expect(spliceSection("S")("no newline at end")).toBe("no newline at end\n\nS\n")
  })
  test("an unterminated span passes through unchanged", () => {
    expect(spliceSection("S")(startMarker)).toBe(startMarker)
  })
  test("replace then parse round-trips through a spliced document", () => {
    const document = `# AGENTS.md\n\n${full(["- [ ] old", "- [x] released"])}\n`
    const next = spliceSection(renderSection(notes([["new", true]])))(document)
    expect(ok(parsed(next))).toEqual(ok(notes([["new", true]])))
  })
})
