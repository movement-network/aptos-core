# Plan: Formal verification for Confidential Assets (experimental)

**Dual-track program (confidential assets):**

1. **Difftest / alignment** — milestones, merged e2e oracle, and **§4.5 checklist** (“properly difftested” in the repo’s sense): **[`CONFIDENTIAL_ASSETS_DIFFERENTIAL_TESTING_PLAN.md`](CONFIDENTIAL_ASSETS_DIFFERENTIAL_TESTING_PLAN.md)**.
2. **Formal verification** — **L0–L5** obligations, refinement, and proof hygiene: **this document**.

Neither track replaces the other: difftest catches **VM↔model drift** on goldens; FV is what supports **“Move implements the intended math”** claims for reviewers.

**Program bar (“properly difftested *and* formally verified”):** both tracks are required, in the following sense (see **§1.3**):

- **(A) Crypto / proof obligations** — machine-checked properties of the **intended math** (transcripts, hashes, curve / proof interfaces, registration soundness-style lemmas, …), largely **L0** and crypto-facing workstreams here.
- **(B) Bytecode vs spec** — connecting **Lean `Move` execution** (and eventually module wiring / storage) to those specs via **refinement** and **`eval`**-level proofs (**L2–L5** as applicable), not only oracle agreement on finite rows.
- **(C) Both (A) and (B)** — this repo’s **completion** goal for CA formal work is **(C)**: difftest and corpora are **necessary regression evidence**; **(A)** and **(B)** together are what “formally verified” means here, unless a milestone explicitly scopes down (e.g. oracle-only L1 for a slice).

---

This document is a **roadmap** for extending the **`AptosFormal`** stack so that **confidential assets** (`aptos_experimental::confidential_*` and dependencies) can be **machine-checked** with a clear statement of what is proved against what. It is written for engineers and proof engineers working in `aptos-move/framework/formal/`.

**Related docs**

- Lean build / difftest workflow: [`lean/README.md`](lean/README.md), [`difftest/README.md`](difftest/README.md)
- Bytecode model + roadmap: [`lean/AptosFormal/Move/README.md`](lean/AptosFormal/Move/README.md)
- Registration **spec-level** review (today’s main CA formal work): [`REGISTRATION_VERIFY_REVIEW.md`](REGISTRATION_VERIFY_REVIEW.md)
- CA Move **audit notes** (semantics / harness sharp edges while building formal artifacts): [`CONFIDENTIAL_ASSETS_MOVE_AUDIT_NOTES.md`](CONFIDENTIAL_ASSETS_MOVE_AUDIT_NOTES.md)

---

## 1. Definitions

### 1.1 “Confidential assets” in this repo

**In scope (Move sources, relative to repo root):**

| Layer | Module(s) | Path |
|-------|-----------|------|
| Asset controller | `aptos_experimental::confidential_asset` | `aptos-move/framework/aptos-experimental/sources/confidential_asset/confidential_asset.move` |
| Proofs / verification | `aptos_experimental::confidential_proof` | `…/confidential_proof.move` |
| Encrypted balances | `aptos_experimental::confidential_balance` | `…/confidential_balance.move` |
| Twisted ElGamal | `aptos_experimental::ristretto255_twisted_elgamal` | `…/ristretto255_twisted_elgamal.move` |
| Test / harness helpers | `aptos_experimental::confidential_gas_e2e_helpers` | `…/confidential_gas_e2e_helpers.move` |

**Transitive dependencies (must be in scope for *full* entrypoint verification):**

- `aptos_std::ristretto255`, `aptos_std::aptos_hash`, Bulletproofs / range-proof APIs as used from Move
- `std::bcs`, `std::vector`, `std::option`, `std::signer`, …
- **Fungible asset / object / dispatchable FA** paths used by `confidential_asset` entrypoints
- Any **governance / allow-list** modules actually invoked

### 1.2 What “formally verified” means here (levels)

Use **explicit levels** so stakeholders do not confuse them:

