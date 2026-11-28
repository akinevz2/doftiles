import { absorbNotes } from "../core/notes.ts"
import { addEach as addEachCore, addNotes, dropNotes, emptyNotes, overruleNotes } from "../core/notes.ts"
import type { DropOutcome, NoteError, Notes, OverruleOutcome } from "../core/notes.ts"
import type { Result } from "../core/result.ts"
import { modifyRef, newRef, readRef } from "./ref.ts"
import type { Ref } from "./ref.ts"

export type Store = {
  readonly get: (sessionID: string) => Notes
  readonly add: (sessionID: string, raw: readonly string[]) => Result<NoteError, Notes>
  readonly addEach: (sessionID: string, raw: readonly string[]) => readonly NoteError[]
  readonly drop: (sessionID: string, raw: readonly string[]) => DropOutcome
  readonly overrule: (sessionID: string, raw: readonly string[]) => OverruleOutcome
  readonly restore: (sessionID: string, file: Notes) => Notes
  readonly reject: (sessionID: string, lines: readonly string[]) => void
  readonly pending: (sessionID: string) => readonly string[]
  readonly drain: (sessionID: string) => readonly string[]
}

const mapOf = <V>(entries?: Iterable<readonly [string, V]>): Map<string, V> => new Map<string, V>(entries)

const setIn = <V>(map: ReadonlyMap<string, V>, key: string, value: V): ReadonlyMap<string, V> => {
  const copy = mapOf(map)
  return copy.set(key, value)
}

const getIn = <V>(map: ReadonlyMap<string, V>, key: string, fallback: V): V => map.get(key) ?? fallback

const emptyLines: readonly string[] = []

const addTo =
  (ref: Ref<ReadonlyMap<string, Notes>>) =>
  (sessionID: string, raw: readonly string[]): Result<NoteError, Notes> => {
    const result = addNotes(getIn(readRef(ref), sessionID, emptyNotes))(raw)
    if (result.tag === "ok") modifyRef(ref)((map) => setIn(map, sessionID, result.value))
    return result
  }

const addAllTo =
  (ref: Ref<ReadonlyMap<string, Notes>>) =>
  (sessionID: string, raw: readonly string[]): readonly NoteError[] => {
    const outcome = addEachCore(getIn(readRef(ref), sessionID, emptyNotes))(raw)
    modifyRef(ref)((map) => setIn(map, sessionID, outcome.notes))
    return outcome.errors
  }

const amendWith =
  <O extends { notes: Notes }>(apply: (notes: Notes) => (raw: readonly string[]) => O) =>
  (ref: Ref<ReadonlyMap<string, Notes>>) =>
  (sessionID: string, raw: readonly string[]): O => {
    const outcome = apply(getIn(readRef(ref), sessionID, emptyNotes))(raw)
    modifyRef(ref)((map) => setIn(map, sessionID, outcome.notes))
    return outcome
  }

const restoreTo =
  (ref: Ref<ReadonlyMap<string, Notes>>) =>
  (sessionID: string, file: Notes): Notes => {
    const merged = absorbNotes(file)(getIn(readRef(ref), sessionID, emptyNotes))
    modifyRef(ref)((map) => setIn(map, sessionID, merged))
    return merged
  }

const appendTo =
  (ref: Ref<ReadonlyMap<string, readonly string[]>>) =>
  (sessionID: string, lines: readonly string[]): void => {
    const step = (map: ReadonlyMap<string, readonly string[]>): ReadonlyMap<string, readonly string[]> =>
      setIn(map, sessionID, [...getIn(map, sessionID, emptyLines), ...lines])
    modifyRef(ref)(step)
  }

const drainFrom =
  (ref: Ref<ReadonlyMap<string, readonly string[]>>) =>
  (sessionID: string): readonly string[] => {
    const lines = getIn(readRef(ref), sessionID, emptyLines)
    modifyRef(ref)((map) => setIn(map, sessionID, []))
    return lines
  }

// makeStore :: () -> Store
//   backed by two refs: per-session notes and per-session undrained rejection lines
export const makeStore = (): Store => {
  const notesRef = newRef<ReadonlyMap<string, Notes>>(mapOf())
  const rejectedRef = newRef<ReadonlyMap<string, readonly string[]>>(mapOf())
  return {
    get: (sessionID) => getIn(readRef(notesRef), sessionID, emptyNotes),
    add: (sessionID, raw) => addTo(notesRef)(sessionID, raw),
    addEach: (sessionID, raw) => addAllTo(notesRef)(sessionID, raw),
    drop: (sessionID, raw) => amendWith(dropNotes)(notesRef)(sessionID, raw),
    overrule: (sessionID, raw) => amendWith(overruleNotes)(notesRef)(sessionID, raw),
    restore: (sessionID, file) => restoreTo(notesRef)(sessionID, file),
    reject: (sessionID, lines) => appendTo(rejectedRef)(sessionID, lines),
    pending: (sessionID) => getIn(readRef(rejectedRef), sessionID, emptyLines),
    drain: (sessionID) => drainFrom(rejectedRef)(sessionID),
  }
}
