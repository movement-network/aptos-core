# EvalEquiv build-time guide

This directory houses the `eval ≡ functional-sim` proof split across `Part1.lean`–`Part4.lean`.
Full `lake build` takes ~25–40 minutes; Part3 alone used to be ~27 min. Below is what to do —
and what not to do — to keep the build tractable as you add PCs or edit proofs.

## The main performance trap: frame-chain unfolds

Each `step_pc{N}_*_generic` theorem stacks ~20 frame definitions (`registrationFramePc{N}…`)
linearly back to `registrationInitFrame`. The old pattern used a single `simp` call listing every
intermediate frame def:

```lean
have hpc : fr'.pc < fr'.code.size := by
  simp [fr', registrationFramePc55AfterStLoc15, registrationFramePc53AfterImmBorrow10,
    registrationFramePc52AfterImmBorrow13, registrationFramePc51AfterStLoc14, …  -- 20 more
    verifyRegistrationProofCode_size_val]
```

Every invocation re-elaborates the entire chain — that's why the theorems at PC ≥ 55 were
carrying `maxHeartbeats 3200000`-to-`12800000` (16× to 64× the default).

## The fix: cache projections once

For each frame def that downstream `step_pc*_generic` theorems depend on, add two `rfl`-proven
`@[simp]` lemmas right after the def:

```lean
@[simp] theorem registrationFramePc{N}_code_eq (…) :
    (registrationFramePc{N}After… …).code = verifyRegistrationProofCode := rfl

@[simp] theorem registrationFramePc{N}_pc_eq (…) :
    (registrationFramePc{N}After… …).pc = {N} := rfl
```

Then simplify the `hpc`/`hc` proofs:

```lean
have hpc : fr'.pc < fr'.code.size := by
  simp [hfr', registrationFramePc{N}_code_eq, verifyRegistrationProofCode_size_val]
have hc : fr'.code[fr'.pc]'hpc = MoveInstr.immBorrowLoc K := by
  simp [hfr', registrationFramePc{N}_code_eq, verifyRegistrationProofCode_idx{N}]
```

The `rfl` proof of the projection lemma pays the chain-unfold cost **once** at definition time;
downstream proofs rewrite through the cached fact and skip the unfold entirely.

### When to add `pc_eq`

- If fr' is wrapped as `{ Pc{N}… with pc := M }`, the outer `with` overrides `.pc` so you don't
  need `Pc{N}_pc_eq` — just `Pc{N}_code_eq` is enough.
- If fr' is used directly as `Pc{N}…`, add both.

## What doesn't help

- Replacing `set fr' := … with hfr'` by `let fr' := …` + `show` — measured ~5% **slower**
  because `show` forces eager defEq chain-unfold.
- Marking `registrationModuleEnv` `@[irreducible]` — touches 50+ call sites across Part1–Part3;
  risky without staged rollout.

## Measuring before you change

Put at the file top:

```lean
set_option profiler true
set_option profiler.threshold 500
```

`lake build` emits per-theorem `elaboration took Ns` and `simp took Nms` diagnostics. The theorems
carrying the highest `maxHeartbeats` overrides are the ones to inspect first. Run
`scripts/lint_heartbeats.sh` for a sorted list.

## Split status

`Part2.lean` was split at PC 44 and PC 55 into `Part2A.lean` (PCs 31–43), `Part2B.lean`
(PCs 44–54), and `Part2C.lean` (PCs 55–62); `Part2.lean` is now a thin aggregator that
re-imports the three parts so `import …EvalEquiv.Part2` still works from Part3/Part4.
Observed costs after split (Apr 2026): Part2A ≈ 6s, Part2B ≈ 93s, Part2C ≈ 384s, Part3 ≈ 1547s.
Total CI time is unchanged (linear dep chain), but incremental rebuild of a single PC region
skips the siblings — e.g. a PC 50 edit only rebuilds Part2B + Part3, saving Part2A+Part2C ≈ 6 min.

## Avoid reintroducing heartbeat overrides

`scripts/lint_heartbeats.sh` lists all `set_option maxHeartbeats N` above threshold (default 400k).
Run it as a local check or wire into CI:

```bash
scripts/lint_heartbeats.sh --strict   # exits 1 on any override > 400000
```