| Level | Meaning | Example |
|-------|---------|---------|
| **L0 – Spec only** | Pure Lean `Prop` / functions aligned to Move **source**; no bytecode. | Today: `AptosFormal.Experimental.ConfidentialAsset.Registration.*` for `verify_registration_proof` math + transcript goldens. |
| **L1 – Differential** | Real VM vs Lean **evaluator** on shared oracles; **not** a proof. | Today: `vector`, `bcs`, `hash`, **`global_resource_smoke`**, **`confidential_*`** harness suites + **merged CA e2e** JSON in CI; many merged CA rows use Lean **witness** stubs (constant returns) — see differential plan **§4.5 / §11**. |
| **L2 – Bytecode refinement (local)** | For a **single** function or closed snippet: transcribed `CodeUnit` in Lean + `Move.step`/`eval` agrees with a **Lean spec** (possibly `sorry`-free under hypotheses). | Today: `Refinement/Core.lean`, `Refinement/Vector.lean` for stdlib-shaped code. |
| **L3 – Bytecode + module wiring** | Correct `ModuleEnv`, constant pool, **native dispatch**, `Call`/`Ret` across **multiple** functions in one compilation unit. | Not done for CA. |
| **L4 – Resource / global state** | Model **`borrow_global`**, `move_to`, signer, **FA stores**; proofs about **entrypoints** that touch storage. | **Not** in current `Move.Instr` “omitted” set; largest extension. |
| **L5 – End-to-end chain** | L4 + **compiler correctness** (Move source ↔ bytecode) or a **trusted** disassembly pipeline. | Optional; separate project from “verify this branch’s Move”. |

The **completion scope** tag **(A) / (B) / (C)** (crypto vs bytecode-vs-spec vs **both**) is spelled out in **§1.3**; the levels above map onto those tags (e.g. **(A)** ↔ L0-heavy crypto, **(B)** ↔ L2–L5, **L1** ↔ difftest evidence).

**“All of confidential assets formally verified”** in a **single milestone** is not realistic. This plan targets **L0 already in progress**, then **L1 → L2 → L3** in priority order, with **L4** as a **branching** track when entrypoint proofs are required.

### 1.3 Program completion scope: **(A)**, **(B)**, and **(C)**

Stakeholders sometimes split “formal verification” into *crypto proofs* vs *implementation proofs*. **For confidential assets in this program, “formally verified” means both:**

| Tag | Meaning | Typical artifacts / levels |
|-----|---------|------------------------------|
| **(A)** | **Crypto / proof obligations** — the Move-facing **math and protocol** story is proved (or clearly axiomatized) in Lean **independently of** “does `eval` replay this bytecode.” | **L0** modules (e.g. registration transcript / Schnorr / hash lemmas), future BP / Ristretto specs as claimed in Workstream A. |
| **(B)** | **Bytecode vs spec** — the **Lean Move model** (`Move.step` / `eval`, `ModuleEnv`, natives, later globals/FA) is shown to **implement** or **refine** the relevant specs on chosen units or entrypoints. | **L2** `Refinement.*`, **L3** module wiring, **L4** resources / FA, **L5** optional compiler-trust story. |
| **(C)** | **Both** — the **intended bar** for “CA is formally verified” in repo documentation and planning: **(A)** without **(B)** leaves an execution gap; **(B)** without **(A)** can match wrong crypto. | Delivered incrementally per milestone; **L1 difftest** is **evidence**, not a substitute for **(C)**. |

**Difftest (L1)** remains **essential** for **regression and alignment**, but it does **not** by itself satisfy **(A)** or **(B)**; it supports **(B)** by pinning concrete behaviors and **(A)** indirectly via goldens, not by proving ∀-properties.

---

## 2. Current baseline (move-lean / formal tree)

### 2.1 Already present

