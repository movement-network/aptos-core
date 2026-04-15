# Plan: Differential testing — Confidential Assets (experimental)

**Active scope (difftest track):** **Move VM ↔ Lean** differential testing (`move-lean-difftest` + `lake exe difftest` + optional merged e2e JSON). Success means **Tier A/B** green and honest progress on **§4.5** (including **Open** rows when claiming “properly difftested” beyond witness-only merged CA rows).

**Parallel scope (formal verification track):** Machine-checked obligations (**L0–L5** in [`CONFIDENTIAL_ASSETS_FORMAL_VERIFICATION_PLAN.md`](CONFIDENTIAL_ASSETS_FORMAL_VERIFICATION_PLAN.md)) — refinement, natives, storage — are **not** implied by difftest green alone. Both tracks are required for a peer-reviewable story that combines **regression evidence** (this doc) and **mathematical validity** (FV plan).

**“Properly difftested *and* formally verified” (repo goal):** means **(C) both** in the FV plan’s sense — **(A)** crypto / proof-level obligations **and** **(B)** bytecode-vs-spec refinement (and higher **L3–L5** wiring as scoped), not difftest alone. See **[`CONFIDENTIAL_ASSETS_FORMAL_VERIFICATION_PLAN.md`](CONFIDENTIAL_ASSETS_FORMAL_VERIFICATION_PLAN.md) §1.3** for the explicit **(A) / (B) / (C)** table; this differential-testing plan covers the **L1** evidence lane and checklists that feed **(B)** but do not replace it.

This document remains **empirical / finite**: it shows agreement on **recorded oracle cases**, not ∀-quantified correctness (see §2.2).

**Prerequisites:** How difftest works today: [`difftest/README.md`](difftest/README.md), [`lean/README.md`](lean/README.md).

**Move source audit (formal track):** [`CONFIDENTIAL_ASSETS_MOVE_AUDIT_NOTES.md`](CONFIDENTIAL_ASSETS_MOVE_AUDIT_NOTES.md) — API semantics / hardening notes from static review (not a product security sign-off).

**Completion rubric (“are we done?”):** Use **§4.3** (what “professionally complete” CA difftest coverage looks like) and **§4.4** (tiers **A / B / C** — how to answer without hand-waving).

---

## 1. What this approach is

- **Differential testing** here means: run the **same** inputs through  
  (A) the **real Move VM** (Rust, in-repo), and  
  (B) the **Lean** small-step evaluator (`AptosFormal.Move.Step` / `eval`),  
  then compare **outputs** (and aborts / errors) encoded in a shared **JSON oracle**.
- It is **empirical**, **finite**, and **regression-oriented**: it shows agreement on **the cases you run**, not a **proof for all inputs** or all execution paths.

---

## 2. What it **does** and **does not** show

### 2.1 What differential testing **provides evidence for**

| Claim | Strength |
|--------|----------|
| On oracle cases, **Lean’s bytecode model + native stubs** agree with **this VM + this compiled bytecode** for the **observed** return values, aborts, and any fields you put in the oracle (e.g. serialized return stack). | **Strong for those cases** — useful to catch transcription bugs, missing instructions, wrong native semantics, endian/layout mistakes. |
| **Regression detection:** after a Move or Lean change, rerunning the suite flags **drift** before production. | **Strong operational value.** |
| **Coverage growth:** more cases ⇒ more **confidence** (statistical / engineering), not a **theorem**. | **Inductive evidence only.** |

### 2.2 What it **does not** prove

| Non-claim | Why |
|-----------|-----|
| **Correctness for all inputs** | Only finitely many tests; no ∀. |
| **No bugs** outside the oracle | Untested paths may still be wrong in VM *or* Lean. |
| **Move source matches bytecode** | Difftest compares **engines on bytecode** (or serialized effects); **compiler correctness** is a separate obligation unless you always regenerate from the same pipeline and trust it. |
| **Cryptographic security** (e.g. soundness of proofs, absence of forgeries) | Difftest checks **functional equality** on samples, not **security definitions**. |
| **Lean natives “match the IRTF / independent crypto spec”** | You are checking **VM vs Lean**; both could disagree with an external reference unless you add separate audits or reference tests. |

**One sentence for stakeholders:**  
Differential testing gives **high-confidence alignment between two implementations on a maintained test set**; it does **not** replace **formal verification** (refinement, invariants, security proofs).

---

## 3. Important constraint: Lean must be able to **run** what you test

In this repository, the **Lean side of difftest is not a second Move VM** — it is **`AptosFormal.Move`**’s evaluator over **transcribed** bytecode + **native** implementations in Lean ([`Native.lean`](lean/AptosFormal/Move/Native.lean), `ModuleEnv`).

So **“entire confidential assets codebase under difftest”** still requires **engineering work** for every path you want to cover:

1. **Bytecode** for the involved functions available to Lean (transcribe or generate from disassembly).  
2. **`MoveInstr` / `Step`** support for every instruction those bytecodes use.  
3. **Native bindings** in Lean for every native those paths call (or a deliberate **narrow scope** that mocks/stubs natives and only compares a **slice** of behavior — must be documented).

