import { err, ok } from "./result.ts"
import type { Result } from "./result.ts"

export type DecodeError = { readonly tag: "notStringArray" }

const isString = (value: unknown): value is string => typeof value === "string"

const isStringArray = (value: unknown): value is readonly string[] =>
  Array.isArray(value) && value.every(isString)

const isRecord = (value: unknown): value is Record<string, unknown> =>
  value instanceof Object && !Array.isArray(value)

// decodeNotesInput :: unknown -> Result DecodeError (readonly string[])
//   accepts an object whose `notes` property is an array of strings; extra keys ignored
export const decodeNotesInput = (input: unknown): Result<DecodeError, readonly string[]> => {
  const notes = isRecord(input) ? input["notes"] : undefined
  return isStringArray(notes) ? ok(notes) : err({ tag: "notStringArray" })
}

export type DecodeAmendError = { readonly tag: "malformed" }
export type AmendInput = {
  readonly notes: readonly string[]
  readonly drop: readonly string[]
  readonly overrule: readonly string[]
}
const optionalStrings = (value: unknown): readonly string[] | undefined =>
  value === undefined ? [] : isStringArray(value) ? value : undefined
// decodeAmendInput :: unknown -> Result DecodeAmendError AmendInput
//   accepts { notes?, drop?, overrule? }, each an array of strings when present;
//   at least one entry must be given overall
export const decodeAmendInput = (input: unknown): Result<DecodeAmendError, AmendInput> => {
  if (!isRecord(input)) return err({ tag: "malformed" })
  const notes = optionalStrings(input["notes"])
  const drop = optionalStrings(input["drop"])
  const overrule = optionalStrings(input["overrule"])
  if (notes === undefined || drop === undefined || overrule === undefined) return err({ tag: "malformed" })
  const empty = notes.length === 0 && drop.length === 0 && overrule.length === 0
  return empty ? err({ tag: "malformed" }) : ok({ notes, drop, overrule })
}