- **`AptosFormal.Move.*`**: partial bytecode instruction set, `Step`/`run`/`eval`, `ModuleEnv`, **`MachineState`** with abstract globals (`GlobalResourceKey`); **no** full `StructTag`+FA signer semantics, variants, or closures (see [`Move/README.md`](lean/AptosFormal/Move/README.md), [`difftest/STUB_POLICY.md`](difftest/STUB_POLICY.md)).
- **`AptosFormal.Native`**: BCS (selected monomorphizations), `sha3_256`, vector-related natives — **not** CA’s full native surface.
- **`AptosFormal.Refinement`**: small `rfl` programs + **`vector::contains`**-style universal proof for curated bytecode.
- **`AptosFormal.Refinement.Confidential`** (**L2 / track B**): `eval confidentialModuleEnv …` agrees with **Move-constant** specs for CA harness rows — **`confidential_balance`** chunk / zero-serialization **`u64`** views (**0–4**), **Bulletproofs** UTF-8 DST + **`u64(16)`** num-bits + **SHA3-512** digest (**14** / **15** / **34**, full **`vector<u8>`** where applicable), **Fiat–Shamir sigma DST** getters (**43–46** / **51**, full **`mvU8Wire`** vs **`Programs.Confidential.fiat*SigmaDstBytes`**), **registration FS golden `msg`** (**38**, **`mvU8Wire`** vs **`Programs.Confidential.registrationFsMsgGoldenMoveBytes`**), **registration tagged-hash goldens** (**174** / **175**, **`mvU8Wire`** vs **`TranscriptAlignment.expectedTaggedHashGolden{,2}.toList`** via **`Programs.Confidential.registrationTaggedHashGolden*MoveBytes`**), **sigma wire length** **`bool(true)`** indices **128–130** and transfer-extension **131** / **133** / **135** / **137** / **139** / **141** / **143** / **145** / **147** / **149** / **151** / **153** / **155** / **157** / **159** / **161** / **163** / **165** / **167** (through **4224** B), FA stub **`faWriteBalance` + `faReadBalance`** round-trip (**169**, **`u64(9999)`** from empty **`faBalances`**), registration FS framework **`bool(true)`** (**170**), registration Schnorr verify on the fixed difftest fixture (**35** / **171**, same **`Operational.execVerifyRegistrationProof`** oracle), second FS golden **`vector<u8>`** + framework **`bool`** rows (**172** / **173**), empty **`serialize_auditor_*`** vectors (**36** / **37**), and pinned **`serialize_auditor_*`** wires (**114–127**); see `lean/AptosFormal/Refinement/Confidential.lean`.
- **`move-lean-difftest`**: **`vector`**, **`bcs`**, **`hash`**, **`global_resource_smoke`**, **`confidential_balance`**, **`confidential_elgamal`**, **`confidential_proof`**, **`confidential_asset`** (layer), **`fa_stub`** ([`difftest/src/suites/mod.rs`](difftest/src/suites/mod.rs)); plus **e2e-exported** CA oracle fragments merged for CI (`DIFTEST_MERGE_CA_E2E`).
- **`AptosFormal.Experimental.ConfidentialAsset.Registration.*`**: **L0** for **`verify_registration_proof`** (crypto story, transcript bytes, axioms/oracles) — **not** bytecode execution in Lean. **`TranscriptAlignment`** pins **`registrationChallengeScalarMove`** on each golden FS `msg` to **`scalarUniformFrom64Bytes`** of the matching **64**-byte tagged digest (`registrationChallengeScalarMove_golden1_msg_eq_uniform_expectedTaggedHashGolden`, `registrationChallengeScalarMove_golden2_msg_eq_uniform_expectedTaggedHashGolden2`). **`Operational`** includes **`execVerifyRegistrationProof_eq_some_iff_pointEqBool_of_parsed`** (post-parse success ↔ `pointEqBool` on the Schnorr LHS).
- **VM↔Lean sigma wire lengths (L1-flavored, real `Step`):** indices **128–130** return **`bool(true)`** when the pinned **`deserialize_sigma_*.hex`** byte vectors have lengths **1152** / **1216** / **1792** (`ldConst` + `vecLen` + `eq`) — complements **M11** stubs on **`deserialize_*` `Some`** rows without claiming parser parity.
- **Wire-level lemmas (L0-flavored, not `eval`):** `AptosFormal.Move.Programs.Confidential` pins VM auditor amount serializer bytes and proves small structural facts (e.g. **`serializeAuditorAmounts_mixed512_orders_distinct`**, **`serializeAuditorAmounts_mixed768_orders_distinct`** — permutations with identical multiset of balances but different vector order are byte-distinct; **`serializeAuditorEksThreeApointWireBytes_length`** / append characterization for **96**-byte triple-**A_POINT** EK wires; **`serializeAuditorEksFourApointWireBytes_length`** for **128**-byte quadruple-**A_POINT** EK wires; **`serializeAuditorEksFiveApointWireBytes_length`** and **`serializeAuditorEksFiveApointWireBytes_eq_deserializeRepeatConcat`** for **160**-byte quintuple-**A_POINT** EK wires vs the same repeat-concat used in sigma layout bytes; **`serializeAuditorEksSixApointWireBytes_length`** / **`serializeAuditorEksSixApointWireBytes_eq_deserializeRepeatConcat`** for **192**-byte sextuple-**A_POINT** EK wires; **`deserializeSigma18Scalars18PointsBytes_five_points_eq_serializeAuditorEksFiveApoint`** / **19** / **transfer** variants — the first five **A_POINT** slots in each checked **`deserialize_sigma_*.hex`** layout match the **160**-byte EK corpus; **`deserializeSigma18Scalars18PointsBytes_six_points_eq_serializeAuditorEksSixApoint`** (and **19** / **transfer** variants) match the first **six** compressed-point slots to the **192**-byte EK corpus), supporting difftest corpora without claiming full `deserialize_*` / `verify_*` in the evaluator.