**What you avoid compared to full formal verification:**  
You do **not** need to write **refinement theorems**, **inductive invariants**, or discharge **proof obligations** in Lean. You **do** still need enough of the **same interpreter stack** that the Lean run is meaningful.

**Rough effort comparison (intuition):**

| Activity | Full verification plan | **This doc (difftest only)** |
|----------|-------------------------|------------------------------|
| Transcription + natives + `Step` extensions | Required | **Still required** for VM↔Lean on those paths |
| Refinement proofs | Required | **Not required** |
| Timeline for “all CA” | Multi-year (proofs + storage) | **Still large** (natives + globals if testing entrypoints), but **shorter than proof** work and parallelizable as **test oracles** |

If the goal were **“VM-only golden tests”** (no Lean column), that would be a **different** (smaller) project — not the repo’s current **differential** design; we mention it in §9 as optional.

---

## 4. Scope — “entire confidential assets codebase”

### 4.1 Move modules (same as formal plan)

| Module | Path (under `aptos-move/framework/aptos-experimental/sources/confidential_asset/`) |
|--------|--------------------------------------------------------------------------------------|
| `confidential_asset` | `confidential_asset.move` |
| `confidential_proof` | `confidential_proof.move` |
| `confidential_balance` | `confidential_balance.move` |
| `ristretto255_twisted_elgamal` | `ristretto255_twisted_elgamal.move` |
| `confidential_gas_e2e_helpers` | `confidential_gas_e2e_helpers.move` (lower priority) |

Plus **transitive** dependencies actually executed (stdlib, `aptos_std`, FA, …) — tracked per test case.

### 4.2 What “coverage” means without proofs

Define **coverage dimensions** explicitly (checklist per milestone):

- [ ] **Functions:** every `public` / `public(friend)` / `entry` you care about appears in at least one oracle.  
- [ ] **Branches:** happy path + representative **abort** / `none` / verification-failure paths where observable.  
- [ ] **Natives:** each native on a hot path has at least one case (or is listed as **out of scope** for Lean column).  
- [ ] **Auditors / optional features:** toggled in dedicated cases.

These bullets are a **minimal inventory checklist**; **§4.3** is the **full professional bar**, and **§4.4** is how to report **which tier (A/B/C)** you satisfy.

### 4.3 Professionally complete confidential-asset difftest coverage (quality bar)

This subsection is **normative for how to talk about “done”** in reviews and when asking assistants: it does **not** redefine Phase 6.x delivery dates, but it **does** define what **“professionally acceptable / complete difftest coverage for CA”** means in industry terms.

**Complete ≠ formal verification.** Completeness here means: **stated scope**, **evidence for every in-scope risk class you claim**, **no undisclosed stubbing on security-critical paths**, and **disciplined oracles** — not “every `entry` in Move has a Lean row tomorrow.”

#### (i) Scope contract

- **In:** which modules and which surfaces (`public` helpers, serializers, crypto primitives, `deserialize_*` edges, …) are claimed by **`move-lean-difftest` + Lean**.
- **Out:** what is **explicitly not** in this pipeline (typical examples: full economic abuse, gas, liveness, **proof soundness**, “Lean matches RFC” without a third reference).
- **Elsewhere:** what is covered only by **VM-only** or **e2e** (see **§7.0**) — still valuable, but **not** “VM↔Lean difftest” for those rows.

Until **in / out / elsewhere** is written (inventory + this doc), “complete” is undefined.

#### (ii) Equivalence-class coverage (not row count)

For every **in-scope** observable API, professionally acceptable coverage includes **representatives per class**, not only happy paths:

- **Lengths / layouts:** empty, sub-min, exact boundary, over-long; `Option` / abort outcomes recorded in the oracle where observable.
- **Encodings:** `to_bytes` / `from_bytes`, compress / decompress, wrong wire layouts.
- **Algebra (where claimed):** identities, inverses, relations that the math guarantees on stated domains; assignment vs functional forms when both exist.
- **Chunking:** parameterized or systematic coverage over chunk indices / amount patterns (not only a few hand-picked constants).
- **Cross-representation:** same semantic value built two supported ways (e.g. constructors that should agree on `balance_equals` / `balance_c_equals` / `is_zero`).

#### (iii) Cryptographic primitives

- **Vectors:** known-answer or **independent** gold vectors where feasible — not only self-consistency between VM and a second engine.
- **Invalid inputs:** wrong lengths, non-canonical encodings if the API distinguishes them.
- **Optional:** small **seeded-random** corpora VM↔Lean for hot paths (still finite; document seeds and scope).

#### (iv) `confidential_proof` — staged honesty

- **`deserialize_*`:** structure / length classes leading to `None` vs `Some`; if you claim deserialization correctness, add a **corpus of valid serialized proofs** from the real prover or harness (versioned bytes).
- **`verify_*`:** either **VM-only / e2e** with a large, versioned accept/reject corpus (**§7.0**), or **VM↔Lean** only when Lean actually runs the same verification semantics. **Undocumented `ldTrue` stubs on `verify_*` are smoke, not “complete verify difftest.”**

