type Fn<A, B> = (a: A) => B

// pipe :: a -> (a -> b) -> ... -> z       (overloads for 2, 3, 4 functions)
export function pipe<A, B>(value: A, ab: Fn<A, B>): B
export function pipe<A, B, C>(value: A, ab: Fn<A, B>, bc: Fn<B, C>): C
export function pipe<A, B, C, D>(value: A, ab: Fn<A, B>, bc: Fn<B, C>, cd: Fn<C, D>): D
export function pipe(value: unknown, ...fns: readonly Fn<unknown, unknown>[]): unknown {
  return fns.reduce((step, fn) => fn(step), value)
}

// absurd :: never -> never                (the only `throw` in the codebase)
export const absurd = (never: never): never => {
  throw new Error(`absurd: ${String(never)}`)
}