### 2.2 Gap

There is **no** end-to-end continuous path yet from **full** **`confidential_asset` / `confidential_proof` / `confidential_balance` / `ristretto255_twisted_elgamal` bytecode** (including globals, FA, and real crypto natives) to **`Move.eval`** + **refinement** + **difftest**. **Partial track B** coverage for the **harness** module exists in **`Refinement.Confidential`** (constant views + sigma length rows); wiring **entrypoints**, **L3** calls, and **L4** state remains open.

---

## 3. Guiding principles

1. **Prove the smallest meaningful slice first** (one function, one path, one oracle).
2. **Separate concerns**: native crypto correctness vs VM stepping vs global storage vs compiler.
3. **Difftest before hard proofs** for each new bytecode transcription — catches transcription and native wiring bugs early.
4. **Reuse L0 specs**: refinement theorems should relate `eval` to existing `verifyRegistrationProofProp`-style definitions where possible, rather than duplicating math in prose.
5. **Document proof obligations**: every `sorry`, axiom, and “trusted disassembly” must be listed for auditors (pattern already in [`lean/README.md`](lean/README.md) and [`REGISTRATION_VERIFY_REVIEW.md`](REGISTRATION_VERIFY_REVIEW.md)).

---

## 4. Dependency graph (conceptual)

```text
  aptos_std (ristretto, hash, …)     move-stdlib (bcs, vector, …)
           \                           /
            \                         /
             v                       v
    ristretto255_twisted_elgamal  confidential_balance
                     \               /
                      v             v
                  confidential_proof
                           |
                           v
                   confidential_asset  ──► FA / object / globals (L4)
```

**Suggested verification order (bottom-up):**

1. **Crypto primitives + twisted ElGamal** (natives + pure helpers).
2. **`confidential_balance`** (chunking, homomorphic ops — mostly local).
3. **`confidential_proof`** (sigma / range / deserialization — heavy natives).
4. **`confidential_asset`** (composition + **storage**).
5. **`confidential_gas_e2e_helpers`** (test-only / harness — lower priority unless product depends on it).

---

## 5. Workstreams (run in parallel where possible)

### Workstream A — **Native and crypto specs**

**Goal:** For every **Move native** invoked on CA paths, either:

- implement **`List MoveValue → Option (List MoveValue)`** in Lean consistent with `AptosFormal.Std.*` / `AptosFormal.AptosStd.*`, or  
- document an **`opaque` / axiom** boundary with a **reviewed** contract (weaker).

**Tasks**

- Build a **static call graph** from disassembled CA + dependencies (script or manual table): list each `native fun` and `Call` target.
- For each native: map to existing Lean (`Std.Hash`, `Std.Bcs`, `AptosStd.Crypto`, …) or add new spec modules.
- **Bulletproofs / range proof verification**: either full Lean spec (very large) or **oracle** for difftest + abstract interface for proofs (“if native returns `true`, then …”).
- Align **tagged SHA3-512**, **scalar from bytes**, **decompress**, etc., with goldens already used in registration / Move tests.

**Exit criteria**