#### (v) `confidential_asset` transactional surface

Professional **product** confidence for the asset module usually requires a **scenario matrix** (register, deposit, withdraw, transfer, rotate, normalize, auditor variants, failure modes) with **observable oracles** (state, events, abort codes) — typically **e2e / integration** (**§7.0**, **§7.1**). The **`move-lean-difftest`** JSON column may cover only **globals-free slices** (**Option B**); that gap must stay **explicit** in [`difftest/inventory/confidential_assets.md`](difftest/inventory/confidential_assets.md).

#### (vi) Second-column (Lean) fidelity

Document, per row or per path, one of:

- **Bytecode + natives** intended to track production semantics, or  
- **Stub / trivial bytecode** that matches the VM **only on that oracle input** (must be obvious in `Programs/Confidential*.lean` + inventory).

Stakeholders should never have to guess which applies.

#### (vii) Process (non-negotiable)

- **Deterministic** oracle regeneration from pinned toolchain / features.  
- **CI** runs VM → JSON → Lean for all non-`skip_lean` rows relevant to CA.  
- **Inventory + changelog** when scope or stubs move.  
- **Triage rule** when VM and Lean disagree (which column is ground truth for regression).

---

### 4.4 Answering “Are we done with confidential-asset difftest coverage?”

Use **named tiers** so answers are not ambiguous:

| Tier | Meaning | Typical evidence |
|------|---------|------------------|
| **A — Pipeline complete (declared slice)** | Every **VM↔Lean** row in the maintained oracle(s) passes; every symbol the inventory marks as **VM↔Lean** for CA suites either has a representative case **or** an explicit **waived / blocked** note; no **undocumented** stubbing. | Green `lake exe difftest` on pinned JSON; [`confidential_assets.md`](difftest/inventory/confidential_assets.md) matches reality. |
| **B — Professionally strong** | **Tier A** plus **§4.3 (ii)–(vii)** to a degree the team signs off on (equivalence classes, vectors where promised, proof/entrypoint staging honest, Lean fidelity documented). | Reviewed coverage matrix + external vectors where claimed. |
| **C — Product-complete CA** | **Tier B** plus **transactional / full `verify_*`** evidence the product relies on — usually **§7.0 e2e** + optional export (**§7.1-B**), **not** `move-lean-difftest` alone unless Lean store + FA + proof natives exist. | E2e suite + optional merged oracle; documented Lean witness limits. |

**How to answer in one sentence**

- If only **Tier A** is satisfied: **“Difftest is green for the declared VM↔Lean oracle slice; CA as a whole is not ‘fully difftested’ unless Tier B/C criteria are separately claimed.”**  
- If **Tier B** is satisfied: **“CA difftest meets the professional bar we documented in §4.3–4.4.”**  
- **Never** say “fully difftested” for all of CA without stating **which tier** and pointing at **§7** for entrypoints / full verification.

**Assistant / reviewer default:** when the user asks **“Are we done?”**, respond with **current tier (A/B/C)** + **one concrete gap** from **§4.3** or the inventory (highest risk first).

**Important:** **Tier C is not a single deliverable** you can “finish” in one change set. Treat **§4.5** as the living checklist until the team signs off or explicitly narrows scope.

---

### 4.5 Traceability — “Full” (Tier C) vs this repository (living checklist)

Use this table to avoid arguing from slogans. **Update the Status column** when work lands.

