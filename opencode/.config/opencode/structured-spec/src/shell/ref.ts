export type Ref<A> = { value: A }

// newRef :: a -> Ref a
export const newRef = <A>(initial: A): Ref<A> => ({ value: initial })

// readRef :: Ref a -> a
export const readRef = <A>(cell: Ref<A>): A => cell.value

// modifyRef :: Ref a -> (a -> a) -> void
export const modifyRef =
  <A>(cell: Ref<A>) =>
  (step: (value: A) => A): void => {
    cell.value = step(cell.value)
  }