- A **checked-in table**: native name → Lean implementation status (`done` / `axiom` / `oracle-only`).

**Partial (tree today):** high-level matrix + status legend for **`aptos_hash` / `ristretto255` / `ristretto255_bulletproofs`** vs CA modules — [`difftest/inventory/confidential_native_matrix.md`](difftest/inventory/confidential_native_matrix.md) (extend with **per-native** rows over time). **Difftest:** VM **`deserialize_*` → `Some`** on fixed sigma layouts (canonical zero scalar + **A_POINT** repeats + empty ZKRP byte vectors); checked-in **hex** (`deserialize_sigma_*.hex`, including transfer extensions **1920** / **2048** / **2176** / **2304** / **2432** / **2560** / **2688** / **2816** / **2944** / **3072** / **3200** / **3328** / **3456** / **3584** / **3712** / **3840** / **3968** / **4096** / **4224** B) + **`move-lean-difftest verify-corpora`** + Lean **`deserializeSigma*Bytes_length`** / prefix lemmas; Lean **110–113** run the same **`ldConst` + `vecLen` + `eq`** bytecode as **128–130**; **131–132** / **133–134** / **135–136** / **137–138** / **139–140** / **141–142** / **143–144** / **145–146** / **147–148** / **149–150** / **151–152** / **153–154** / **155–156** / **157–158** / **159–160** / **161–162** / **163–164** / **165–166** / **167–168** use **`ldConst` 27** / **28** / **29** / **30** / **31** / **32** / **33** / **34** / **35** / **36** / **37** / **38** / **39** / **40** / **41** / **42** / **43** / **44** / **45** (not full **`deserialize_*`** in `eval`). **Proofs:** `Programs/Confidential` — **`confidentialLayoutSomeRowsLeanEval_bool_true`**, **`confidentialLayoutSomeRow*_*_eval_eq_*`**, **`confidentialSigmaTransferExtended1920RowsLeanEval_bool_true`**, **`confidentialSigmaTransferExtendedEval_131_eq_132`**, **`confidentialSigmaTransferExtended2048RowsLeanEval_bool_true`**, **`confidentialSigmaTransferExtendedEval_133_eq_134`**, **`confidentialSigmaTransferExtended2176RowsLeanEval_bool_true`**, **`confidentialSigmaTransferExtendedEval_135_eq_136`**, **`confidentialSigmaTransferExtended2304RowsLeanEval_bool_true`**, **`confidentialSigmaTransferExtendedEval_137_eq_138`**, **`confidentialSigmaTransferExtended2432RowsLeanEval_bool_true`**, **`confidentialSigmaTransferExtendedEval_139_eq_140`**, **`confidentialSigmaTransferExtended2560RowsLeanEval_bool_true`**, **`confidentialSigmaTransferExtendedEval_141_eq_142`**, **`confidentialSigmaTransferExtended2688RowsLeanEval_bool_true`**, **`confidentialSigmaTransferExtendedEval_143_eq_144`**, **`confidentialSigmaTransferExtended2816RowsLeanEval_bool_true`**, **`confidentialSigmaTransferExtendedEval_145_eq_146`**, **`confidentialSigmaTransferExtended2944RowsLeanEval_bool_true`**, **`confidentialSigmaTransferExtendedEval_147_eq_148`**, **`confidentialSigmaTransferExtended3072RowsLeanEval_bool_true`**, **`confidentialSigmaTransferExtendedEval_149_eq_150`**, **`confidentialSigmaTransferExtended3200RowsLeanEval_bool_true`**, **`confidentialSigmaTransferExtendedEval_151_eq_152`**, **`confidentialSigmaTransferExtended3328RowsLeanEval_bool_true`**, **`confidentialSigmaTransferExtendedEval_153_eq_154`**, **`confidentialSigmaTransferExtended3456RowsLeanEval_bool_true`**, **`confidentialSigmaTransferExtendedEval_155_eq_156`**, **`confidentialSigmaTransferExtended3584RowsLeanEval_bool_true`**, **`confidentialSigmaTransferExtendedEval_157_eq_158`**, **`confidentialSigmaTransferExtended3712RowsLeanEval_bool_true`**, **`confidentialSigmaTransferExtendedEval_159_eq_160`**, **`confidentialSigmaTransferExtended3840RowsLeanEval_bool_true`**, **`confidentialSigmaTransferExtendedEval_161_eq_162`**, **`confidentialSigmaTransferExtended3968RowsLeanEval_bool_true`**, **`confidentialSigmaTransferExtendedEval_163_eq_164`**, **`confidentialSigmaTransferExtended4096RowsLeanEval_bool_true`**, **`confidentialSigmaTransferExtendedEval_165_eq_166`**, **`confidentialSigmaTransferExtended4224RowsLeanEval_bool_true`**, **`confidentialSigmaTransferExtendedEval_167_eq_168`**, **`confidentialFaStubWriteReadEval_u64_9999`** (`native_decide` on `eval`). **`Refinement.Confidential`:** **`confidential_bulletproofs_views_eval_bundle`** (**14** / **15** / **34**), **`confidential_fiat_shamir_sigma_dst_eval_bundle`** (**43–46** / **51**), **`registration_fs_message_golden_move_eval_eq_vector`** (**38**), **`sigma_transfer_ext3456_len_eval_eq`** (**155**), **`sigma_transfer_ext3584_len_eval_eq`** (**157**), **`sigma_transfer_ext3712_len_eval_eq`** (**159**), **`sigma_transfer_ext3840_len_eval_eq`** (**161**), **`sigma_transfer_ext3968_len_eval_eq`** (**163**), **`sigma_transfer_ext4096_len_eval_eq`** (**165**), **`sigma_transfer_ext4224_len_eval_eq`** (**167**), **`fa_stub_write_then_read_balance_eval_eq_u64_9999`** (**169**), **`registration_fs_framework_matches_helpers_golden_eval_eq_true`** (**170**), **`registration_fs_message_golden_move_second_eval_eq_vector`** (**172**), **`registration_fs_framework_second_scenario_matches_helpers_golden_eval_eq_true`** (**173**), **`registration_helpers_roundtrip_eval_eq_true`** (**35**) / **`registration_framework_deterministic_verify_roundtrip_eval_eq_true`** (**171**) / **`registration_helpers_roundtrip_eval_eq_framework_verify_roundtrip_eval`**, **`confidential_serialize_auditor_wires_eval_bundle`** (**114–127**).