| §4.3 / §4.4 requirement | Where it lives in-repo | Typical status (check in PRs) |
|-------------------------|--------------------------|--------------------------------|
| **Tier A:** VM↔Lean harness rows green | `lake exe difftest` on `difftest_oracle.json` (local) / merged in CI | **Track:** must stay green on every CA-touched PR. |
| **Tier A:** merged harness + e2e fragment green | [`.github/workflows/formal-difftest.yaml`](../../../.github/workflows/formal-difftest.yaml); [`difftest.sh`](difftest.sh) with `DIFTEST_MERGE_CA_E2E=1` | **Track:** CI runs merge + Lean on `difftest_ci_merged.json`. |
| **Tier C (VM):** transactional CA + real `verify_*` | [`e2e-move-tests/.../confidential_asset_e2e.rs`](../../e2e-move-tests/src/tests/confidential_asset_e2e.rs) | **Exists** — canonical **VM** depth. |
| **Tier C (oracle bridge):** e2e → JSON fragment | [`confidential_asset_e2e_oracle_impl.rs`](../../e2e-move-tests/src/tests/confidential_asset_e2e_oracle_impl.rs) `export_confidential_asset_e2e_oracle_fragment` | **Exists** — `CONFIDENTIAL_ASSET_E2E_ORACLE_OUT=…`. |
| **§4.3 (ii)** equivalence-class matrix written down | [`difftest/inventory/confidential_assets.md`](difftest/inventory/confidential_assets.md) §8–10 | **Ongoing** — extend as suites grow. |
| **§4.3 (iii)** independent / gold crypto vectors | [`difftest/corpora/confidential_assets/`](difftest/corpora/confidential_assets/) + **`cargo run -p move-lean-difftest -- verify-corpora`** (Rust; **`difftest.sh` \[0\]** / **`.github/workflows/formal-difftest.yaml`**) | **Partial** — registration FS + tagged SHA3 + BP DST + **fixed sigma wire layouts** (`deserialize_sigma_*.hex`, **1152 / 1216 / 1792 / 1920 / 2048 / 2176 / 2304 / 2432 / 2560 / 2688 / 2816 / 2944 / 3072 / 3200 / 3328 / 3456 / 3584 / 3712 / 3840 / 3968 / 4096 / 4224** B transfer extension classes) + **auditor serializer wires** (EK **32 / 64 / 96 / 128 / 160 / 192** B; pending amounts **256 / 512** B zero rows + **256** B VM-pinned **`u64(1)`** no-rand + **512** B actual-width zero + **512** B mixed two-pending wires in **both** vector orders: zero-then-**`u64(1)`** and **`u64(1)`**-then-zero + **768** B mixed **actual**-zero + **`u64(1)`**-pending in **both** orders) checked vs Rust verifier + Lean defs/theorems; extend with more Ristretto/BP/third-party vectors when claiming broader crypto alignment. |
| **§4.3 (iv)** valid serialized proof corpus for `deserialize_*` `Some` paths | harness + Lean bytecode + [`corpora/confidential_assets/deserialize_sigma_*.hex`](difftest/corpora/confidential_assets/) | **Partial** — harness rows **`test_deserialize_{withdrawal,normalization,rotation,transfer}_layout_ok_is_some`** exercise VM `Some` on canonical scalar **0** + fixed compressed point **A_POINT** at correct sigma lengths (+ empty ZKRP wrappers); **`test_deserialize_transfer_layout_extended_one_auditor_ok_is_some`** / **`…_two_auditors_ok_is_some`** / **`…_three_auditors_ok_is_some`** / **`…_four_auditors_ok_is_some`** / **`…_five_auditors_ok_is_some`** / **`…_six_auditors_ok_is_some`** / **`…_seven_auditors_ok_is_some`** / **`…_eight_auditors_ok_is_some`** / **`…_nine_auditors_ok_is_some`** / **`…_ten_auditors_ok_is_some`** / **`…_eleven_auditors_ok_is_some`** / **`…_twelve_auditors_ok_is_some`** / **`…_thirteen_auditors_ok_is_some`** / **`…_fourteen_auditors_ok_is_some`** / **`…_fifteen_auditors_ok_is_some`** / **`…_sixteen_auditors_ok_is_some`** / **`…_seventeen_auditors_ok_is_some`** / **`…_eighteen_auditors_ok_is_some`** / **`…_nineteen_auditors_ok_is_some`** cover **1920**- through **4224**-byte transfer sigmas (+ empty ZKRP); **hex** + **`verify-corpora`** + Lean **`deserializeSigma*Bytes`** / slice lemmas; Lean **110–113** use the same real **`Step`** as **128–130**; **132**/**134**/**136**/**138**/**140**/**142**/**144**/**146**/**148**/**150**/**152**/**154**/**156**/**158**/**160**/**162**/**164**/**166**/**168** match **131**/**133**/**135**/**137**/**139**/**141**/**143**/**145**/**147**/**149**/**151**/**153**/**155**/**157**/**159**/**161**/**163**/**165**/**167** (`ldConst` **27**/**28**/**29**/**30**/**31**/**32**/**33**/**34**/**35**/**36**/**37**/**38**/**39**/**40**/**41**/**42**/**43**/**44**/**45** + `vecLen` + `eq`). **`test_layout_sigma_*_byte_length_is_*`** at **128–131**, **133**, **135**, **137**, **139**, **141**, **143**, **145**, **147**, **149**, **151**, **153**, **155**, **157**, **159**, **161**, **163**, **165**, and **167**. Still **open** for full Lean `eval` replay of **`deserialize_*`** + cryptographic `verify_*` alignment. |
| **§4.3 (iv)** Lean runs real `verify_*` on proof blobs | `AptosFormal.Move.Native` + `Programs/Confidential` | **Open / formal-plan scale** — not implied by `lake exe difftest` today. |
| **§4.3 (v)** Lean replays FA + `borrow_global` + entrypoints | `Move.State` / store model | **Open** — see **§7.1-A/C** and formal verification plan. |
| **§4.3 (vi)** stub vs real bytecode documented per CA row | `Programs/Confidential.lean` + inventory + [`difftest/inventory/confidential_native_matrix.md`](difftest/inventory/confidential_native_matrix.md) | **Ongoing** — expand comments when adding indices; native matrix tracks **stdlib crypto** vs Lean. |
| **§4.3 (vii)** triage rule + oracle regen discipline | `difftest/ORACLE_CHANGELOG.md`, `difftest/README.md` | **Track** — keep current. |

