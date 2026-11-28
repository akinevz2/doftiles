import { readFile, writeFile } from "node:fs/promises"
import { err, ok } from "../core/result.ts"
import type { Result } from "../core/result.ts"

export type ReadError = { readonly tag: "notFound" } | { readonly tag: "unreadable"; readonly reason: string }
export type WriteError = { readonly tag: "unwritable"; readonly reason: string }

const reasonOf = (cause: unknown): string => (cause instanceof Error ? cause.message : String(cause))
const isMissing = (cause: unknown): boolean =>
  cause instanceof Error && "code" in cause && cause.code === "ENOENT"

// readText :: string -> Promise (Result ReadError string)
//   notFound when the file does not exist; unreadable for every other failure
export const readText = (path: string): Promise<Result<ReadError, string>> =>
  readFile(path, "utf8").then(
    (text): Result<ReadError, string> => ok(text),
    (cause: unknown): Result<ReadError, string> =>
      isMissing(cause) ? err({ tag: "notFound" }) : err({ tag: "unreadable", reason: reasonOf(cause) }),
  )

// writeText :: string -> string -> Promise (Result WriteError undefined)
export const writeText =
  (path: string) =>
  (text: string): Promise<Result<WriteError, undefined>> =>
    writeFile(path, text, "utf8").then(
      (): Result<WriteError, undefined> => ok(undefined),
      (cause: unknown): Result<WriteError, undefined> => err({ tag: "unwritable", reason: reasonOf(cause) }),
    )
