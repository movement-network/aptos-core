# Formal Methods Learning Path: Complete Guide

**Version:** 1.0  
**Last Updated:** 2026-04-22  
**Audience:** Engineers new to formal verification, researchers transitioning to applied formal methods, contributors to CA verification effort  
**Prerequisites:** Basic programming experience, willingness to learn mathematical reasoning  

## Overview

This guide provides a structured learning path from zero formal methods experience to contributing to the Confidential Assets (CA) verification effort. It's designed as a practical, hands-on curriculum with concrete milestones, realistic time estimates, and executable exercises at each stage.

**Learning philosophy:**
- Theory through practice: learn concepts as you need them, not in abstract isolation
- Build incrementally: each milestone produces a working proof
- Fail fast: exercises are designed to hit common errors early when they're cheap to fix
- Real-world context: all examples drawn from actual CA verification work

**Time commitment:**
- **Beginner track** (no formal methods background): 8-12 weeks part-time to productive contribution
- **Intermediate track** (some logic/proof experience): 4-6 weeks to Lean fluency
- **Advanced track** (formal verification experience in other tools): 1-2 weeks to CA-specific patterns

---

## Table of Contents

1. [Learning Path Overview](#learning-path-overview)
2. [Stage 0: Foundations (Week 1)](#stage-0-foundations-week-1)
3. [Stage 1: Lean Basics (Week 2-3)](#stage-1-lean-basics-week-2-3)
4. [Stage 2: Proof Tactics (Week 4-5)](#stage-2-proof-tactics-week-4-5)
5. [Stage 3: Dependent Types (Week 6-7)](#stage-3-dependent-types-week-6-7)
6. [Stage 4: MoveModel Semantics (Week 8-9)](#stage-4-movemodel-semantics-week-8-9)
7. [Stage 5: CA-Specific Patterns (Week 10-12)](#stage-5-ca-specific-patterns-week-10-12)
8. [Parallel Learning: MSL Track](#parallel-learning-msl-track)
9. [Parallel Learning: Difftest Track](#parallel-learning-difftest-track)
10. [Common Pitfalls and How to Avoid Them](#common-pitfalls-and-how-to-avoid-them)
11. [Self-Assessment Checkpoints](#self-assessment-checkpoints)
12. [Resources and References](#resources-and-references)

---

## Learning Path Overview

```
Stage 0 (Week 1): Foundations
  ↓ Learn: propositional logic, predicate logic, proof structure
  ↓ Output: hand-written proofs of simple theorems
  ↓ Checkpoint: prove modus ponens, prove De Morgan's laws

Stage 1 (Week 2-3): Lean Basics
  ↓ Learn: Lean syntax, term mode, tactic mode, type system basics
  ↓ Output: simple Lean proofs (nat induction, list properties)
  ↓ Checkpoint: prove `map_append`, `reverse_reverse`

Stage 2 (Week 4-5): Proof Tactics
  ↓ Learn: simp, rw, induction, cases, have, calc
  ↓ Output: CA step lemma (immBorrowLoc, stLoc)
  ↓ Checkpoint: contribute 1 step lemma to StepLemmas library

Stage 3 (Week 6-7): Dependent Types
  ↓ Learn: indexed families, equality types, heq, subtype patterns
  ↓ Output: array-indexed proof with bounds
  ↓ Checkpoint: prove 1 PC transition with array indexing

Stage 4 (Week 8-9): MoveModel Semantics
  ↓ Learn: Move VM execution model, frame semantics, step function
  ↓ Output: 10-PC bytecode proof using symbolic state
  ↓ Checkpoint: prove eval_equiv for a simple Move function

Stage 5 (Week 10-12): CA-Specific Patterns
  ↓ Learn: oracle modeling, functional sim, PC chaining, composition
  ↓ Output: complete verification for 1 sigma protocol operation
  ↓ Checkpoint: close 1 temporary axiom or extend existing proof

GRADUATE: Ready to contribute to CA verification effort
```

**Parallel tracks:** MSL and Difftest can be learned in parallel starting Stage 3. See dedicated sections below.

---

## Stage 0: Foundations (Week 1)

**Goal:** Understand what formal proofs are and why they're valuable. Build intuition for proof structure before touching Lean.

**Why this matters:** Jumping straight to Lean without proof intuition leads to "proof by trial and error" — blindly trying tactics until something works. This stage builds the mental model that makes tactics meaningful.

### Learning Objectives

- Understand propositional logic (AND, OR, NOT, IMPLIES)
- Understand predicate logic (FORALL, EXISTS, quantifiers)
- Recognize proof patterns: direct proof, proof by contradiction, proof by induction
- Read and write structured proofs in natural language

### Exercises (do these by hand, no tools)

**Exercise 0.1: Propositional logic truth tables**
Construct truth tables for:
- `(P ∧ Q) → R`
- `(P → Q) ∧ (Q → R) → (P → R)` (transitivity)
- `¬(P ∧ Q) ↔ (¬P ∨ ¬Q)` (De Morgan)

**Exercise 0.2: Direct proof**
Prove (in English prose): "If n is even and m is even, then n + m is even."

```
Proof:
  Assume n is even and m is even.
  By definition, n = 2k for some integer k, and m = 2j for some integer j.
  Then n + m = 2k + 2j = 2(k + j).
  Since k + j is an integer, n + m is even by definition.
∎
```

**Exercise 0.3: Proof by contradiction**
Prove: "There are infinitely many prime numbers." (Euclid's proof)

Hint: Assume finitely many primes p₁, ..., pₙ. Consider N = (p₁ × ... × pₙ) + 1.

**Exercise 0.4: Proof by induction**
Prove: "For all n ≥ 0, 1 + 2 + ... + n = n(n+1)/2."

Structure:
- Base case: n = 0
- Inductive step: assume true for n, prove for n+1

### Checkpoint

Can you:
- [ ] Explain the difference between "proof" in everyday language vs formal proof?
- [ ] Write a structured English proof for a simple number theory claim?
- [ ] Recognize when induction is the right proof technique?

**Time estimate:** 6-8 hours over 1 week (mix of reading + exercises)

**Resources:**
- "How to Prove It" by Daniel Velleman (chapters 1-3)
- 3Blue1Brown video: "Essence of Linear Algebra" (for mathematical intuition)
- CA example: Read `audit/CLAIMS.md` and pick one claim — how would you prove it informally?

---

## Stage 1: Lean Basics (Week 2-3)

**Goal:** Translate hand-written proofs into Lean. Understand Lean's syntax, type system, and the distinction between term mode and tactic mode.

**Why this matters:** Lean is a proof assistant, not a magic theorem prover. You guide it step-by-step. Fluency in basic syntax removes cognitive load when tackling hard proofs.

### Learning Objectives

- Install Lean 4 and VS Code extension
- Understand Lean's type system (Prop, Type, function types)
- Use term mode (`fun`, `λ`, `have`, `show`) and tactic mode (`by`)
- Prove simple theorems about natural numbers and lists

### Setup

1. **Install Lean 4:**
   ```bash
   curl https://raw.githubusercontent.com/leanprover/elan/master/elan-init.sh -sSf | sh
   lean --version  # expect: Lean (version 4.x.0)
   ```

2. **Install VS Code extension:**
   - Open VS Code
   - Install "lean4" extension by leanprover
   - Create test file `test.lean`, type `#check Nat`, see infoview update

3. **Clone Lean learning repo:**
   ```bash
   git clone https://github.com/leanprover/theorem_proving_in_lean4
   cd theorem_proving_in_lean4
   lake build
   ```

### Exercises

**Exercise 1.1: Type checking basics**
```lean
-- In a new file exercises_stage1.lean
#check Nat           -- Nat : Type
#check Prop          -- Prop : Type
#check Nat → Nat     -- function type
#check ∀ n : Nat, n + 0 = n  -- universal quantification in Prop

-- Your turn: what are the types of these?
#check List Nat
#check 42
#check (fun x => x + 1)
```

**Exercise 1.2: Term-mode proof (modus ponens)**
```lean
theorem modus_ponens (P Q : Prop) (hpq : P → Q) (hp : P) : Q :=
  hpq hp

-- Your turn: prove these in term mode
theorem and_comm (P Q : Prop) (h : P ∧ Q) : Q ∧ P :=
  sorry  -- replace with proof

theorem or_comm (P Q : Prop) (h : P ∨ Q) : Q ∨ P :=
  sorry  -- replace with proof
```

Solution (no peeking until you try):
```lean
theorem and_comm (P Q : Prop) (h : P ∧ Q) : Q ∧ P :=
  ⟨h.right, h.left⟩

theorem or_comm (P Q : Prop) (h : P ∨ Q) : Q ∨ P :=
  h.elim Or.inr Or.inl
```

**Exercise 1.3: Tactic-mode proof (natural number induction)**
```lean
theorem zero_add (n : Nat) : 0 + n = n := by
  induction n with
  | zero => rfl
  | succ n ih =>
    show 0 + (n + 1) = n + 1
    rw [Nat.add_succ, ih]

-- Your turn: prove these by induction
theorem add_zero (n : Nat) : n + 0 = n := by
  sorry  -- hint: induction on n

theorem add_comm (m n : Nat) : m + n = n + m := by
  sorry  -- hint: induction on n, use add_zero and add_succ lemmas
```

**Exercise 1.4: List properties**
```lean
theorem map_append {α β : Type} (f : α → β) (xs ys : List α) :
    (xs ++ ys).map f = xs.map f ++ ys.map f := by
  induction xs with
  | nil => rfl
  | cons x xs ih =>
    simp [List.map, List.append]
    rw [ih]

-- Your turn: prove this
theorem reverse_reverse {α : Type} (xs : List α) :
    xs.reverse.reverse = xs := by
  sorry  -- hint: induction on xs, need helper lemma about reverse_append
```

### Checkpoint

Can you:
- [ ] Navigate Lean infoview in VS Code (see goal state, hover for types)?
- [ ] Distinguish when to use term mode vs tactic mode?
- [ ] Prove a simple theorem by induction without looking up syntax?
- [ ] Read Lean error messages and understand "type mismatch" errors?

**Time estimate:** 12-16 hours over 2 weeks (exercises + reading)

**Resources:**
- "Theorem Proving in Lean 4" (chapters 1-5)
- Lean Zulip chat: https://leanprover.zulipchat.com
- CA example: Read `lean/MovementFormal/MoveModel/StepLemmas/Basic.lean` — can you follow the proof structure?

---

## Stage 2: Proof Tactics (Week 4-5)

**Goal:** Master the 10 core tactics that cover 90% of CA proofs. Learn when to use each tactic and how to debug when tactics fail.

**Why this matters:** CA proofs are 80% routine tactic application, 20% creative insight. This stage automates the 80% so you can focus on the hard parts.

### Core Tactics Arsenal

1. **`rfl`** — prove by reflexivity (works when both sides reduce to same term)
2. **`rw [lemma]`** — rewrite using equality lemma
3. **`simp`** — simplify using simp lemmas (powerful but opaque)
4. **`simp only [lemma1, lemma2]`** — controlled simplification (prefer this)
5. **`unfold def`** — expand definition
6. **`cases h`** — case split on hypothesis
7. **`induction n`** — proof by induction
8. **`have h : P := proof`** — introduce intermediate claim
9. **`apply lemma`** — apply lemma to goal
10. **`exact term`** — provide explicit proof term

### Exercises

**Exercise 2.1: Rewriting practice**
```lean
example (a b c : Nat) (h1 : a = b) (h2 : b = c) : a = c := by
  rw [h1, h2]

-- Your turn: prove using rw
example (xs ys : List Nat) (h : xs = ys) : xs.length = ys.length := by
  sorry  -- hint: rw [h]

example (n : Nat) : n + 0 = 0 + n := by
  sorry  -- hint: rw [Nat.add_zero, Nat.zero_add]
```

**Exercise 2.2: Simplification control**
```lean
-- Bad: opaque simp
example (xs : List Nat) : (xs ++ []).reverse = xs.reverse := by
  simp  -- works but you don't know what it used

-- Good: explicit simp
example (xs : List Nat) : (xs ++ []).reverse = xs.reverse := by
  simp only [List.append_nil]

-- Your turn: prove with explicit simp only
example (n m : Nat) : (n + m) + 0 = n + m := by
  sorry  -- use simp only [Nat.add_zero]
```

**Exercise 2.3: Case analysis**
```lean
-- Case split on constructor
example (opt : Option Nat) : opt.isSome ∨ opt.isNone := by
  cases opt with
  | none => right; rfl
  | some n => left; rfl

-- Your turn: prove by cases
def classify (n : Nat) : String :=
  if n = 0 then "zero" else "positive"

example (n : Nat) : classify n = "zero" ∨ classify n = "positive" := by
  sorry  -- hint: unfold classify, then cases on n = 0 decision
```

**Exercise 2.4: Have-chain (intermediate claims)**
```lean
-- Structured proof with intermediate steps
example (a b c : Nat) (h1 : a < b) (h2 : b < c) : a < c := by
  have hab : a < b := h1
  have hbc : b < c := h2
  exact Nat.lt_trans hab hbc

-- Your turn: prove with have-chain
example (xs : List Nat) (h : xs.length > 0) : xs ≠ [] := by
  sorry  -- hint: have h_nil : ([] : List Nat).length = 0 := rfl
         --       then show contradiction
```

**Exercise 2.5: CA-style step lemma**
Now apply to real CA code. Prove a simplified version of a MoveModel step lemma:

```lean
-- Simplified frame structure (actual CA version is more complex)
structure SimpleFrame where
  pc : Nat
  stack : List Nat
  locals : Array Nat

-- Step function for "StLoc k" instruction (store to local k)
def step_stLoc (k : Nat) (f : SimpleFrame) (h : f.stack.length > 0) : SimpleFrame :=
  { pc := f.pc + 1
  , stack := f.stack.tail
  , locals := f.locals.set! k f.stack.head! }

-- Prove: executing StLoc increments PC by exactly 1
theorem step_stLoc_pc (k : Nat) (f : SimpleFrame) (h : f.stack.length > 0) :
    (step_stLoc k f h).pc = f.pc + 1 := by
  sorry  -- hint: unfold step_stLoc, then rfl

-- Prove: executing StLoc pops exactly one element from stack
theorem step_stLoc_stack_length (k : Nat) (f : SimpleFrame) (h : f.stack.length > 0) :
    (step_stLoc k f h).stack.length = f.stack.length - 1 := by
  sorry  -- hint: unfold step_stLoc, simp only [List.tail_length], omega
```

Solutions (after you try):
```lean
theorem step_stLoc_pc (k : Nat) (f : SimpleFrame) (h : f.stack.length > 0) :
    (step_stLoc k f h).pc = f.pc + 1 := by
  unfold step_stLoc
  rfl

theorem step_stLoc_stack_length (k : Nat) (f : SimpleFrame) (h : f.stack.length > 0) :
    (step_stLoc k f h).stack.length = f.stack.length - 1 := by
  unfold step_stLoc
  simp only [List.length_tail]
  omega  -- arithmetic automation
```

### Checkpoint

Can you:
- [ ] Choose the right tactic for a given goal (rw vs simp vs cases)?
- [ ] Debug a failing `simp` by switching to `simp only [...]`?
- [ ] Prove a 5-line theorem without consulting documentation?
- [ ] Read a CA step lemma and understand its proof structure?

**Time estimate:** 10-14 hours over 2 weeks (heavy on exercises)

**Resources:**
- "Theorem Proving in Lean 4" (chapters 6-8)
- CA example: Read `lean/MovementFormal/MoveModel/StepLemmas/Locals.lean` — identify which tactics are used where

---

## Stage 3: Dependent Types (Week 6-7)

**Goal:** Understand dependent types, indexed families, equality types, and the heq pattern that appears everywhere in CA proofs.

**Why this matters:** Move VM semantics use dependent types heavily (stack indexed by length, locals indexed by count, array access with bounds proofs). You can't read CA proofs without understanding heq.

### Learning Objectives

- Understand indexed families (`Vec α n` vs `List α`)
- Work with equality types (`Eq`, `HEq`, the difference)
- Prove theorems about array indexing with bounds
- Use subtype patterns (`{x : Nat // x < n}`)

### Dependent Types Crash Course

**Indexed family:**
```lean
-- Length-indexed vectors (type depends on value)
inductive Vec (α : Type) : Nat → Type where
  | nil : Vec α 0
  | cons : α → Vec α n → Vec α (n + 1)

-- Now the type system tracks length!
def head {α : Type} {n : Nat} : Vec α (n + 1) → α
  | Vec.cons x _ => x
-- No need for Option — type ensures non-empty

-- Your turn: implement tail
def tail {α : Type} {n : Nat} : Vec α (n + 1) → Vec α n :=
  sorry  -- hint: pattern match, return the tail
```

**Equality vs heterogeneous equality:**
```lean
-- Eq: homogeneous equality (same type)
example (n m : Nat) (h : n = m) : n = m := h

-- HEq: heterogeneous equality (possibly different types)
example {α β : Type} (x : α) (y : β) (ht : α = β) (hv : x == y) : True := by
  trivial

-- When you need HEq: dependent type changes
example (xs : Vec Nat n) (ys : Vec Nat m) (h : n = m) : xs == ys → xs = ys := by
  sorry  -- hint: cases h, then heq becomes eq
```

### Exercises

**Exercise 3.1: Vector indexing**
```lean
-- Safe array access via dependent types
def Vec.get {α : Type} {n : Nat} : Vec α n → (i : Nat) → i < n → α
  | Vec.cons x xs, 0, _ => x
  | Vec.cons x xs, i+1, h => xs.get i (Nat.lt_of_succ_lt_succ h)

-- Prove: getting element doesn't change vector
theorem vec_get_preserves {α : Type} {n : Nat} (v : Vec α n) (i : Nat) (h : i < n) :
    v == v := by
  sorry  -- hint: rfl works (reflexivity of heq)

-- Your turn: prove this
theorem vec_get_get {α : Type} {n : Nat} (v : Vec α n) (i j : Nat) 
    (hi : i < n) (hj : j < n) (hij : i = j) :
    v.get i hi = v.get j hj := by
  sorry  -- hint: cases hij, then bounds proofs are equal by proof irrelevance
```

**Exercise 3.2: Array.get? pattern (CA style)**
```lean
-- CA proofs use Array.get? to avoid explicit bounds proofs in statements
def myLocals : Array Nat := #[10, 20, 30]

example : myLocals.get? 0 = some 10 := rfl
example : myLocals.get? 5 = none := rfl

-- Prove: if get? succeeds, the array is non-empty
theorem get_some_implies_nonempty {α : Type} (arr : Array α) (i : Nat) (x : α)
    (h : arr.get? i = some x) : arr.size > 0 := by
  sorry  -- hint: cases on i, use Array.get?_eq_some

-- Your turn: prove this
theorem get_some_implies_in_bounds {α : Type} (arr : Array α) (i : Nat) (x : α)
    (h : arr.get? i = some x) : i < arr.size := by
  sorry  -- hint: unfold Array.get?, cases on i < arr.size
```

**Exercise 3.3: CA frame indexing (realistic)**
Here's actual CA pattern — locals access with bounds management:

```lean
structure Frame where
  pc : Nat
  locals : Array Nat
  stack : List Nat

-- Real CA theorem style: uses get? to defer bounds to proof context
theorem immBorrowLoc_preserves_local 
    (k : Nat) (f : Frame) 
    (h_bound : k < f.locals.size) :
    (step_immBorrowLoc k f).locals.get? k = f.locals.get? k := by
  sorry
  -- In real CA proof:
  -- unfold step_immBorrowLoc
  -- simp only [Array.get?_eq_get, h_bound]
  -- rfl
```

Your turn: prove this following the pattern above.

### Checkpoint

Can you:
- [ ] Explain the difference between `Eq` and `HEq`?
- [ ] Work with array indexing without panicking on bounds proofs?
- [ ] Read a CA theorem statement with `Array.get?` and understand why it's there?
- [ ] Prove a theorem about indexed structures (Vec, Array)?

**Time estimate:** 10-12 hours over 2 weeks

**Resources:**
- "Theorem Proving in Lean 4" (chapter 9: Structures and Records, chapter 10: Type Classes)
- CA example: Read `lean/MovementFormal/MoveModel/StepLemmas/Structs.lean` — how are array bounds handled?

---

## Stage 4: MoveModel Semantics (Week 8-9)

**Goal:** Understand the Move VM execution model as formalized in Lean. Learn how the `step` function works, what a frame is, and how bytecode sequences execute.

**Why this matters:** All CA proofs are about MoveModel execution. You're proving properties of `step`, `run`, and their composition. Without understanding the model, proofs are just symbol manipulation.

### Learning Objectives

- Understand Move VM stack-based execution
- Read bytecode and predict execution
- Work with the `Frame` and `CallStack` structures
- Prove `step` properties for simple instructions
- Prove `run` properties (multi-step execution)

### MoveModel Architecture

**Frame structure (simplified from actual CA):**
```lean
structure Frame where
  pc : Nat                          -- program counter
  locals : Array Value              -- local variables
  stack : List Value                -- operand stack
  function_handle : Nat             -- which function we're in
  h_pc_bound : pc < bytecode.length -- PC validity invariant
```

**Step function (conceptual):**
```lean
def step (env : Env) (frame : Frame) (callstack : CallStack) (memory : Memory) 
    : Result (Frame × CallStack × Memory) :=
  match env.bytecode[frame.pc] with
  | Instruction.LdU64 n =>
    -- Load constant n onto stack
    .success { frame with 
                pc := frame.pc + 1
              , stack := Value.u64 n :: frame.stack }
  | Instruction.Add =>
    -- Pop two, push sum
    match frame.stack with
    | Value.u64 a :: Value.u64 b :: rest =>
      .success { frame with 
                  pc := frame.pc + 1
                , stack := Value.u64 (a + b) :: rest }
    | _ => .error "type mismatch"
  | Instruction.StLoc k =>
    -- Pop and store to locals[k]
    match frame.stack with
    | v :: rest =>
      .success { frame with 
                  pc := frame.pc + 1
                , stack := rest
                , locals := frame.locals.set! k v }
    | _ => .error "stack underflow"
  -- ... 40+ more instructions
```

**Run function (multi-step):**
```lean
def run (env : Env) (frame : Frame) (cs : CallStack) (ms : Memory) 
    (fuel : Nat) : Result (Frame × CallStack × Memory) :=
  match fuel with
  | 0 => .timeout
  | fuel' + 1 =>
    match step env frame cs ms with
    | .success (frame', cs', ms') =>
      if frame'.pc >= bytecode.length then
        .returned frame'.stack cs' ms'
      else
        run env frame' cs' ms' fuel'
    | .error msg => .error msg
```

### Exercises

**Exercise 4.1: Bytecode reading**
Given this bytecode sequence:
```
0: LdU64 10
1: LdU64 20
2: Add
3: StLoc 0
4: Ret
```

What are the frame states after each instruction? Fill in:

```
PC=0: stack=[], locals=[?]
PC=1: stack=[10], locals=[?]
PC=2: stack=[10, 20], locals=[?]
PC=3: stack=[30], locals=[?]
PC=4: stack=[], locals=[30]
PC=5: (return)
```

**Exercise 4.2: Single-step proof**
Prove that `LdU64` increases stack length by 1:

```lean
theorem step_LdU64_stack_length (env : Env) (frame : Frame) (n : Nat)
    (h_instr : env.bytecode[frame.pc] = Instruction.LdU64 n) :
    let frame' := step env frame
    frame'.stack.length = frame.stack.length + 1 := by
  sorry
  -- hint: unfold step, simp only [h_instr], rfl
```

**Exercise 4.3: Two-step composition**
Prove that executing `LdU64 a; LdU64 b` in sequence produces stack `[a, b, ...]`:

```lean
theorem two_ldu64_composition (env : Env) (frame0 : Frame)
    (h0 : env.bytecode[frame0.pc] = Instruction.LdU64 a)
    (h1 : env.bytecode[frame0.pc + 1] = Instruction.LdU64 b) :
    let frame1 := step env frame0
    let frame2 := step env frame1
    frame2.stack.take 2 = [Value.u64 b, Value.u64 a] := by
  sorry
  -- hint: step twice, simplify, check stack shape
```

**Exercise 4.4: Run until return**
Prove that the bytecode sequence from Exercise 4.1 returns `[30]`:

```lean
def simple_function_bytecode : Array Instruction := #[
  Instruction.LdU64 10,
  Instruction.LdU64 20,
  Instruction.Add,
  Instruction.StLoc 0,
  Instruction.Ret
]

theorem simple_function_returns_30 :
    run env (initial_frame simple_function_bytecode) cs ms 100 
    = .returned [Value.u64 30] cs ms := by
  sorry
  -- hint: unfold run repeatedly (5 times), simplify each step
  -- this is tedious — real CA proofs use automation
```

**Exercise 4.5: CA-style symbolic state**
Real CA proofs don't chain frames — they use symbolic state. Replicate the pattern:

```lean
-- Symbolic state for simple_function above
@[irreducible] def simple_function_state := 
  { result : Value.u64 30
  , local0_final : Value.u64 30 }

-- Projection lemmas
@[simp] theorem simple_function_state_result :
    simple_function_state.result = Value.u64 30 := by
  unfold simple_function_state; rfl

-- Top-level theorem in CA style
theorem simple_function_eval_equiv :
    run env (initial_frame simple_function_bytecode) cs ms 100 
    = .returned [simple_function_state.result] cs ms := by
  sorry
  -- hint: unfold simple_function_state only in result
  -- prove the run property separately
  -- compose them with simp
```

### Checkpoint

Can you:
- [ ] Read a bytecode sequence and predict stack/locals evolution?
- [ ] Prove a property of a single `step` call?
- [ ] Prove a property of a `run` sequence (2-3 instructions)?
- [ ] Understand why CA proofs use symbolic state instead of frame chains?

**Time estimate:** 12-16 hours over 2 weeks

**Resources:**
- Read: `lean/MovementFormal/MoveModel/Exec.lean` (step function)
- Read: `lean/MovementFormal/MoveModel/Run.lean` (run function)
- CA example: `lean/MovementFormal/Experimental/ConfidentialAsset/Normalization/EvalEquiv.lean` (14-instruction run proof)

---

## Stage 5: CA-Specific Patterns (Week 10-12)

**Goal:** Master the patterns used in actual CA verification: oracle modeling, functional simulation, PC chaining, composition theorems.

**Why this matters:** This is the real work. Everything before was building the toolkit. This stage is where you contribute to the verification effort.

### Learning Objectives

- Model cryptographic oracles as opaque functions
- Write functional simulations for sigma protocol verifiers
- Chain PC-level step proofs into full function proofs
- Prove composition theorems (eval ≡ functional sim)
- Close temporary axioms or extend existing proofs

### CA Verification Patterns

**Pattern 1: Oracle modeling**
Cryptographic operations (Schnorr verify, Bulletproofs, SHA-256) are modeled as opaque functions:

```lean
-- Abstract oracle interface
opaque verify_schnorr_proof 
    (public_key : RistrettoPoint)
    (message : ByteArray)
    (signature : SchnorrSignature) : Bool

-- Axioms capture external security guarantees
axiom schnorr_soundness :
  verify_schnorr_proof pk msg sig = true →
  ∃ sk, pk = generator_mul sk ∧ signature_was_generated_by sk msg sig

axiom schnorr_completeness :
  ∀ sk msg, 
    let sig := generate_schnorr_signature sk msg
    verify_schnorr_proof (generator_mul sk) msg sig = true
```

Why opaque? We don't re-prove elliptic curve crypto in Lean — we rely on audited implementations and bind them via difftest.

**Pattern 2: Functional simulation**
High-level spec of what a protocol should do:

```lean
-- Functional simulation for Registration protocol
def registrationFunctionalSim 
    (public_key : RistrettoPoint)
    (proof : SchnorrProof) : RegistrationResult :=
  -- Check proof structure
  if proof.commitment.length ≠ 32 then
    .error "malformed commitment"
  else if proof.response.length ≠ 32 then
    .error "malformed response"
  else
    -- Verify Schnorr proof
    if verify_schnorr_proof public_key (fiat_shamir_challenge proof) proof then
      .success public_key
    else
      .aborted ESIGMA_PROTOCOL_VERIFY_FAILED_ABORT_CODE
```

This is the SPEC — what the bytecode SHOULD compute.

**Pattern 3: PC chaining**
Prove bytecode implements the spec by chaining step lemmas:

```lean
theorem registration_eval_equiv_functional_sim 
    (public_key : RistrettoPoint)
    (proof : SchnorrProof) :
    run env (registration_initial_frame public_key proof) cs ms 1000
    = to_move_result (registrationFunctionalSim public_key proof) := by
  
  -- Unfold run to step sequence
  unfold run
  
  -- PC 0: LdConst (load public_key)
  have h0 := step_ldconst_preserves public_key
  rw [h0]
  
  -- PC 1-5: Extract proof fields
  have h1_5 := step_sequence_extract_proof_fields proof
  rw [h1_5]
  
  -- PC 6: Call native verify_schnorr_proof
  have h6 := step_call_native_schnorr
  cases verify_schnorr_proof public_key ... with
  | true =>
    -- Success branch: PC 7-10
    have h7_10 := step_sequence_success_path
    rw [h7_10]
    rfl
  | false =>
    -- Failure branch: PC 11-12
    have h11_12 := step_sequence_abort_path
    rw [h11_12]
    rfl
```

Real CA proofs are ~200 lines of this pattern (Registration rebuild is 3300 lines covering 55 PCs + 28 native calls).

### Exercises

**Exercise 5.1: Simple oracle modeling**
Model a simplified "hash to scalar" oracle:

```lean
-- Oracle interface
opaque hash_to_scalar (data : ByteArray) : Scalar

-- Security axiom (collision resistance)
axiom hash_to_scalar_injective :
  ∀ data1 data2, hash_to_scalar data1 = hash_to_scalar data2 → data1 = data2

-- Your turn: write functional sim for a protocol that checks hash equality
def hashCheckFunctionalSim (data1 data2 : ByteArray) : Bool :=
  sorry  -- return true iff hash_to_scalar data1 = hash_to_scalar data2
```

**Exercise 5.2: Functional simulation**
Write functional sim for a simplified withdrawal check:

```lean
-- Withdrawal verifies: amount < balance AND range proof valid
def withdrawalFunctionalSim 
    (encrypted_balance : ElGamalCiphertext)
    (amount : Nat)
    (range_proof : BulletproofRangeProof) : WithdrawalResult :=
  sorry
  -- Check: verify_range_proof amount range_proof = true
  -- Check: amount ≤ decrypt encrypted_balance (assume we have secret key)
  -- Return: .success if both checks pass, else .aborted or .error
```

**Exercise 5.3: Two-PC chain**
Prove a 2-instruction sequence matches functional sim:

```lean
-- Bytecode: LdU64 n; MoveToLoc k
-- Functional sim: store n to locals[k]
def store_constant_sim (n k : Nat) : Array Nat → Array Nat :=
  fun locals => locals.set! k n

theorem store_constant_eval_equiv (n k : Nat) (frame0 : Frame) :
    let frame1 := step env { frame0 with bytecode[pc] = LdU64 n }
    let frame2 := step env { frame1 with bytecode[pc+1] = StLoc k }
    frame2.locals = store_constant_sim n k frame0.locals := by
  sorry
  -- hint: step twice, unfold store_constant_sim, show array equality
```

**Exercise 5.4: Case-split on oracle**
Prove a protocol that branches on oracle result:

```lean
-- Bytecode: CallNative verify_schnorr; BrFalse abort_label
-- Functional sim: if verify succeeds, continue; else abort
def conditional_verify_sim (pk : PublicKey) (sig : Signature) : VerifyResult :=
  if verify_schnorr_proof pk msg sig then
    .success
  else
    .aborted 65537

theorem conditional_verify_eval_equiv (pk : PublicKey) (sig : Signature) :
    run env (verify_initial_frame pk sig) cs ms 100
    = to_move_result (conditional_verify_sim pk sig) := by
  unfold run conditional_verify_sim
  -- Step to CallNative
  have h_call := step_call_native_verify pk sig
  -- Case split on verify result
  cases hv : verify_schnorr_proof pk msg sig with
  | true =>
    -- Success path: no branch taken, continue
    simp [hv]
    sorry  -- complete the success path
  | false =>
    -- Abort path: branch taken
    simp [hv]
    sorry  -- complete the abort path
```

**Exercise 5.5: Contribute to CA (capstone)**
Pick one of these and implement:

**Option A:** Add a missing step lemma to `StepLemmas/` library
- Choose an instruction class (e.g., `ImmBorrowField`, `Pack`)
- Prove a general lemma parametric over any frame
- Verify it's used in at least one CA proof

**Option B:** Extend an existing CA proof
- Pick a protocol (Normalization is simplest: 14 PCs)
- Read the `EvalEquiv.lean` file
- Add a new property (e.g., "normalization preserves balance value")

**Option C:** Close a temporary axiom
- Check `#print axioms` on a CA theorem
- Pick one axiom from the list
- Attempt to prove it (may not finish, but get far enough to see the structure)

### Checkpoint

Can you:
- [ ] Read a CA `EvalEquiv.lean` file and identify: functional sim, PC chain, case splits?
- [ ] Write a simple functional simulation for a new protocol?
- [ ] Prove a 5-10 PC bytecode sequence matches a functional sim?
- [ ] Contribute a small proof or extension to the CA verification effort?

**Time estimate:** 16-20 hours over 3 weeks (includes contribution time)

**Resources:**
- Read: `lean/MovementFormal/Experimental/ConfidentialAsset/Normalization/EvalEquiv.lean` (full working example)
- Read: `lean/MovementFormal/Experimental/ConfidentialAsset/Transfer/EvalEquiv.lean` (complex example, 24 PCs)
- Study: `audit/AXIOM_INVENTORY.md` (understand what axioms remain)
- Contribute: Check `CONFIDENTIAL_ASSETS_UNIFIED_VERIFICATION_PLAN.md` Phase 1 and Phase 6 for open work

---

## Parallel Learning: MSL Track

**When to start:** After Stage 2 (once you understand proof structure)  
**Time commitment:** 6-8 weeks parallel to Lean track  
**Goal:** Verify Move source code using Move Specification Language (MSL) and Move Prover

### MSL Learning Path

**Week 1-2: MSL Syntax**
- Learn `spec` block syntax
- Understand `requires`, `ensures`, `aborts_if`, `modifies`
- Write simple pre/post conditions for Move functions

Resources:
- Move Book: "Formal Verification" chapter
- Example: Read `aptos-experimental/sources/confidential_asset/confidential_asset.spec.move`

**Week 3-4: Invariants and Ghost Code**
- Resource invariants (`invariant`)
- Global invariants
- Ghost variables (`spec var`)
- Frame conditions (`modifies`)

Exercise: Write invariants for a simple token contract.

**Week 5-6: Move Prover Workflow**
- Run `movement move prove` locally
- Interpret verification errors
- Debug failing VCs (verification conditions)
- Use `pragma verify = true` selectively

Exercise: Fix a broken spec in CA modules.

**Week 7-8: CA-Specific MSL Patterns**
- `pragma opaque` for crypto boundaries
- Composing with FA framework specs
- Abort code specifications
- Balance preservation invariants

Capstone: Write a complete spec for one CA `_internal` function.

### MSL-Lean Coordination

**Key insight:** MSL and Lean prove different things about the same code.

- **MSL proves:** source-level properties (balance conservation, abort conditions, resource invariants)
- **Lean proves:** bytecode-level crypto properties (sigma verifier correctness)
- **Difftest binds them:** ensures source and bytecode agree on concrete inputs

**Integration points:**
1. Same abort codes in MSL `aborts_with` and Lean functional sim
2. Same function signatures (param count, types)
3. Same native function interfaces (MSL `pragma opaque`, Lean `@[opaque]`)

**Example coordination:**
```move
// In .move source
spec withdraw_to_internal {
  aborts_if !verify_withdrawal_proof(...) with 65537;  // sigma verify failed
  ensures old_balance = new_balance + amount;          // balance conservation
}
```

```lean
-- In Lean functional sim
def withdrawalFunctionalSim ... :=
  if ¬ verify_withdrawal_proof ... then
    .aborted 65537  -- SAME abort code
  else
    .success (balance - amount)  -- SAME balance relation
```

Read `audit/COMPOSITION_CLAIMS.md` for how these compose into end-to-end guarantees.

---

## Parallel Learning: Difftest Track

**When to start:** After Stage 1 (basic Lean fluency)  
**Time commitment:** 4-6 weeks parallel to other tracks  
**Goal:** Validate Lean proofs against real Move VM execution using differential testing

### Difftest Learning Path

**Week 1-2: Difftest Concepts**
- Understand corpus-based testing
- Read a corpus row (JSON input/output pair)
- Distinguish: VM execution, Lean simulation, oracle behavior

Resources:
- Read: `difftest/README.md`
- Study: `difftest/inventory/confidential_assets.md` (87 corpus rows)

**Week 3-4: Running Difftest**
- Run `difftest.sh` locally
- Interpret diff output (VM vs Lean)
- Debug a failing corpus row

Exercise: Run difftest on Registration corpus, confirm all 23 rows pass.

**Week 5-6: Adding Corpus Rows**
- Design a new test case
- Generate VM output (run Move VM)
- Generate Lean output (evaluate Lean model)
- Commit corpus row

Exercise: Add 1 new corpus row for an edge case (e.g., withdrawal with amount = 0).

**Week 7-8: Oracle Mocking**
- Understand mocked vs real oracles
- Write oracle JSON specifications
- Validate oracle consistency across VM and Lean

Capstone: Add a corpus row that exercises a native oracle call.

### Difftest-Lean Coordination

**Key insight:** Difftest validates that Lean proofs model reality.

- **Lean proves:** ∀ input, bytecode behavior matches functional sim
- **Difftest validates:** on THIS input, Lean simulation matches VM output

**Workflow:**
1. Prove theorem in Lean (∀ property holds)
2. Pick representative inputs (corpus rows)
3. Run VM on those inputs → get actual output
4. Run Lean eval on same inputs → get model output
5. Difftest compares: if they match, Lean model is faithful

**Example:**
```lean
-- Lean theorem (universal claim)
theorem registration_eval_equiv :
  ∀ public_key proof,
    run env (registration_initial_frame public_key proof) cs ms 1000
    = registrationFunctionalSim public_key proof
```

```json
// Difftest corpus row (concrete instance)
{
  "name": "registration_happy_path",
  "input": {
    "public_key": "0x1a2b3c...",
    "proof_commitment": "0x4d5e6f...",
    "proof_challenge": "0x7g8h9i...",
    "proof_response": "0xajbkc..."
  },
  "vm_output": { "status": "success", "events": [...] },
  "lean_output": { "status": "success", "public_key_registered": "0x1a2b3c..." }
}
```

If `vm_output ≠ lean_output`, either:
- Lean model is wrong (fix the model)
- VM has a bug (rare, but has happened)
- Corpus row is malformed (fix the test case)

Read `INTEGRATION_TESTING_AND_CROSS_LAYER_VALIDATION_GUIDE.md` for detailed workflow.

---

## Common Pitfalls and How to Avoid Them

### Pitfall 1: Proof by Trial-and-Error
**Symptom:** Trying tactics randomly until something works  
**Why it happens:** Skipping Stage 0 — no intuition for what proofs are  
**Fix:** Go back to Stage 0. Write the proof in English FIRST. Then translate to Lean.

### Pitfall 2: Opaque Simp
**Symptom:** `simp` works but you don't know why  
**Why it happens:** Simp is powerful but hides reasoning  
**Fix:** Use `simp only [lemma1, lemma2]` instead. Make simp explicit.

### Pitfall 3: Ignoring Error Messages
**Symptom:** Stuck on an error, asking for help without reading the message  
**Why it happens:** Lean errors are verbose and technical  
**Fix:** Read the FIRST line of the error. It usually says exactly what's wrong. Common errors:
- "type mismatch" → you provided `Nat` but expected `Int`
- "unknown identifier" → typo or forgot to import
- "tactic failed" → the tactic can't apply (e.g., `rw` when sides aren't equal)

### Pitfall 4: Fighting the Type System
**Symptom:** Trying to coerce types, using `cast`, adding `sorry` to "just make it compile"  
**Why it happens:** Type mismatch is a SIGNAL, not an obstacle  
**Fix:** Trust the type system. If Lean says types don't match, they probably shouldn't. Refactor the proof, don't hack around it.

### Pitfall 5: Skipping Checkpoints
**Symptom:** Jumping ahead to Stage 5 without mastering Stage 2  
**Why it happens:** Eagerness to contribute  
**Fix:** Slow down. Each stage builds on the previous. Skipping leads to confusion later. Do the checkpoint exercises — they catch gaps.

### Pitfall 6: Not Asking for Help
**Symptom:** Stuck for 2+ hours on the same error  
**Why it happens:** Don't want to bother the team  
**Fix:** Ask! Use Lean Zulip, CA team chat, or GitHub discussions. Formal verification is HARD — everyone gets stuck. The community is helpful. Just provide:
- Minimal code snippet
- Full error message
- What you've tried

### Pitfall 7: Perfectionism
**Symptom:** Rewriting the same proof 5 times to make it "elegant"  
**Why it happens:** Lean proofs can be beautiful, and that's enticing  
**Fix:** Get it working first, elegant later. A `sorry`-free proof that works is better than a half-finished elegant proof. Refactor in a second pass.

---

## Self-Assessment Checkpoints

Use these to gauge readiness before advancing:

### Checkpoint: Ready for Stage 1?
- [ ] I can write a proof by induction by hand (on paper)
- [ ] I can explain what a "proof" means in mathematics
- [ ] I understand the difference between "proof" and "verification"

### Checkpoint: Ready for Stage 2?
- [ ] I can prove `map_append` in Lean without looking up syntax
- [ ] I can read Lean error messages and understand "type mismatch"
- [ ] I can navigate Lean infoview (goals, hypotheses, expected type)

### Checkpoint: Ready for Stage 3?
- [ ] I can choose the right tactic for a given goal (reflexivity, rewrite, induction, cases)
- [ ] I can debug a failing `simp` by making it explicit
- [ ] I've contributed 1 step lemma to CA `StepLemmas/` library

### Checkpoint: Ready for Stage 4?
- [ ] I understand `Eq` vs `HEq` and when each is needed
- [ ] I can work with array indexing without panicking on bounds proofs
- [ ] I've proven 1 theorem about indexed structures (Vec, Array)

### Checkpoint: Ready for Stage 5?
- [ ] I can read bytecode and predict stack evolution
- [ ] I can prove a 3-instruction bytecode sequence matches a spec
- [ ] I understand why CA uses symbolic state instead of frame chains

### Checkpoint: Ready to Contribute?
- [ ] I can read a CA `EvalEquiv.lean` file and identify key proof structure
- [ ] I can write a functional simulation for a new protocol
- [ ] I've proven a 10+ PC bytecode chain or closed 1 axiom or extended 1 CA proof

If you check all boxes in "Ready to Contribute," you're ready for real CA verification work!

---

## Resources and References

### Books
- **"Theorem Proving in Lean 4"** (official tutorial) — https://lean-lang.org/theorem_proving_in_lean4/
- **"How to Prove It"** by Daniel Velleman (foundations)
- **"Software Foundations"** (Coq-based, but concepts transfer) — https://softwarefoundations.cis.upenn.edu/

### Online Communities
- **Lean Zulip Chat** — https://leanprover.zulipchat.com (most active, friendly to beginners)
- **Lean 4 GitHub Discussions** — https://github.com/leanprover/lean4/discussions
- **Mathlib4 Docs** — https://leanprover-community.github.io/mathlib4_docs/

### CA-Specific Resources
- **CA Unified Plan** — `CONFIDENTIAL_ASSETS_UNIFIED_VERIFICATION_PLAN.md` (roadmap)
- **CA Architecture** — `CA_ARCHITECTURE_OVERVIEW.md` (high-level)
- **Proof Debugging** — `PROOF_DEBUGGING_ADVANCED_STRATEGIES.md` (when stuck)
- **Step Lemmas Library** — `lean/MovementFormal/MoveModel/StepLemmas/` (reusable building blocks)
- **Worked Examples**:
  - Registration (complex): `lean/MovementFormal/Experimental/ConfidentialAsset/Registration/EvalEquivRebuild.lean`
  - Normalization (simple): `lean/MovementFormal/Experimental/ConfidentialAsset/Normalization/EvalEquiv.lean`
  - Transfer (very complex): `lean/MovementFormal/Experimental/ConfidentialAsset/Transfer/EvalEquiv.lean`

### Video Tutorials
- **Lean 4 Tutorial Series** by leanprover-community — YouTube
- **3Blue1Brown: Essence of Linear Algebra** (mathematical intuition) — YouTube
- **Computerphile: Formal Verification** (high-level intro) — YouTube

### Practice Problem Sets
- **Lean 4 Exercises** — https://github.com/leanprover/lean4-samples
- **Natural Number Game** (browser-based, fun) — https://adam.math.hhu.de/#/g/leanprover-community/NNG4
- **CA Mini-Exercises** — Each stage in this guide has embedded exercises

---

## Graduated! What's Next?

Congratulations on completing the learning path! You're now equipped to contribute to CA formal verification.

**Next steps:**

1. **Join the team:** Introduce yourself, share what you've learned, ask for a first task
2. **Pick a contribution:**
   - Close a temporary axiom (check `audit/AXIOM_INVENTORY.md`)
   - Extend a CA proof (add a new property)
   - Add corpus rows (difftest coverage expansion)
   - Improve documentation (you just learned this — what was confusing?)
3. **Stay current:** CA verification is ongoing — follow plan updates, participate in reviews
4. **Help others:** You just climbed this mountain — help the next person by improving this guide, answering questions, writing worked examples

**Long-term growth:**

- **Contribute to Lean ecosystem:** Once you're fluent, contribute step lemmas, tactics, or documentation to benefit other projects
- **Cross-stack expertise:** Learn MSL + Difftest deeply (not just surface-level) — being fluent in all three stacks makes you invaluable
- **Research:** Consider publishing formal verification techniques, especially CA-specific patterns that could apply to other ZK protocols

**Recognition:**

Formal verification is HARD. You've acquired a rare, valuable skill. Whether you become a full-time formal verification engineer or use these skills to write more robust code, you've leveled up in a way few engineers do.

Well done.

---

## Appendix: Quick Reference

### Tactic Cheat Sheet
| Tactic | Use When | Example |
|--------|----------|---------|
| `rfl` | Both sides reduce to same term | `n + 0 = n` → `rfl` (after rewrite) |
| `rw [lemma]` | Rewrite using equality | `rw [Nat.add_comm]` |
| `simp` | Simplify with all simp lemmas | `simp` (opaque, use sparingly) |
| `simp only [...]` | Controlled simplification | `simp only [List.append_nil]` |
| `unfold def` | Expand definition | `unfold step` |
| `cases h` | Case split on type | `cases opt with \| none => ... \| some x => ...` |
| `induction n` | Proof by induction | `induction n with \| zero => ... \| succ n ih => ...` |
| `have h : P := proof` | Intermediate claim | `have h : n < m := ...` |
| `apply lemma` | Apply lemma to goal | `apply Nat.lt_trans` |
| `exact term` | Provide explicit proof | `exact h` |

### Common Lean Syntax
| Syntax | Meaning |
|--------|---------|
| `∀ x, P x` | For all x, P(x) holds |
| `∃ x, P x` | There exists x such that P(x) |
| `P ∧ Q` | P and Q |
| `P ∨ Q` | P or Q |
| `P → Q` | P implies Q |
| `¬P` | Not P |
| `x = y` | Equality (homogeneous) |
| `x == y` | Heterogeneous equality (HEq) |
| `{ x // P x }` | Subtype: x such that P(x) |
| `#check expr` | Show type of expression |
| `#eval expr` | Evaluate expression |
| `#print def` | Show definition |
| `#print axioms thm` | Show axioms used in theorem |

### CA Proof Patterns
| Pattern | File Example | Key Technique |
|---------|--------------|---------------|
| Step lemma | `StepLemmas/Locals.lean` | Parametric over frame, simp lemma |
| PC chain | `Normalization/EvalEquiv.lean` | Unfold run, step repeatedly, rfl |
| Functional sim | `Registration/FunctionalSim.lean` | High-level spec, case splits |
| Oracle modeling | `AptosStd/Crypto/Schnorr.lean` | Opaque def + axioms |
| Symbolic state | `Registration/EvalEquivRebuild.lean` | @[irreducible] state + projections |
| Composition | `Registration/Phase6Composition.lean` | eval_equiv → functional_sim |

---

**Document metadata:**
- **Version:** 1.0
- **Author:** CA Verification Team
- **Maintained by:** See `CONTRIBUTING_TO_CA_VERIFICATION.md`
- **Feedback:** Open an issue or PR with suggested improvements
- **Last major update:** 2026-04-22

**Related guides:**
- `DEVELOPER_ONBOARDING_GUIDE.md` — Quickstart for experienced engineers
- `PROOF_DEBUGGING_ADVANCED_STRATEGIES.md` — When you're stuck
- `ADVANCED_LEAN_PROOF_TECHNIQUES_GUIDE.md` — Advanced patterns beyond this guide
- `CONFIDENTIAL_ASSETS_UNIFIED_VERIFICATION_PLAN.md` — Current work and roadmap