---

### Workstream B — **Lean bytecode model extensions**

**Goal:** `MoveInstr` / `Step` / `State` support **every instruction** needed by chosen CA bytecode, or a **documented** reduction (e.g. “we only verify inlined core”).

**Tasks**

- For each target function: `movement move compile` + disassemble; diff against supported `MoveInstr` set; extend [`Instr.lean`](lean/AptosFormal/Move/Instr.lean) / [`Step.lean`](lean/AptosFormal/Move/Step.lean) as needed.
- Revisit **omissions** from [`Move/README.md`](lean/AptosFormal/Move/README.md): **globals**, **variants**, **closures** — decide **per milestone** whether to add them or keep verification **intraprocedural** (function body only with **assumed** initial locals / heap snippet).

**Exit criteria**

- `lake build` green; **smoke** `native_decide` tests run for new instruction paths.

---

### Workstream C — **Transcription and `ModuleEnv`**

**Goal:** For each verified function: **`Array MoveInstr`** + **`FuncDesc`** + **constant pool** + **native table** entries match the **compiler output** for this repo revision.

**Tasks**

- Add `Programs/Confidential*.lean` (or similar) mirroring today’s [`Programs/Vector.lean`](lean/AptosFormal/Move/Programs/Vector.lean) pattern: hand-written + **real** `real…Code` where useful.
- Extend [`Programs.lean`](lean/AptosFormal/Move/Programs.lean) `stdModuleEnv` (or a dedicated **`caModuleEnv`**) with function indices; keep **disassembly provenance** in comments (commit hash, compiler version).
- Serialization: Move **BCS / vector-of-u8** arguments must match Lean `MoveValue` decoding used by `eval` and difftest.

**Exit criteria**

- For each transcribed function: **bit-identical** or **semantically checked** against Rust VM on a **golden** input (Workstream D).

---

### Workstream D — **Differential testing (CA suite)**