**Bottom line for assistants:** **“Full difftests for confidential assets” (Tier C)** means **this table’s Tier-C rows + Tier B evidence** are satisfied **and** the team accepts **Lean witness limits** until the **Open** rows close. **Do not** claim Tier C solely from harness row count.

---

## 5. Architecture extensions (Rust + Lean + schema)

### 5.1 Rust (`move-lean-difftest`)

- New suite(s), e.g. `confidential` or `confidential_balance` / `confidential_proof` / … registered in [`difftest/src/suites/mod.rs`](difftest/src/suites/mod.rs) (pattern: [`vector.rs`](difftest/src/suites/vector.rs)).
- **Load** compiled packages that include `aptos_experimental` + dependencies (same style as existing suites: `InMemoryStorage`, publish, invoke).
- For each case: build **args**, run VM, serialize **results** (return values, abort code, optional **event** bytes if needed) into the oracle JSON.

### 5.2 JSON schema

- Extend [`schema.rs`](difftest/src/schema.rs) / Lean [`DiffTest/JsonParser.lean`](lean/AptosFormal/DiffTest/JsonParser.lean) if CA cases need richer payloads (large `vector<u8>`, multiple return values, structured errors).
- Version the schema if old oracles must keep working.

### 5.3 Lean (`lake exe difftest`)

- Extend [`DiffTest/Runner.lean`](lean/AptosFormal/DiffTest/Runner.lean) (or a sibling) to:
  - parse CA cases;
  - map case → **`ModuleEnv`** function index + **decoded `MoveValue` args**;
  - run `eval` / `evalProg` with sufficient **fuel**;
  - compare to oracle (same equality strategy as vector/BCS/hash).

### 5.4 `ModuleEnv` for CA

- Add a **`caModuleEnv`** (or extend `stdModuleEnv`) in new `Programs/Confidential*.lean` files: function table + **native dispatch** aligned with what CA bytecode calls.
- **No refinement files required** — only enough definitions for **evaluation** to complete or abort consistently.

---

## 6. Phased plan (difftest-only)

**Numbering:** The roadmap defines **Phases 0–5 only** (subsections below). **There is no Phase 6.** Later headings **§7–§9** are **other document sections** (evidence wording, optional VM-only note, maintenance) — they are **not** “Phase 7 / Phase 8 / Phase 9.” If your editor shows “Phase 5” followed by “7,” that jump is **section** numbering (6 = phased plan, 7 = evidence), not a missing delivery phase.

### 6.0 Honest scope — what “implemented” means here

The **calendar-style** subsections below (especially Phase **2–4** timelines) describe **breadth of coverage** that can take many weeks. What is **actually in the tree** today is narrower:

| Phase | In repo today | Still open (same phase number) |
|-------|----------------|--------------------------------|
| **1** | CA smoke in the harness + Lean + CI path | — |
| **2** | Many `confidential_balance` VM cases + Lean **stub** `ModuleEnv` matching VM on those oracle rows | Full bytecode transcription / evaluator paths for every hot native; every public helper in §4 inventories |
| **3** | Constants + empty `deserialize_*`; **registration FS golden `msg`** (161 B) VM↔Lean via `TranscriptAlignment`; deterministic Schnorr roundtrip VM-only in harness; SHA3-512 on BP DST VM↔Lean | **Friend-only** `verify_registration_proof` on **production** bytecode still lives in **e2e** (`§7.0`), not in `head.mrb` harness. **Lean:** no executable Ristretto verification in `eval` yet — `verify_*` on full proof blobs and **Bulletproof verify end-to-end in Lean** remain **formal-verification-track** scope ([`CONFIDENTIAL_ASSETS_FORMAL_VERIFICATION_PLAN.md`](CONFIDENTIAL_ASSETS_FORMAL_VERIFICATION_PLAN.md)), not `lake exe difftest`. |
| **4** | **Option B** layer smoke + **Option B+**: `global_resource_smoke` suite — real `borrow_global` on a published `has key` resource at `@std` in the **same** JSON oracle as other suites | **FA / fungible store / `confidential_asset::register` entrypoints** in VM↔Lean JSON: still **§7.0 e2e** + **merged fragment** (`skip_lean` rows). **Lean note:** `MachineState` + `GlobalResourceKey` exist; FA + CA globals in `eval` are not implemented. |
| **ElGamal** | Suite `confidential_elgamal`: VM oracles for **non–`test_only`** `public` APIs; Lean stubs indices 20–31 plus **`ciphertext_add_assign` / `ciphertext_sub_assign`** witnesses at indices **53–54** | Field access on `CompressedCiphertext` internals (no public getters); `#[test_only]` keygen / `new_ciphertext*` |
| **5** | `schema_version`, `ORACLE_CHANGELOG.md`, regen workflow via script + CI | Optional nightly fuzz; no automated “regen oracle on every CA API change” beyond developer/CI runs |

So: **infrastructure and a real differential slice are done**; **full Phase 2–4 depth from the tables is not.** Section **§4.2** checkboxes stay open until coverage catches up.

