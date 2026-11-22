import type { NoteError } from "../core/notes.ts"
import { red, renderOverflow } from "../core/render.ts"

const reportOne = (error: NoteError): void =>
  error.tag === "tooLong" ? console.error(renderOverflow(red)(error.overflow)) : undefined

// reportErrors :: readonly NoteError[] -> void
//   for each `tooLong` error: the red overflow line on the console. the model never
//   receives ansi codes.
export const reportErrors = (errors: readonly NoteError[]): void => {
  errors.map((error) => reportOne(error))
}
