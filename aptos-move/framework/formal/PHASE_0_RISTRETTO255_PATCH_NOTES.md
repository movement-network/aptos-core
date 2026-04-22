# Phase 0 — ristretto255 MSL spec patch notes

The Move Prover currently fails to compile any CA module because of two specific bugs in
`aptos-move/framework/aptos-stdlib/sources/cryptography/ristretto255.spec.move`. Plan §5.2 names
them; this doc records the candidate patches and the open question of where to upstream them.

## Bug 1 — `spec_scalar_from_u64_internal` / `spec_scalar_from_u128_internal` type mismatch

**Current declarations** (lines 295, 297):

```move
spec fun spec_scalar_from_u64_internal(num: u64): vector<u8>;
spec fun spec_scalar_from_u128_internal(num: u128): vector<u8>;
```

**Error path:** when `confidential_balance` is Boogie-translated, the `u64` / `u128`
arithmetic through `new_scalar_from_u64` / `new_scalar_from_u128` uses Boogie's bv64/bv128
encoding (selected per-module via `pragma bv_enabled`). But the spec funs above are declared
with `num: u64` which Boogie translates to `int` (the default integer encoding). The encoding
mismatch causes Boogie compilation to fail with:

```
expected bv64 but found int for argument 1 of spec_scalar_from_u64_internal
```

**Candidate patch (A) — declare both bv and int forms:**

Add companion functions under different names with bv-typed inputs:

```move
spec fun spec_scalar_from_u64_internal_bv(num: u64): vector<u8>;  // Boogie: accepts bv64
spec fun spec_scalar_from_u128_internal_bv(num: u128): vector<u8>;

// Axiom bridging the two:
spec fun spec_scalar_from_u64_internal_bv_eq_int(num: u64) :
    spec_scalar_from_u64_internal_bv(num) == spec_scalar_from_u64_internal(num);
```

**Candidate patch (B) — module-level pragma forcing int encoding:**

Add at the top of `ristretto255.spec.move`:

```move
spec module {
    pragma bv_implementation = false;  // use int encoding throughout
}
```

Needs verification that this doesn't break any existing upstream prover runs that assume bv.

**Candidate patch (C) — remove `u64`/`u128` and use `num` (MSL universal integer):**

```move
spec fun spec_scalar_from_u64_internal(num: num): vector<u8>;
spec fun spec_scalar_from_u128_internal(num: num): vector<u8>;
```

`num` is MSL's arbitrary-precision integer type that translates to Boogie's `int` regardless
of the module's bv encoding — but the trade-off is losing the u64/u128 range axioms at the
spec-fun boundary, requiring callers to add explicit range assertions.

**Recommendation:** try (B) first (least invasive); fall back to (A) if (B) breaks other
upstream runs.

## Bug 2 — `vector<CompressedRistretto>::length` monomorphization missing

**Error path:** `confidential_proof` uses `vector<CompressedRistretto>` for its sigma X-point
arrays. When `vector::length<CompressedRistretto>(&v)` appears inside an MSL spec or assertion,
Boogie needs a monomorphized `$Length_vector_CompressedRistretto` instance. None is emitted
for this type because there's no `#[verify]`-tagged CA-side call site that prompts the Move
Prover to emit the monomorphization for the `CompressedRistretto` element type.

**Candidate patch — add explicit monomorphization trigger in `ristretto255.spec.move`:**

```move
spec module {
    // Force emission of vector-length monomorphization for all Ristretto struct types
    // so downstream modules (confidential_proof, confidential_balance) can reason about
    // `vector<CompressedRistretto>` / `vector<RistrettoPoint>` lengths.
    invariant [deactivated] forall v: vector<CompressedRistretto> : len(v) >= 0;
    invariant [deactivated] forall v: vector<RistrettoPoint> : len(v) >= 0;
}
```

The `[deactivated]` invariants never fire but their mere presence forces the Move Prover's
boogie-gen to emit the monomorphization. This is the standard workaround for MSL's missing
auto-monomorphization.

## Upstream or carry?

Open question from plan §8 Q1: do we upstream these patches to `aptos-core` or carry locally?

- **Upstream pro:** one source of truth; other Move Prover users benefit from the fixes.
- **Upstream con:** upstream review cycle is months; CA verification work blocked meanwhile.
- **Carry pro:** unblocks CA work today.
- **Carry con:** maintenance burden on every framework sync; risk of accidental drop.

**Recommendation:** submit patches upstream AND carry a local branch-copy until merged. The
carry copy lives in `aptos-move/framework/aptos-stdlib/sources/cryptography/ristretto255.spec.move`
directly (no separate file — edit in place). Document in commit message: "carries
[upstream PR #XXXX](link) pending review."

## Next steps

1. [ ] Reproduce Bug 1 locally by attempting `movement move prove --filter confidential_balance` —
       capture the exact error message for the upstream PR description.
2. [ ] Try Candidate patch B (module-level `pragma bv_implementation = false`). If it works,
       single-line fix.
3. [ ] If B fails, try patch A (companion bv funs + axiom).
4. [ ] Reproduce Bug 2 by attempting `movement move prove --filter confidential_proof` — capture
       error.
5. [ ] Apply monomorphization-trigger invariants; confirm Boogie compiles.
6. [ ] Run full CA prover lane (`move-prover-ca.yaml` workflow); confirm all four `.spec.move`
       files compile even if they don't yet verify.
7. [ ] Open upstream PR + file local carry issue.