### Phase 0 — Inventory and case design (**complete**)

**Deliverables (done)**

- Hub methodology + suite registry: [`difftest/INVENTORY.md`](difftest/INVENTORY.md).
- Confidential assets + template tables: [`difftest/inventory/`](difftest/inventory/) (`confidential_assets.md`, `move_framework_template.md`).
- Rust harness: `--list-suites`, dynamic `--suite` help / errors from `all_suites()`; [`difftest.sh`](difftest.sh) supports `--list-suites` (skips Lean).
- **Discipline:** VM oracle is ground truth per run; mismatches are investigated — Move code is **not** assumed correct; oracles are not hand-edited to force Lean passes.

---

### Phase 1 — Harness + one end-to-end smoke case (2–6 weeks)

**Deliverables**

- [x] One Rust-generated oracle for **one** CA-invoking scenario (simplest: helper that only touches balance + crypto already partially modeled, or **pure** deserialization path).
- [x] Lean runner executes **that** case; `difftest.sh` forwards `--suite confidential` (meta id expanding to balance + proof + layer smoke).
- [x] CI job: generate oracle + run Lean — [`.github/workflows/formal-difftest.yaml`](../../../.github/workflows/formal-difftest.yaml) (path-filtered); default policy remains **generated** oracle (see [`difftest/README.md`](difftest/README.md)).

**Success criterion:** Green CI on that single case.

---

### Phase 2 — `confidential_balance` coverage (4–10 weeks)

**Deliverables**

- [x] Oracles for **public** helpers: zero balance, compress/decompress roundtrip, add (fixed inputs), serialization size checks, chunk constants, `Option` deserialization edge cases, etc.
- [x] Lean: **native stubs** in `AptosFormal.Move.Programs.Confidential` aligned with VM outputs on oracle inputs (not full bytecode transcription for every path — see inventory skip list).

**Success criterion:** Suite runs **N** cases; documented list of **skipped** functions and why — [`difftest/inventory/confidential_assets.md`](difftest/inventory/confidential_assets.md).

---

### Phase 3 — `confidential_proof` (8–20 weeks, parallel by verifier)

**Sub-tracks**

- [x] **Registration transcript (partial):** harness rows **`test_registration_fs_message_golden_move`** / **`test_registration_fs_message_golden_move_second`** return the **161-byte** FS `msg` for the two formal goldens; Lean uses **`TranscriptAlignment.expectedRegistrationFsMsgMoveGolden`** / **`expectedRegistrationFsMsg2`** (same bytes as [`formal_goldens_registration.move`](../aptos-experimental/tests/confidential_asset/formal_goldens_registration.move)). Framework-vs-helpers rows **170** / **173** VM-pin **`registration_fs_message_for_test`** on each scenario. This tightens **transcript** alignment; it is **not** a `verify_registration_proof` **curve** check in `eval`.
- [x] **Harness Schnorr roundtrip:** `difftest_registration_helpers::registration_roundtrip_vm` (VM). Lean column: **bool stub** until Ristretto/group operations are executable in `AptosFormal.Move` natives.
- [x] **Partial — production curve verify in harness JSON:** `verify_registration_proof_for_difftest` + deterministic prover on the **`registration_roundtrip_vm`** fixture (`test_registration_proof_framework_deterministic_verify_roundtrip`, Lean **171** = same `execVerifyRegistrationProof` column as **35**). Full **`register` → friend `verify_registration_proof`** on transactions remains **e2e** canonical (`§7.0`).
- [ ] **Transfer / withdraw / normalize / key rotation in harness+Lean:** same as above; **e2e merged oracle** records real `verify_*` on transactions (`skip_lean`).

**Native-heavy areas:** range proof / sigma / Bulletproofs — **VM↔Lean equality on full verify** would require Lean natives matching Aptos Bulletproofs + Ristretto batch interfaces; that is **orthogonal** to this difftest roadmap (treat as proof or reference-library work).

---

### Phase 4 — `confidential_asset` entrypoints (depends on Phase 2–3 + storage)

**Challenge:** Entrypoints touch **global storage** and **FA**; current `Move.*` model **omits globals** (see [`Move/README.md`](lean/AptosFormal/Move/README.md)).

**Options (pick explicitly):**

| Option | Difftest “entire codebase” meaning |
|--------|--------------------------------------|
| **A. Extend Lean state with a minimal store** | True VM↔Lean on entrypoints; **large** model work, still **no proofs**. |
| **B. Test only `fun` paths** that do not need globals | Partial “entire” — document gap. |
| **C. VM column only** for entrypoints; Lean for **internal** slices | Hybrid; not pure differential on entrypoints. |

**Chosen for this repo (current track): Option B** for `confidential_asset` **module paths**, plus **§7.1-B** for **full stack (FA + globals + `verify_*`)** evidence: the **merged** oracle [`difftest_ci_merged.json`](difftest/difftest_ci_merged.json) (CI) = `move-lean-difftest` harness + **e2e** [`OracleFragment`](../../e2e-move-tests/src/tests/confidential_asset_e2e_oracle_impl.rs) rows with **`skip_lean: false`**, so Lean runs the **witness** bytecode paths mapped in `Runner.lean` (not full FA + real `verify_*` replay in Lean). E2e success rows include **`bool` `true`** as a compact witness that the scenario’s VM checks passed.

