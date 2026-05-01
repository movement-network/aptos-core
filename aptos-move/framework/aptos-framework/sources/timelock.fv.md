# Timelock module — formal verification status & TODO

## Current status

`movement move prove --filter timelock` reports **Success** (with
`BOOGIE_EXE` and `Z3_EXE` set; Z3 must be ≤ 4.11.2). The proof is real but **not complete**: several
specs use `pragma aborts_if_is_partial` or `pragma verify = false`, which
narrow what the prover actually checks. This document enumerates each gap and
what is needed to close it.

### Verified end-to-end (no escape hatches)

- `validate_members` — proven. Body uses an explicit `while` loop with a
  `spec { invariant ... }` block (5 invariants linking `distinct` to the
  prefix of `members`). Both `aborts_if` clauses discharge.
- View functions: `creators`, `executors`, `min_num_seconds_execute`,
  `is_creator`, `is_executor`, `get_transaction`.
- Pure helpers: `create_timelock_account_seed`, `get_transaction_hash`.
- Self-governance modifiers: `update_min_num_seconds_execute`,
  `remove_executors` (modulo `aborts_if_is_partial` notes below).
- `cancel_transaction`, `create_timelock_account_internal` — full
  `aborts_if`/`ensures` checked.

### Currently using escape hatches

| Function | Pragma | Reason |
|---|---|---|
| `create` | `verify = false` | Cross-module effects of `create_resource_account` + `coin::register<AptosCoin>` |
| `create_timelock_account` | `verify = false` | Same as above |
| `resolve` | `verify = false` | `transaction_context::get_script_hash()` is a native with no spec abstraction |
| `add_creators` | `aborts_if_is_partial` | Cross-list duplicate abort path not yet specified |
| `add_executors` | `aborts_if_is_partial` | Cross-list duplicate abort path not yet specified |
| `remove_creators` | `aborts_if_is_partial` | Post-removal `>= 1` invariant not enumerated |
| `create_transaction` | `aborts_if_is_partial` | Aborts from `Table::add` and `keccak256` not enumerated |
| `can_be_executed` | `aborts_if_is_partial` | `creation_time_secs + num_seconds_execute` u64 overflow not enumerated |
| `get_next_timelock_account_address` | `aborts_if_is_partial` | `account::get_sequence_number` abort behavior not modeled |

## What needs to be done

### 1. Add resource invariants on `TimelockAccount` (foundational)

Required so callers like `add_creators`/`add_executors` can prove that the
*existing* creators/executors lists do not contain the timelock address itself
and have no internal duplicates. These invariants are established at creation
by `validate_members` and preserved by every modifier — but the prover does
not derive them.

```move
spec module {
    invariant forall addr: address where exists<TimelockAccount>(addr):
        forall i in 0..len(global<TimelockAccount>(addr).creators):
            global<TimelockAccount>(addr).creators[i] != addr;
    // ... same for executors, plus no-duplicates for both.
}
```

**Blocker:** the current `add_creators` / `add_executors` flow appends *then*
re-validates. The append at line 322 / 364 temporarily violates the
invariants, and `pragma disable_invariants_in_body` is not sufficient on its
own — the prover still requires the post-state to satisfy invariants and
demands explicit `aborts_if` clauses for every path that would otherwise
break them.

**Fix:** refactor `add_creators` and `add_executors` to **validate before
mutating**. Two options:

a. Build a temporary combined vector, run `validate_members` on it, then
   assign:
   ```move
   let combined = copy timelock.creators;
   combined.append(new_creators);
   validate_members(&combined, timelock_address, EDUPLICATE_CREATOR);
   timelock.creators = combined;
   ```

b. Add an explicit cross-list dedup loop *before* the append, with its own
   loop invariant.

Option (a) is simpler to verify but copies the existing list (gas cost
proportional to current member count). Option (b) avoids the copy but adds
another while loop with its own spec annotations.

### 2. Spec abstraction for `transaction_context::get_script_hash`

`resolve` is currently `verify = false` because the prover has no model for
the running script's hash.

