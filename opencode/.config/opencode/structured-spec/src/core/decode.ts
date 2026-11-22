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