**New harness suite:** `global_resource_smoke` — `borrow_global` on a resource published at `@std` via BCS from Rust (not FA).

The plan should **name the chosen option** in the README for this suite.

---

### Phase 5 — Regression and maintenance

**Deliverables**

- [x] Oracles regenerated on compiler / CA **API** changes; changelog entry when oracle format bumps — [`difftest/ORACLE_CHANGELOG.md`](difftest/ORACLE_CHANGELOG.md) + `schema_version` in JSON (`CURRENT_SCHEMA_VERSION` in Rust).
- [ ] Optional: nightly **fuzz**-generated cases (VM only first; add Lean when safe). *Not implemented in CI;* track as a separate harness if random/property cases are needed beyond `move-lean-difftest`’s fixed vectors.

---

## 7. Stretch scope — three requested tracks (dependency map + what already exists)

This section records **gaps for `move-lean-difftest` + Lean**, and **where the repo already runs the heavier VM story** (transactional CA + real proof verification on bytecode).

### 7.0 **Already in tree:** transactional VM, `register`, and full `verify_*` / `verify_registration_proof` paths

**Location:** [`aptos-move/e2e-move-tests/src/tests/confidential_asset_e2e.rs`](../../e2e-move-tests/src/tests/confidential_asset_e2e.rs)

**What it does (VM column only — not `lake exe difftest`):**

- Builds **`aptos-experimental`** with **`test_mode = true`** and injects **all `0x7`** modules (plus a **test-mode `0x1`** stdlib graph) into a **`MoveHarness`** so `#[test_only]` helpers such as **`prove_registration`** are available.
- Re-seeds **`FAController` / `init_module_for_testing`** so on-disk layout matches injected `confidential_asset` bytecode.
- Drives **real entry transactions**: **`register`** (which calls **`verify_registration_proof`** on the **friend** path), **`deposit`**, **`rollover`**, **`confidential_transfer`**, **`withdraw_to`**, **`rotate_encryption_key`**, freeze/auditor scenarios, etc., with **valid** proof payloads assembled in Rust / Move helpers inside that file.

**How to run (from repo root):**

```bash
# All tests whose names match the module filter (can be slow; some environments need a larger stack).
RUST_MIN_STACK=8388608 cargo test -p e2e-move-tests confidential_asset_e2e -- --test-threads=1
```

Example **single** scenario (register + deposit + rollover + gas profile hook):

```bash
RUST_MIN_STACK=8388608 cargo test -p e2e-move-tests tests::confidential_asset_e2e::confidential_asset_register_deposit_rollover_and_gas -- --exact --test-threads=1
```

**Relation to `move-lean-difftest`:** this is the **canonical** answer today for “**full VM** behavior including globals, FA, and **`confidential_proof::verify_*`** on real structs.” It does **not** produce the **JSON oracle** consumed by Lean; bridging **e2e → `difftest_oracle*.json`** (or extending Lean to replay harness state) remains future work (see **7.1-B** / **7.2**).

### 7.1 `confidential_asset` in **`move-lean-difftest`** (still Option B)

**Why `move-lean-difftest` alone is still limited:** `register`, `deposit_to`, … **`acquire`** store + FA; the harness uses **`InMemoryStorage` + `execute_loaded_function`**, not a full Aptos transaction. **`head.mrb`** omits **`#[test_only]`** symbols, so **`register_for_testing`** etc. are **not** in that compiler graph.

**Forks if you want VM↔Lean on entrypoints here:**

| Track | Idea | Lean column? |
|-------|------|----------------|
| **7.1-A** | Extend difftest session with **minimal global store + FA** (or share harness code with e2e) | After `AptosFormal.Move.State` matches |
| **7.1-B** | Emit **JSON** from **e2e** (or `aptos move test`) for VM-only rows, optional `lake exe` skip | VM-only until Lean store |
| **7.1-C** | **Option A** from Phase 4 (§6): full Lean container store + FA | Largest Lean surface |

**Suggested order:** treat **§7.0** as source of VM truth for entrypoints → add **7.1-B** export or **7.1-A** only if you need the **same JSON pipeline** as vector/BCS suites.

### 7.2 `confidential_proof` in **`move-lean-difftest`** vs **e2e**

**On real bytecode today:** **`verify_registration_proof`** runs inside **`confidential_asset::register`** in **§7.0** tests. **`verify_withdrawal_proof` / `verify_transfer_proof` / …** run on **`withdraw_to` / `confidential_transfer` / `rotate_*`** paths in the same file.

**On `move-lean-difftest` today:** only **release-visible** smoke (`deserialize_*` on empty, constants). Friend-only **`verify_registration_proof`** and **`prove_*`** are **not** in **`head.mrb`**.

