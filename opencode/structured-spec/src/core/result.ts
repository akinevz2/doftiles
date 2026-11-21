export type Result<E, A> =
  | { readonly tag: "err"; readonly error: E }
  | { readonly tag: "ok"; readonly value: A }

// ok :: a -> Result e a
export const ok = <A>(value: A): Result<never, A> => ({ tag: "ok", value })

// err :: e -> Result e a
export const err = <E>(error: E): Result<E, never> => ({ tag: "err", error })

// fold :: (e -> b) -> (a -> b) -> Result e a -> b
export const fold =
  <E, A, B>(onError: (error: E) => B) =>
  (onOk: (value: A) => B) =>
  (result: Result<E, A>): B =>
    result.tag === "err" ? onError(result.error) : onOk(result.value)