**Goal:** New **`move-lean-difftest`** suite (e.g. `confidential` or split by submodule) following [`difftest/README.md`](difftest/README.md).

**Tasks**

- **Rust:** load compiled packages containing CA modules (same layout as today’s vector suite: `InMemoryStorage`, publish modules, invoke script or test entry).
- **Oracle JSON schema:** extend [`schema.rs`](difftest/src/schema.rs) if needed: function id, serialized args, expected **return values** / **abort** / optional **event** payloads.
- **Lean:** extend [`DiffTest/Runner.lean`](lean/AptosFormal/DiffTest/Runner.lean) (or parallel) to dispatch CA cases to `eval` / `evalProg` with **`caModuleEnv`**.
- **`difftest.sh` / CI:** register the new suite in [`suites/mod.rs`](difftest/src/suites/mod.rs).

**Exit criteria**

- One-command run from repo root; CI fails on VM vs Lean mismatch for registered goldens.

---

### Workstream E — **Refinement proofs**

**Goal:** **L2/L3** theorems: `eval env f args fuel = …` ↔ your **`Prop`** / functional spec.

**Tasks**

- **Registration (`verify_registration_proof`)**: prove equivalence between **bytecode `eval`** result and **`verifyRegistrationProofProp`** (or `execVerifyRegistrationProof`) under explicit **fuel** and **parsing-success** side conditions — reusing [`Operational.lean`](lean/AptosFormal/Experimental/ConfidentialAsset/Registration/Operational.lean) / [`VerifyMath.lean`](lean/AptosFormal/Experimental/ConfidentialAsset/Registration/VerifyMath.lean).
- **`confidential_balance`**: lemmas that homomorphic ops match **Twisted ElGamal** specs in Lean (may require **`AptosFormal`** specs for `ristretto255_twisted_elgamal` parallel to Move).
- **`confidential_proof`**: sigma + range proof **verification** as logical implications from native return + structured inputs.
- **`confidential_asset`**: only after **L4** or **stubbed** store — prove **local** helpers first.

**Exit criteria**

- No **unintended** `sorry` in shipped modules; `#print axioms` reviewed for each top-level theorem.

---

### Workstream F — **Global / resource semantics (L4, optional track)**

**Goal:** Model enough of **storage**, **`signer`**, and **FA** to state theorems about **`public entry fun`** behavior.

**Tasks**

