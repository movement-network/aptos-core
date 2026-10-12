/-!
# Vector operation specifications

Pure Lean specifications of Move's `vector` module functions.
Each definition here states *what* a vector operation should compute,
independent of how the bytecode implements it.

These specs serve as the target for refinement proofs: we prove that
evaluating the bytecode program under `Move.Step` produces results
matching these definitions for all inputs.

**Source:** `aptos-move/framework/move-stdlib/sources/vector.move`
-/

namespace MovementFormal.Std.Vector

/-! ## reverse

`reverse elems` reverses the list.

```move
public fun reverse<Element>(self: &mut vector<Element>) {
    let len = self.length();
    self.reverse_slice(0, len);
}
```
-/

def reverse (elems : List α) : List α := elems.reverse

/-! ## contains

`contains elems e` returns `true` iff `e` appears in the list.

```move
public fun contains<Element>(self: &vector<Element>, e: &Element): bool {
    let i = 0;
    let len = self.length();
    while (i < len) {
        if (self.borrow(i) == e) return true;
        i += 1;
    };
    false
}
```
-/

def contains [BEq α] (elems : List α) (e : α) : Bool :=
  elems.any (· == e)

/-! ## index_of

`indexOf elems e` returns `(true, i)` where `i` is the first index
at which `e` appears, or `(false, 0)` if `e` is not in the list.

```move
public fun index_of<Element>(self: &vector<Element>, e: &Element): (bool, u64) {
    let i = 0;
    let len = self.length();
    while (i < len) {
        if (self.borrow(i) == e) return (true, i);
        i += 1;
    };
    (false, 0)
}
```
-/

def indexOf [BEq α] (elems : List α) (e : α) : Bool × Nat :=
  go elems e 0
where
  go : List α → α → Nat → Bool × Nat
    | [], _, _ => (false, 0)
    | x :: xs, e, i => if x == e then (true, i) else go xs e (i + 1)

/-! ## append

`append a b` concatenates the two lists.

```move
public fun append<Element>(self: &mut vector<Element>, other: vector<Element>)
```
-/

def append (a b : List α) : List α := a ++ b

/-! ## remove

`remove elems i` removes the element at index `i`, returning
the removed element and the shortened list.

```move
public fun remove<Element>(self: &mut vector<Element>, i: u64): Element
```
-/

def remove (elems : List α) (i : Nat) : Option (α × List α) :=
  if h : i < elems.length then
    some (elems[i], elems.eraseIdx i)
  else none

end MovementFormal.Std.Vector