**Fix:** add an uninterpreted spec function in the framework's
`transaction_context.spec.move` (or local to `timelock.spec.move` if the
framework can't be touched):

```move
spec module {
    fun spec_script_hash(): vector<u8>;
}

spec get_script_hash(): vector<u8> {
    pragma opaque;
    aborts_if [abstract] false;
    ensures [abstract] result == spec_script_hash();
}
```

Then `resolve`'s spec can use `spec_script_hash()` in `aborts_if`/`ensures`,
remove `pragma verify = false`, and discharge the script-hash equality check.

### 3. Tighten `create_transaction`

Remove `aborts_if_is_partial` and enumerate the remaining abort paths:

- `Table::add` aborts if the key already exists — already covered by the
  preceding `table::spec_contains` check, but the prover may need this
  spelled out.
- `keccak256` itself: with the `spec_keccak256` substitution applied (already
  done), this should be `aborts_if [abstract] false`.

### 4. Tighten `remove_creators`

Replace `aborts_if_is_partial` with a precise `aborts_if`:

```move
aborts_if (count of existing creators not in creators_to_remove) < 1;
```

Expressing "count of survivors" requires a spec helper function or set
arithmetic. Likely needs a `spec fun` like:

```move
spec fun creators_after_removal(existing, to_remove): vector<address>;
```

with axioms or recursive definition.

### 5. Tighten `can_be_executed`

Add an overflow `aborts_if`:

```move
aborts_if table::spec_contains(timelock.transactions, transaction_hash)
    && table::spec_get(timelock.transactions, transaction_hash).creation_time_secs
        + table::spec_get(timelock.transactions, transaction_hash).num_seconds_execute > MAX_U64;
```

This was attempted but failed verification — the prover insisted the
function does not actually abort under this condition. Likely cause: short-
circuit semantics in the Move source's `&&` mean the addition is only
evaluated when `tx.executed` is false; the spec needs the same gating.

### 6. Verify `create` and `create_timelock_account`

These call `account::create_resource_account` (which *is* fully verified in
`account.spec.move`) and `coin::register<AptosCoin>` (which has its own spec
gaps related to fungible-asset migration).

**Investigation needed:** remove `pragma verify = false` from each and run
the prover to surface the actual blocker. If it's `coin::register`'s spec,
either (a) wait for upstream spec improvements or (b) wrap the call in a
helper with its own `verify = false` that's narrowly scoped.

### 7. Re-introduce resource invariants once (1) is done

After `add_creators` / `add_executors` are refactored, restore the four
global invariants from the rolled-back attempt and verify they hold across
all modifiers (`create_timelock_account_internal`, `add_*`, `remove_*`).

## Toolchain prerequisites

The local `movement` CLI requires:

- `BOOGIE_EXE` pointing to a Boogie binary (3.x works).
- `Z3_EXE` pointing to a Z3 binary, version **≤ 4.11.2** (the bundled prover
  rejects 4.14.x).

Without these, `movement move prove` fails before doing useful work. Earlier
spec drafts that called `aptos_std::aptos_hash::keccak256` directly inside
`ensures`/`aborts_if` clauses also tripped a separate Boogie translation bug
(undeclared `$1_aptos_hash_$keccak256`). The fix — already applied — is to
reference the abstract spec helper `spec_keccak256` in spec contexts rather
than the runtime function.

## Effort estimate

| Item | Estimated effort |
|---|---|
| 1. Refactor add_* + invariants | half-day |
| 2. `get_script_hash` abstraction | 1-2 hours |
| 3. Tighten `create_transaction` | 1 hour |
| 4. Tighten `remove_creators` | 2-3 hours (set arithmetic) |
| 5. Tighten `can_be_executed` | 1 hour |
| 6. Verify `create` / `create_timelock_account` | unknown — depends on upstream specs |
| 7. Re-add invariants and re-verify | 1-2 hours after (1) lands |

Total to reach "no `verify = false`, no `aborts_if_is_partial`" on the
in-module functions (everything except (6)): roughly **1-2 days** of
prover-engineering work, assuming no new toolchain issues surface.

(6) is open-ended and may require framework-level spec PRs rather than
changes inside this module.