- Extend `MoveValue` / `State` with a **minimal** resource map (type-indexed or monomorphic per milestone).
- Implement **`borrow_global`**, **`move_to`**, **`exists`**, … as in [`file_format.rs`](https://github.com/aptos-labs/aptos-core/blob/main/third_party/move/move-binary-format/src/file_format.rs) / interpreter — **large**.
- Integrate **dispatchable FA** behavior used by deposits/withdrawals or **prove** only **internal** `fun` paths that take pre-loaded references.

**Exit criteria**

- At least one **entrypoint**-level theorem **or** a published **negative result** (“we verify `foo_internal` only”) with clear scope.

---

## 6. Phased roadmap (milestones)

### Phase 0 — Inventory and proof obligations (2–4 weeks, ongoing)

**Deliverables**

- Call graph: CA modules → natives → stdlib.
- Table: function → **verification level target** (L0–L5) → owner.
- List of **goldens** (Move tests) to become difftest oracles.

**Partial (tree today):** registration FS `msg` + tagged SHA3-512 goldens as **hex corpora** with **`cargo run -p move-lean-difftest -- verify-corpora`** (Rust SHA3-512 cross-check vs Lean `TranscriptAlignment`) under [`difftest/corpora/confidential_assets/`](difftest/corpora/confidential_assets/).

**Overlap (difftest track):** the **VM↔Lean inventory** and methodology for CA live under [`difftest/INVENTORY.md`](difftest/INVENTORY.md) and [`difftest/inventory/confidential_assets.md`](difftest/inventory/confidential_assets.md) — extend the formal-plan tables from there or merge in a future edit.

**Dependencies:** none.

---

### Phase 1 — CA difftest harness + one golden (4–8 weeks)

**Deliverables**

- New difftest suite: **one** `public` or `public(friend)` function with **minimal** natives (e.g. a **balance** serializer or a **no-op** path).
- Lean runner + **one** committed or CI-generated oracle.

**Dependencies:** Workstream D; minimal B from **existing** instructions.

**Success:** CI runs VM + Lean on CA package.

**Status (tree today):** Multiple CA-related harness suites and **merged e2e** oracle paths are already wired (see **§2.1**); Phase 1 is **superseded for “existence of a suite”** — remaining Phase 1-style work is **§4.5 checklist depth** (non-witness Lean rows, corpora, `deserialize_*` `Some`, …) on the differential plan.

---

### Phase 2 — `ristretto255_twisted_elgamal` + `confidential_balance` (8–16 weeks)

**Deliverables**

- Native/spec coverage for **twisted ElGamal** operations used by balance.
- Bytecode transcription for **selected** `public fun` in `confidential_balance` (e.g. chunk split, encrypt-with-identity-randomness helpers if bytecode-heavy).
- Difftest goldens for those functions.
- **Refinement** for “plaintext chunk vector ↔ ciphertext” for **fixed** small cases, then generalize.

**Dependencies:** A (crypto), B/C, D, E.

---

### Phase 3 — `confidential_proof` (16+ weeks, parallelizable by sub-proof)

**Sub-phases**

3a. **Registration bytecode** (`verify_registration_proof`): transcription + natives + difftest + refinement to **existing L0** spec.  
3b. **Withdraw / normalize / key rotation** proofs: same pattern.  
3c. **`verify_transfer_proof`**: largest (sigma + Bulletproofs); consider **proof-modular** lemmas (verify sigma subroutine ↔ spec).

**Dependencies:** Phase 2; full A for crypto.

---

### Phase 4 — `confidential_asset` (depends on Phase 3 or stubbed proof calls)

**Deliverables**

- Internal `fun` verification where possible **without** L4.
- **L4** track: entry `confidential_transfer`, `deposit_to`, `withdraw_to`, … with **explicit** store axioms or modeled store.

**Dependencies:** Phase 3 + F if entrypoints required.

---

### Phase 5 — Hardening and regression

**Deliverables**

- **Upgrade playbook**: when Move or compiler changes, regenerate disassembly, rerun difftest, re-check `sorry`.
- Extend **golden consistency** scripts if CA bytes are duplicated in Lean ([`check_golden_consistency.sh`](check_golden_consistency.sh) pattern).

---

## 7. Risks and mitigations

| Risk | Mitigation |
|------|------------|
| Bulletproofs / range proofs too heavy to spec in Lean | Start **oracle-only** for native return; prove **simpler** lemmas; or bound scope to “native agrees with Rust reference impl” tested by difftest. |
| Proof effort explodes | **Per-function** milestones; keep **L0** specs as the contract. |
| Global FA semantics | Default to **L2 internal fun** first; document **L4** as stretch. |
| Compiler drift | Pin **toolchain + commit** in transcription headers; CI difftest. |

---

## 8. “Done” checklist (organization-level)

Use this as a **release gate** for claiming “CA is formally verified” at a given level:

- [ ] **Scope document**: which **functions** and which **level (L0–L5)** per function.
- [ ] **No undocumented `sorry`** in production Lean modules for claimed theorems.
- [ ] **`#print axioms`** reviewed and listed (including **`ristretto_subgroup_order_prime`**-style custom axioms).
- [ ] **Difftest** covers every **transcribed** function on representative inputs (or explains why not).
- [ ] **REGISTRATION_VERIFY_REVIEW** (or successor) updated to describe **bytecode refinement** if L2+ shipped for registration.
- [ ] **Move/README.md** updated: which **globals** / **natives** are supported for CA.

---

## 9. Summary

Formal verification of **all** confidential assets is a **multi-year**, **multi-workstream** effort if interpreted as **bytecode-level refinement + difftest + eventual storage**. The **feasible** path is:

1. **Keep and extend L0** (already strong for registration math).  
2. **Add CA difftest** and **grow natives + bytecode** from **twisted ElGamal** and **`confidential_balance`** upward.  
3. **Prove refinement** incrementally toward **`verify_registration_proof`**, then **other proof verifiers**, then **`confidential_asset`** with an explicit decision on **L4**.

This file is the **living plan**: update phase dates, owners, and checklist as work lands.