**Lean:** still **no** faithful sigma + Bulletproofs over full proof blobs in `AptosFormal.Move.Programs.Confidential`; stubs only match the **narrow** oracle cases.

**Suggested order:** optional **JSON export** from e2e scenarios → **VM-only** rows in schema (§9) → long-term **Lean natives** or bytecode transcription (**7.3**).

### 7.3 “True” bytecode parity in Lean (whole CA modules, not stub `ModuleEnv`)

**What it means:** For each function under test, **disassembled** `MoveInstr` in Lean (or generated from the same compiler pipeline), **`Step`** coverage for **every** instruction, and **every** `native` on those paths bound in `AptosFormal.Move.Native` with semantics matching the VM — **then** `eval` against `realModuleEnv`-style tables instead of **`Programs/Confidential` stub `FuncDesc`**.

**Why it is large:** `confidential_proof.move` alone is thousands of lines with many natives (Ristretto, SHA3, Bulletproofs, …). This is **orthogonal** to “no refinement proofs” — you still need a **complete interpreter slice**.

**Suggested order:** automate **bytecode export** for one **`confidential_balance`** `public fun` already in the oracle → prove **`Step`** + natives for **that** function end-to-end → repeat module-by-module. CA-wide parity is a **program**, not one task.

---

## 8. Appendix — Evidence summary (for audits / leadership)

**You can honestly claim:**

- “On **{N}** automated cases, the **Lean bytecode evaluator** and the **Aptos Move VM** **agreed** on outputs for **{listed}** confidential-asset paths, revision **{git SHA}**, toolchain **{versions}**.”

**You should not claim:**

- “Confidential assets are **formally verified**.”  
- “**All** inputs behave correctly.”  
- “**Security** of the cryptographic protocol follows from difftest.”

**Optional one-liner:**  
Differential testing is **continuous alignment evidence** between two implementations; refinement proofs would be **mathematical obligation** — orthogonal.

---

## 9. Appendix — Optional: VM-only oracle suite (out of scope for “difftest” name)

If the team wants **fast** coverage **without** extending Lean:

- Maintain **JSON (or Move test) goldens** produced **only** by the VM.  
- That is **not** “Move ↔ Lean differential testing” in this repo’s sense; it is still valuable as **VM regression**.  
- Can be a **Phase 0** deliverable feeding later VM↔Lean cases (same inputs, once Lean is ready).

---

## 10. Appendix — Document maintenance

- Update **Phase** status and **option A/B/C** for `confidential_asset` when decided.  
- When CA difftest **scope or stubs** change, update **§4.3–4.4** if the **completion rubric** or **tier definitions** shift; keep [`difftest/inventory/confidential_assets.md`](difftest/inventory/confidential_assets.md) aligned so **“which tier are we?”** stays answerable from the repo.  
- Link this file from [`formal/README.md`](README.md) if you want discoverability.

---

## 11. Appendix — “Full stack in JSON / full verify in Lean”: what this repo does **not** promise

Requests sometimes bundle: **FA + globals + `borrow_global`**, **real `verify_*` on non-trivial proofs in the Lean column**, **full Bulletproof verification in Lean**, and **machine-checked refinement of `verify_registration_proof` inside `lake exe difftest`**.

| Ask | In-repo status |
|-----|----------------|
| FA + CA entrypoints + real proofs **in the VM oracle** | **Yes (VM column + merged oracle):** [`confidential_asset_e2e_oracle_impl.rs`](../../e2e-move-tests/src/tests/confidential_asset_e2e_oracle_impl.rs) scenarios + merge into `difftest_ci_merged.json`. Lean **compares** mapped rows (`skip_lean: false`) on **witness** programs, not the full transactional stack. |
| FA + the same in **Lean `eval`** | **No:** would require a large `AptosFormal.Move` store + FA + confidential bytecode + natives — see [`CONFIDENTIAL_ASSETS_FORMAL_VERIFICATION_PLAN.md`](CONFIDENTIAL_ASSETS_FORMAL_VERIFICATION_PLAN.md). |
| **Full Bulletproof verify in Lean** (matching VM bit-for-bit on proof blobs) | **No:** not implemented; difftest checks **SHA3-512** on the BP **DST string** and other **narrow** stubs only. |
| **Refinement proof** of registration inside the difftest runner | **No:** registration **math** lives under `AptosFormal.Experimental.ConfidentialAsset.Registration.*` (e.g. `SchnorrCompleteness`, `TranscriptAlignment`); `lake exe difftest` is **operational** alignment on oracle rows, not a proof obligation discharge. |
| **`borrow_global` in harness JSON** | **Yes (VM↔Lean):** suite `global_resource_smoke` (`difftest_global_smoke.move` + published `Counter`). |

**Local CI mirror:** `./aptos-move/framework/formal/difftest.sh` (harness + Lean); with `DIFTEST_MERGE_CA_E2E=1`, e2e export + merge + Lean on `difftest_ci_merged.json` (same as [`.github/workflows/formal-difftest.yaml`](../../../.github/workflows/formal-difftest.yaml)).
