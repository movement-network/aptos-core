# Research and Future Directions: Comprehensive Roadmap

**Version:** 1.0  
**Last Updated:** 2026-04-22  
**Audience:** Research engineers, academic collaborators, long-term technical planning  
**Purpose:** Chart the research horizon beyond current CA verification work  

## Executive Summary

This document maps the research frontier beyond the Confidential Assets (CA) unified verification plan. While `CONFIDENTIAL_ASSETS_UNIFIED_VERIFICATION_PLAN.md` tracks work-in-progress toward production deployment (Phases 0-8), this roadmap explores what comes AFTER — the multi-year research questions, fundamental limitations, and visionary improvements that could transform formal verification of cryptographic protocols.

**Scope:**
- **Near-term (6-12 months):** Incremental improvements to current CA verification infrastructure
- **Medium-term (1-3 years):** New verification capabilities, expanded protocol coverage, performance breakthroughs
- **Long-term (3-5+ years):** Fundamental research, new proof methodologies, ecosystem-wide impact

**Key themes:**
1. **Axiom elimination:** Reduce trust assumptions toward fully verified cryptography
2. **Proof automation:** AI-assisted proof generation, tactic synthesis, property inference
3. **Performance scaling:** Sub-second verification, incremental checking, parallelization
4. **Compositional verification:** Modular protocol specs, plug-and-play verified components
5. **Ecosystem impact:** Cross-chain verification, industry standards, open-source tooling

---

## Table of Contents

1. [Current State and Baseline](#current-state-and-baseline)
2. [Near-Term Research (6-12 Months)](#near-term-research-6-12-months)
3. [Medium-Term Research (1-3 Years)](#medium-term-research-1-3-years)
4. [Long-Term Research (3-5+ Years)](#long-term-research-3-5-years)
5. [Fundamental Research Questions](#fundamental-research-questions)
6. [Technology Enablers and Dependencies](#technology-enablers-and-dependencies)
7. [Collaboration Opportunities](#collaboration-opportunities)
8. [Success Metrics and Milestones](#success-metrics-and-milestones)
9. [Risk Assessment and Mitigation](#risk-assessment-and-mitigation)
10. [Resource Allocation Strategy](#resource-allocation-strategy)

---

## Current State and Baseline

**Where we are (2026-04-22):**
- 5 sigma protocols verified (Registration complete, 4 others in Phase 6)
- 3-stack verification (Lean + MSL + Difftest) operational
- 23 axioms (21 permanent crypto assumptions + 2 temporary)
- ~200 Lean theorems, 88 MSL spec blocks
- Build time: Lean ~4s, MSL ~1s per op, difftest ~1s
- Coverage: 95%+ bytecode, 100% entry points, 87 corpus rows

**What's proven:**
- Bytecode-level correctness of sigma verifiers (Lean)
- Source-level balance conservation, abort conditions (MSL)
- VM↔model consistency on concrete inputs (difftest)

**What's assumed (current axiom baseline):**
- Ristretto255 group laws (12 axioms)
- Ristretto compression/decompression (4 axioms)
- Bulletproofs soundness/completeness (5 axioms)
- Temporary: 2 axioms pending Phase 1/6 completion

**Limitations:**
- Manual proof effort: ~3 weeks per protocol (Phase 4 experience)
- No automatic property inference from code
- Crypto axioms remain external (no in-Lean proofs)
- Difftest covers examples, not ∀-guarantees
- No support for protocol composition beyond manual reasoning

This is the **BASELINE** for measuring research progress. All proposed work aims to improve on these dimensions.

---

## Near-Term Research (6-12 Months)

### R1: Axiom Elimination via Lean Crypto Libraries

**Goal:** Reduce axiom count from 23 to <15 by replacing crypto axioms with verified Lean implementations.

**Motivation:** Every axiom is a trust assumption. Ristretto255 group laws (12 axioms) are well-understood math — we should prove them, not assume them.

**Approach:**
1. **Phase 1: Ristretto255 field arithmetic** (3-4 months)
   - Formalize prime field 𝔽ₚ in Lean (p = 2²⁵⁵ - 19)
   - Prove field axioms (associativity, commutativity, distributivity, inverses)
   - Implement Barrett reduction, Montgomery multiplication
   - Benchmark: prove 1000 field operations in <1s

2. **Phase 2: Edwards curve group law** (4-6 months)
   - Formalize Edwards curve equation: -x² + y² = 1 + dx²y²
   - Prove group law (point addition, scalar multiplication)
   - Prove subgroup order, cofactor clearing
   - Benchmark: prove group closure in <5s

3. **Phase 3: Ristretto encoding** (2-3 months)
   - Formalize Ristretto quotient construction
   - Prove compression/decompression roundtrip
   - Eliminate 4 Ristretto compression axioms

**Challenges:**
- Arithmetic complexity: field operations are low-level bit manipulation
- Proof size: naive field arithmetic proofs can be 10K+ lines
- Performance: unconstrained proof search times out on large field operations

**Mitigation:**
- Use `norm_num` tactic for concrete field arithmetic
- Implement custom `field_simp` tactic for symbolic simplification
- Leverage Mathlib's existing field theory infrastructure

**Expected outcome:**
- Axiom count: 23 → 7 (eliminate all Ristretto axioms)
- New theorems: ~50 field/group lemmas
- Build time impact: +5-10s (acceptable)

**Related work:**
- Fiat Cryptography (MIT): verified field arithmetic, code generation
- EverCrypt (MSR/Inria): verified crypto primitives in F*
- Mathlib: finite field theory, elliptic curves (partial)

**Deliverables:**
- `lean/MovementFormal/Crypto/Ristretto255/Field.lean` (~2K lines)
- `lean/MovementFormal/Crypto/Ristretto255/EdwardsCurve.lean` (~3K lines)
- `lean/MovementFormal/Crypto/Ristretto255/RistrettoEncoding.lean` (~1K lines)
- Paper: "Verified Ristretto255 Implementation in Lean 4" (submission to ITP conference)

---

### R2: Proof Automation via Custom Tactics

**Goal:** Reduce manual proof effort from ~3 weeks to ~1 week per protocol via domain-specific automation.

**Motivation:** CA proofs have repetitive structure (PC chaining, step lemmas, case splits). Humans shouldn't write 200-line boilerplate — tactics should.

**Approach:**
1. **`pc_chain` tactic** (1-2 months)
   - Automatically chain `step` proofs for linear PC sequences
   - Input: bytecode range `[pc_start, pc_end]`, expected stack evolution
   - Output: proof that `run` executes that sequence correctly
   - Example:
     ```lean
     -- Before: 10 lines of manual chaining
     have h0 := step_ldu64 ...
     have h1 := step_stloc ...
     have h2 := step_immborrowloc ...
     ...
     
     -- After: 1 line with tactic
     pc_chain [0..10] {stack_diff := +2, locals_changed := [0, 3]}
     ```

2. **`oracle_case_split` tactic** (1 month)
   - Automatically case-split on native oracle results
   - Handles Schnorr verify, Bulletproofs verify, SHA-256, etc.
   - Generates success/failure branches with correct abort codes
   - Example:
     ```lean
     -- Before: 15 lines of manual case analysis
     cases hv : verify_schnorr_proof pk msg sig with
     | true => ...  -- 8 lines
     | false => ... -- 7 lines
     
     -- After: 1 line with tactic
     oracle_case_split verify_schnorr_proof [success_path, abort_65537]
     ```

3. **`functional_sim_equiv` tactic** (2-3 months)
   - Prove eval↔functional_sim equivalence automatically for simple protocols
   - Uses symbolic execution + SMT-style constraint solving
   - Limitation: works for straight-line code, not complex control flow
   - Target: automate Normalization proof (currently 14 PC manual proof)

**Challenges:**
- Tactic development requires metaprogramming expertise (Lean 4 macros, elaboration)
- Overfitting: tactics too specific to current protocols, don't generalize
- Debugging: when tactic fails, error messages are cryptic

**Mitigation:**
- Start with simple tactics (`pc_chain` for linear sequences only)
- Build incrementally: manual proof → pattern extraction → tactic implementation → validation
- Document tactic internals thoroughly for maintainability

**Expected outcome:**
- Proof effort: 3 weeks → 1 week per protocol (3x speedup)
- New tactics: 3 custom tactics + 10+ helper macros
- Lines of proof code: -40% (automation replaces boilerplate)

**Related work:**
- Sledgehammer (Isabelle): automatic proof search via external ATPs
- Hint databases (Coq): reusable proof hints
- Dafny: automatic invariant inference

**Deliverables:**
- `lean/MovementFormal/Tactics/PcChain.lean` (~500 lines)
- `lean/MovementFormal/Tactics/OracleCaseSplit.lean` (~300 lines)
- `lean/MovementFormal/Tactics/FunctionalSimEquiv.lean` (~1K lines)
- Tutorial: "Writing Custom Tactics for CA Proofs" (documentation)

---

### R3: Incremental Verification via Dependency Tracking

**Goal:** Reduce re-verification time from minutes to seconds by only re-checking changed proofs.

**Motivation:** During protocol development, changing 1 line of Move code triggers full rebuild (currently ~4s Lean + ~1s MSL). This slows iteration. Incremental checking should be <1s.

**Approach:**
1. **Lean-side dependency graph** (2 months)
   - Build dependency DAG: theorem → lemmas → definitions
   - Cache proof terms at module boundaries
   - On code change, invalidate only downstream theorems
   - Use Lean's `lake` build system for incremental compilation

2. **MSL-side selective verification** (1 month)
   - Track `spec` block dependencies (which specs use which helper functions)
   - Run Move Prover on changed specs only
   - Cache VC (verification condition) results per spec block
   - Parallel VC solving for independent specs

3. **Cross-stack invalidation** (1 month)
   - When Move source changes, invalidate: MSL specs + Lean bytecode proofs + difftest rows
   - When Lean model changes, invalidate: all Lean proofs using that model
   - When oracle spec changes, invalidate: all proofs + difftest rows using that oracle
   - Implement via `verify-ca.sh --incremental` mode

**Challenges:**
- Cache invalidation is hard (classic CS problem)
- False dependencies: over-invalidation wastes time, under-invalidation causes unsoundness
- Lake build system has limited incremental support (as of Lean 4.8)

**Mitigation:**
- Start with conservative invalidation (over-invalidate initially)
- Measure cache hit rate, refine over time
- Contribute improvements to Lake upstream if needed

**Expected outcome:**
- Incremental build: <1s for unchanged proofs
- Full build: ~4s (no regression)
- Developer iteration speed: 5-10x faster during protocol development

**Related work:**
- Coq's parallel proof checking (`-j` flag)
- Why3: modular VC generation
- Build systems: Bazel, Buck (hermetic incremental builds)

**Deliverables:**
- Enhanced `verify-ca.sh` with `--incremental` flag
- Dependency tracking module: `scripts/dependency_tracker.py`
- Benchmarking suite: measure cache hit rate, invalidation precision

---

### R4: Property-Based Testing for MSL Specs

**Goal:** Automatically generate test cases to validate MSL specs catch real bugs.

**Motivation:** MSL specs are only useful if they're CORRECT. A wrong spec that verifies proves nothing. Property-based testing (PBT) can catch spec bugs early.

**Approach:**
1. **QuickCheck-style generators** (1-2 months)
   - Generate random valid CA inputs: public keys, proofs, balances, amounts
   - Respect preconditions: amount ≤ balance, proof structure valid, etc.
   - Use Rust `proptest` or `quickcheck` crates

2. **Differential testing: Move VM vs MSL** (2 months)
   - Run Move VM on generated inputs
   - Check MSL `ensures` clauses against actual VM output
   - Report violations: "MSL says balance = X, but VM produced balance = Y"

3. **Mutation testing for MSL specs** (2-3 months)
   - Mutate MSL spec: change `ensures` to `ensures not`, swap `<` to `≤`, etc.
   - Run Move Prover on mutated spec
   - If prover still succeeds, the spec is too weak (missing constraints)
   - Report: "Removing this clause didn't break verification — it's redundant or too weak"

**Challenges:**
- Generator complexity: valid CA inputs require cryptographic structure (valid Schnorr proofs)
- Execution cost: running Move VM on 10K inputs takes time
- False positives: mutation testing can flag intentionally weak specs

**Mitigation:**
- Start with simple property tests (balance ≥ 0, array bounds)
- Use mocked oracles for faster execution
- Manual review of mutation testing results

**Expected outcome:**
- Catch 5-10 spec bugs before they reach production
- Higher confidence in MSL specs
- Automated spec quality checks in CI

**Related work:**
- QuickCheck (Haskell): original PBT framework
- Hypothesis (Python): modern PBT
- KLEE: symbolic execution for C programs

**Deliverables:**
- `aptos-experimental/tests/property_based_tests.rs` (~1K lines Rust)
- Mutation testing script: `scripts/mutate_msl_specs.py`
- CI integration: property tests run on every PR

---

## Medium-Term Research (1-3 Years)

### R5: Bulletproofs Verification in Lean

**Goal:** Eliminate the 5 Bulletproofs axioms by implementing and verifying the Bulletproofs protocol in Lean.

**Motivation:** Bulletproofs is a MAJOR trust assumption (5 of 23 axioms). If we can verify it, we eliminate ~22% of our axiom count and significantly strengthen the overall verification.

**Scope:**
This is a LARGE project — comparable in effort to the entire current CA verification. Bulletproofs is a complex cryptographic protocol with:
- Inner product arguments (recursive structure, log-depth)
- Fiat-Shamir transform (hash-to-scalar soundness)
- Range proof aggregation
- Batch verification optimizations

**Approach:**
1. **Phase 1: Mathematical foundations** (6 months)
   - Formalize inner product arguments in Lean
   - Prove soundness: prover can't cheat without solving discrete log
   - Prove completeness: honest prover always convinces verifier
   - Formalize Fiat-Shamir security reduction

2. **Phase 2: Range proof construction** (6 months)
   - Implement Bulletproofs range proof protocol
   - Prove: if verifier accepts, committed value is in range [0, 2ⁿ)
   - Handle edge cases: n = 8, 16, 32, 64 bits
   - Prove aggregation correctness (batch verification preserves soundness)

3. **Phase 3: Integration with CA** (3-4 months)
   - Replace `opaque verify_range_proof` axiom with verified implementation
   - Update difftest corpus: verify Lean implementation matches VM oracle
   - Performance tuning: ensure verified version doesn't slow proofs >10%

4. **Phase 4: Publication** (2-3 months)
   - Write paper: "Formal Verification of Bulletproofs in Lean 4"
   - Submit to top-tier venue: IEEE S&P, CCS, CRYPTO
   - Open-source: contribute to Lean crypto library ecosystem

**Challenges:**
- Cryptographic complexity: Bulletproofs uses advanced techniques (Pedersen commitments, inner product arguments, recursive composition)
- Proof size: naive implementation could be 20K+ lines of Lean
- Performance: complex crypto proofs can timeout (heartbeat limits)
- Maintenance: Bulletproofs spec may evolve (BP++, other optimizations)

**Mitigation:**
- Collaborate with cryptography researchers (academic partnership)
- Reuse existing Lean crypto libraries (Mathlib, EverCrypt port)
- Modular design: separate foundations (IP arguments) from application (range proofs)
- Set realistic timeline: this is a PhD-thesis-level project

**Expected outcome:**
- Axiom count: 23 → 18 (eliminate 5 Bulletproofs axioms)
- New theorems: ~100 cryptographic lemmas
- Build time: +15-30s (substantial but acceptable)
- Impact: first fully verified Bulletproofs implementation in any proof assistant

**Related work:**
- Jasmin/EasyCrypt: Bulletproofs implementation (not fully verified)
- CryptHOL (Isabelle): cryptographic game proofs
- FCF (Coq): foundational cryptography framework

**Resource estimate:**
- Effort: 1.5-2 person-years (senior cryptography + formal methods expert)
- External collaboration: cryptography professor + 1-2 PhD students
- Funding: research grant or academic partnership

**Risk assessment:**
- **High risk:** This is cutting-edge research. No one has done this before.
- **High reward:** If successful, establishes CA as most rigorously verified ZK protocol in production.
- **Fallback:** If full verification is infeasible, verify subcomponents (e.g., inner product argument only) and document remaining assumptions clearly.

---

### R6: AI-Assisted Proof Generation

**Goal:** Use large language models (LLMs) and machine learning to automatically generate Lean proofs from natural language specifications.

**Motivation:** Humans are slow at writing proofs (3 weeks per protocol). AI can explore proof search space faster. Even partial automation (suggest tactics, fill in easy steps) would accelerate verification.

**Approach:**
1. **Phase 1: Tactic suggestion** (4-6 months)
   - Train LLM on CA proof corpus: input = goal state, output = next tactic
   - Fine-tune on Lean 4 syntax (base model: GPT-4, Codex, CodeLlama)
   - Integrate with VS Code: suggest top-3 tactics at each proof step
   - Benchmark: >50% top-1 accuracy on CA test set

2. **Phase 2: Lemma synthesis** (6-9 months)
   - Given theorem statement, synthesize intermediate lemmas automatically
   - Use reinforcement learning: reward = proof closes, penalty = timeout
   - Example: given `theorem transfer_preserves_balance`, synthesize helper lemmas for each PC
   - Benchmark: close 30% of simple theorems with zero human intervention

3. **Phase 3: Property inference** (9-12 months)
   - Automatically infer properties from Move code
   - Input: Move function, Output: MSL spec candidate
   - Use symbolic execution + ML to propose `requires`, `ensures`, `aborts_if` clauses
   - Human reviews and refines suggestions
   - Benchmark: reduce spec writing time by 50%

**Challenges:**
- Hallucination: LLMs generate plausible-looking but unsound proofs
- Context window: Lean proof states can be 10K+ tokens (exceeds most LLM limits)
- Soundness: AI-generated proofs must still pass Lean kernel (no risk to correctness, but wasted effort if proof is wrong)
- Dependency: reliance on external AI models (API costs, rate limits, model deprecation)

**Mitigation:**
- Sandboxing: AI generates candidate proof, Lean kernel validates (soundness preserved)
- Iterative refinement: AI suggests, human edits, AI re-suggests
- Local models: fine-tune open models (Llama 3, Mistral) for on-premise deployment
- Fallback: if AI fails, human writes proof manually (no worse than today)

**Expected outcome:**
- Proof effort: 1 week → 3-4 days per protocol (30-40% reduction)
- Developer experience: faster iteration, less tedious boilerplate
- Novel insight: AI may discover non-obvious proof strategies

**Related work:**
- Copilot for Lean: GitHub Copilot suggestions in VS Code (exists, needs fine-tuning)
- Proof Artifact Co-training (PACT): train LLM on proof datasets
- AlphaProof (DeepMind): IMO problem solving via RL + proof search
- LeanDojo: benchmark for ML-guided theorem proving

**Resource estimate:**
- Effort: 6-12 months (ML engineer + Lean expert collaboration)
- Compute: GPU cluster for fine-tuning (or cloud TPU credits)
- Data: CA proof corpus (current ~10K lines, need 50K+ for good training)

**Ethical considerations:**
- Transparency: clearly mark AI-generated proofs
- Reproducibility: if model changes, can we still regenerate proofs?
- Intellectual property: who owns AI-generated proofs?

---

### R7: Compositional Protocol Verification Framework

**Goal:** Enable modular verification where protocols are composed from verified components, with automatic property composition.

**Motivation:** Future CA features (shielded pools, cross-chain transfers, private DEX) will compose multiple protocols. Re-verifying from scratch for each composition is wasteful. We need compositionality.

**Approach:**
1. **Phase 1: Protocol interfaces** (3-4 months)
   - Define formal interface for a "verified protocol component"
   - Interface includes: preconditions, postconditions, invariants, abort conditions, oracle dependencies
   - Example:
     ```lean
     structure ProtocolInterface where
       name : String
       preconditions : State → Prop
       postconditions : State → State → Prop
       invariants : State → Prop
       aborts_with : List Nat
       oracles_used : List OracleId
     ```

2. **Phase 2: Composition operators** (4-6 months)
   - Define composition primitives: sequential, parallel, conditional, recursive
   - Prove composition theorems: if A correct and B correct and compatible(A, B), then compose(A, B) correct
   - Example:
     ```lean
     theorem sequential_composition 
         (A B : ProtocolInterface)
         (h_A : correct A)
         (h_B : correct B)
         (h_compatible : A.postconditions ⊆ B.preconditions) :
         correct (A.then B)
     ```

3. **Phase 3: Library of verified components** (ongoing)
   - Package each CA protocol as a reusable component: Registration, Withdrawal, Transfer, etc.
   - Extend to new protocols: Shielded pool deposit, cross-chain proof relay, private swap
   - Build component catalog: searchable, well-documented, versioned

4. **Phase 4: Automatic composition checking** (6-9 months)
   - Tool: `verify-composition.sh --protocol A --protocol B --mode sequential`
   - Checks compatibility automatically
   - Generates combined proof obligations
   - Outputs: combined MSL spec, combined Lean theorem, difftest corpus rows

**Challenges:**
- Abstraction overhead: interfaces add complexity
- Compatibility checking: how to automatically verify `A.post ⊆ B.pre`?
- State management: composed protocols share global state (stores, accounts) — how to partition?

**Mitigation:**
- Start simple: sequential composition only (easiest case)
- Learn from: Iris (Concurrent Separation Logic), Verified Software Toolchain (CompCert)
- Incrementally add composition modes (parallel, conditional) as needed

**Expected outcome:**
- New protocol verification: 1 week → 2 days (if reusing 80% of components)
- Confidence in compositions: formal proof that properties carry through
- Ecosystem: library of 10-20 verified protocol components

**Related work:**
- Iris: modular verification of concurrent programs
- VST: compositional C verification
- Why3: modular specification and proof

---

### R8: Cross-Chain Verification Infrastructure

**Goal:** Extend CA verification to cross-chain contexts — prove properties of multi-chain protocols involving asset bridges, cross-chain proofs, and inter-chain communication.

**Motivation:** Blockchain ecosystems are multi-chain. Confidential assets may bridge to Ethereum, Solana, Cosmos, etc. Cross-chain protocols introduce new attack surfaces. We need verification that spans chains.

**Approach:**
1. **Phase 1: Multi-VM semantics** (6-8 months)
   - Formalize execution semantics of: Move VM, EVM, SVM (Solana VM)
   - Model cross-chain message passing (IBC, LayerZero, Wormhole)
   - Prove: if chain A sends message M, chain B receives M unchanged (no tampering)

2. **Phase 2: Bridge verification** (6-9 months)
   - Verify asset bridge contracts: lock on chain A, mint on chain B
   - Prove: total supply conserved across chains (lock amount = mint amount)
   - Prove: no double-spend (unlock on A only after burn on B)
   - Handle failure modes: what if bridge relayer is Byzantine?

3. **Phase 3: Cross-chain privacy** (9-12 months)
   - Verify: confidential asset on chain A can transfer to chain B without leaking balance
   - Prove: zero-knowledge proof from chain A validates correctly on chain B
   - Handle: different curves (Ristretto on Move, BN254 on Ethereum) — proof translation

**Challenges:**
- Multi-VM modeling: each VM has different semantics (stack-based vs register-based vs account-based)
- Asynchrony: cross-chain messages are asynchronous, nondeterministic ordering
- Byzantine faults: relayers, validators may be malicious
- Cryptographic mismatch: different chains use different curves, hash functions, proof systems

**Mitigation:**
- Collaborate with cross-chain protocol teams (LayerZero, Wormhole)
- Focus on specific bridge (e.g., Move ↔ Ethereum) before generalizing
- Use existing multi-chain verification work as foundation

**Expected outcome:**
- First verified cross-chain confidential asset protocol
- Proof: total supply conserved across chains
- Proof: privacy preserved across chains

**Related work:**
- IronBridge (cross-chain verification research)
- Wormhole v2 security audit (informal, but comprehensive)
- EF's multi-chain research

**Resource estimate:**
- Effort: 2-3 person-years
- Collaboration: bridge protocol teams, VM specification experts
- High risk: this is largely uncharted territory

---

## Long-Term Research (3-5+ Years)

### R9: Fully Automated End-to-End Verification

**Vision:** Write Move code, press a button, get a verified protocol — no manual proofs, no human intervention.

**Motivation:** Current verification requires 3 weeks per protocol (even with automation). Ideal: developer writes Move function, automated tools generate MSL specs + Lean proofs + difftest corpus, all without human input.

**Approach:**
This requires breakthroughs in multiple areas:

1. **Automatic specification inference** (1-2 years)
   - Infer MSL specs from Move code automatically
   - Use symbolic execution, abstract interpretation, invariant inference
   - Human reviews generated specs, but default is "accept"

2. **Automatic proof generation** (2-3 years)
   - Given Move code + inferred spec, generate Lean proof automatically
   - Use AI, SMT solvers, proof search, heuristic guidance
   - Target: 90% of simple protocols prove automatically

3. **Automatic test generation** (1-2 years)
   - Generate difftest corpus rows automatically
   - Cover all branches, edge cases, error paths
   - Use symbolic execution to enumerate reachable states

4. **Integration** (1 year)
   - Single command: `movement verify --auto <module>`
   - Output: verified or list of proof obligations that need human help
   - CI integration: auto-verify on every commit

**Challenges:**
- This is AGI-hard (general automatic theorem proving is undecidable)
- Will never reach 100% automation — some protocols require human insight
- Risk of false confidence: "it verified automatically" doesn't mean it's correct if spec is wrong

**Mitigation:**
- Target 90% automation, accept 10% manual
- Always human-review auto-generated specs
- Incremental deployment: start with simple protocols, gradually expand

**Expected outcome (if successful):**
- Verification time: 3 weeks → 1 day (20x speedup)
- Developer experience: verification becomes part of standard workflow, not special effort
- Ecosystem impact: formal verification becomes accessible to all Move developers, not just experts

**Related work:**
- Dafny: automatic invariant inference (limited success)
- Liquid Types: refinement types with SMT-backed inference
- SeNVe: neural-network-based verified deep learning

**Reality check:**
This is ASPIRATIONAL. Full automation may be impossible. But pursuing it will yield valuable partial automation techniques along the way.

---

### R10: Verified Cryptographic Compiler

**Goal:** Compile high-level cryptographic protocol descriptions to verified Move bytecode automatically.

**Vision:**
```
Input: Protocol description in high-level DSL
  "Sigma protocol for proof-of-knowledge of discrete log"
  
Output: 
  - Move bytecode implementing the protocol
  - MSL spec proving protocol properties
  - Lean proof that bytecode matches cryptographic definition
  - Difftest corpus
  
All generated automatically, all verified correct.
```

**Motivation:** Currently, humans write Move code, then verify it matches the protocol. Why not generate BOTH code and proof from a single source of truth?

**Approach:**
1. **Design DSL** (1-2 years)
   - Domain-specific language for sigma protocols, zero-knowledge proofs, cryptographic primitives
   - Example syntax:
     ```
     sigma_protocol ProofOfKnowledge {
       public: commitment G
       private: witness x
       relation: G = g^x
       
       prover:
         r ← random_scalar()
         a := g^r
         e := fiat_shamir(a)
         z := r + e*x
         return (a, z)
       
       verifier:
         e := fiat_shamir(a)
         check: g^z == a * G^e
     }
     ```

2. **Compiler to Move** (1-2 years)
   - Translate DSL to Move bytecode
   - Optimize: constant folding, dead code elimination, instruction scheduling
   - Prove: generated bytecode is correct by construction

3. **Compiler to Lean** (1-2 years)
   - Generate Lean proof automatically from DSL
   - Prove: bytecode matches high-level protocol semantics
   - Leverage proof-producing compilation (CompCert-style)

4. **Integration** (1 year)
   - Command: `crypto-compile protocol.sigma --output move,lean,msl`
   - Generates all verification artifacts
   - Integrated into Move build system

**Challenges:**
- DSL design: balance expressiveness (can express complex protocols) vs simplicity (easy to compile)
- Proof-producing compilation: generating proofs automatically is hard
- Optimization: generated code may be slower than hand-written

**Mitigation:**
- Start with narrow domain: sigma protocols only (later expand to Bulletproofs, SNARKs, etc.)
- Allow escape hatches: hand-written Move for performance-critical parts
- Iterative design: build DSL based on real protocol patterns

**Expected outcome:**
- Protocol implementation time: 3 weeks → 1 week (write DSL, compile, review)
- Correctness: verified by construction (no manual proof needed)
- Ecosystem: DSL becomes standard for cryptographic protocol development

**Related work:**
- EasyCrypt: cryptographic proof framework (closest analogue)
- Jasmin: low-level crypto compiler with verification
- CompCert: verified C compiler (proof-producing compilation)

**Resource estimate:**
- Effort: 4-5 person-years
- Expertise: PL researcher + cryptographer + Move expert
- High risk, high reward

---

### R11: Formal Verification as a Service (FVaaS)

**Vision:** Cloud platform where developers upload Move code, get verification results in minutes, pay per verification.

**Motivation:** Formal verification expertise is rare. Most Move developers can't verify their own code. FVaaS democratizes access: upload code, get verified, no PhD required.

**Approach:**
1. **Platform architecture** (1-2 years)
   - Web UI: upload Move module, select properties to verify (balance conservation, no overflow, etc.)
   - Backend: distributed verification cluster (Lean workers, Move Prover workers, difftest runners)
   - Queue system: prioritize paying customers, free tier for open-source projects
   - Result dashboard: show proof status, failed properties, suggested fixes

2. **Property templates** (1 year)
   - Pre-built verification templates: "verify this is a safe token contract", "verify no reentrancy", etc.
   - User selects template, platform generates specs automatically
   - Human reviews, platform verifies

3. **Proof repair** (1-2 years)
   - If verification fails, platform suggests fixes
   - Use AI to analyze counterexamples: "failed because balance can underflow on line 42 — add bounds check"
   - User applies fix, re-verifies

4. **Certification** (1 year)
   - Verified contracts get "Formally Verified" badge
   - Blockchain-anchored proof certificate (immutable, auditable)
   - Insurance: verified contracts eligible for hack insurance (partner with DeFi insurance protocols)

**Challenges:**
- Business model: how to price? Per-verification? Subscription? Freemium?
- Trust: users must trust the platform (can we do client-side verification?)
- Scalability: distributed proof checking is complex
- Legal: is the platform liable if a "verified" contract has a bug?

**Mitigation:**
- Open-source the verification tools (transparency)
- Clear disclaimers: verification covers stated properties only
- Hybrid model: critical verification on-premise, routine checks on cloud

**Expected outcome:**
- Accessibility: 100x more developers can access formal verification
- Quality: Moveco system has higher average code quality (verified contracts become the norm)
- Revenue: platform sustains verification research (self-funding)

**Related work:**
- Certora: commercial verification-as-a-service for Ethereum (exists, successful)
- OpenZeppelin: security audits (manual, not formal)
- GitHub Actions: CI/CD as a service (architecture model)

**Resource estimate:**
- Effort: 3-5 person-years
- Funding: VC-backed startup or grant-funded nonprofit
- Go-to-market: partner with Move Foundation, Aptos Labs, Movement Labs

---

### R12: Standardization and Ecosystem Impact

**Goal:** Establish formal verification standards for Move ecosystem, influence industry-wide best practices.

**Motivation:** CA verification techniques are valuable beyond CA. If we standardize and open-source, the entire Move ecosystem benefits — and formal verification becomes competitive advantage for Move vs Solidity/Rust.

**Approach:**
1. **Verification standard** (1-2 years)
   - Define: "what does it mean for a Move module to be formally verified?"
   - Specify: minimum properties (no overflow, no reentrancy, resource safety)
   - Publish: Move Improvement Proposal (MIP) or Aptos Improvement Proposal (AIP)
   - Adoption: get buy-in from Aptos Foundation, Movement Foundation, other Move chains

2. **Open-source tooling** (ongoing)
   - Release CA verification stack as open-source (already partially done)
   - Maintain community-friendly docs, tutorials, examples
   - Host workshops, conferences, hackathons (formal verification track)

3. **Certification program** (1-2 years)
   - Training: "Certified Formal Verification Engineer for Move" course
   - Exam: practical verification project + written test
   - Credential: blockchain-anchored certificate (NFT?)
   - Partnerships: universities, bootcamps, online education platforms

4. **Industry collaboration** (ongoing)
   - Co-author papers with academic researchers
   - Collaborate with other blockchain verification projects (Ethereum, Solana, Cosmos)
   - Contribute to formal methods conferences: ITP, CPP, CAV, FM

**Expected outcome:**
- Move becomes known as "the blockchain platform with formal verification"
- Talent pipeline: more engineers trained in formal methods
- Safety: fewer hacks, higher trust in Move DeFi ecosystem

**Related work:**
- ERC-20 standard (Ethereum): simple but widely adopted
- MISRA C (automotive): safety standard for embedded C code
- Common Criteria (security certification): government-recognized standard

**Resource estimate:**
- Effort: ongoing (community building, not time-bound project)
- Funding: grants, foundations, corporate sponsorships

---

## Fundamental Research Questions

Beyond specific projects, there are deep research questions that underpin this work:

**Q1: What is the right abstraction level for cryptographic verification?**
- **Tension:** Low-level (field arithmetic, assembly) is precise but slow. High-level (sigma protocols, abstract algebras) is fast but may miss bugs.
- **Open question:** Can we verify at multiple levels simultaneously and prove they agree?

**Q2: How do we verify probabilistic protocols in a deterministic proof assistant?**
- **Challenge:** ZK proofs are probabilistic (soundness error 2⁻ⁿ). Lean is deterministic.
- **Current approach:** Axiomatize probability theory, assume results.
- **Open question:** Can we verify probabilistic protocols without axioms? (Recent work in Isabelle/HOL on probability is promising.)

**Q3: What properties are verifiable in practice vs theory?**
- **Known:** Termination is undecidable in general.
- **Unknown:** Which crypto protocol properties are decidable? Can we characterize the boundary?

**Q4: Can AI ever replace human proof engineers?**
- **Current state:** AI can suggest tactics, fill in easy steps.
- **Open question:** Can AI do creative proofs (non-obvious lemmas, novel invariants)?
- **Philosophical:** If AI proves a theorem but humans can't understand the proof, is it knowledge?

**Q5: How do we verify verifiers?**
- **Regress:** We trust Lean kernel. But what verifies Lean kernel?
- **Answer:** Meta-verification (verify Lean in Isabelle, Isabelle in Coq, ...). But this regress must stop somewhere.
- **Open question:** What is the minimal trusted base we can achieve?

---

## Technology Enablers and Dependencies

Research progress depends on external technologies maturing:

**Lean 4 evolution:**
- **Current:** Lean 4.8 (as of 2026-04)
- **Needed:** Better IDE support (infoview performance), faster elaborator, incremental checking
- **Timeline:** Lean 4.10+ (2027?) should address these

**AI/ML models:**
- **Current:** GPT-4, Codex (proprietary), Llama 3 (open)
- **Needed:** Specialized models for formal verification (fine-tuned on proof datasets)
- **Timeline:** Within 1-2 years (active research area)

**SMT solvers:**
- **Current:** Z3 4.11, CVC5
- **Needed:** Better support for non-linear arithmetic, quantifiers, crypto primitives
- **Timeline:** Incremental improvements (no breakthrough expected)

**Hardware:**
- **Current:** Proof checking is single-threaded (Lean limitation)
- **Needed:** Parallel proof checking, GPU-accelerated SMT
- **Timeline:** 2-5 years (requires Lean runtime changes)

**Cross-chain standards:**
- **Current:** IBC, LayerZero (not formally specified)
- **Needed:** Formal specs of cross-chain protocols
- **Timeline:** Depends on industry adoption (uncertain)

---

## Collaboration Opportunities

This research is too large for one team. Collaboration is essential:

**Academic partnerships:**
- **Universities:** MIT, CMU, Berkeley, EPFL, Cambridge (formal methods groups)
- **Topics:** Bulletproofs verification, AI-assisted proving, cross-chain semantics
- **Structure:** Joint research projects, PhD internships, co-authored papers

**Industry partnerships:**
- **Blockchain:** Aptos Labs, Movement Labs, Mysten Labs (Sui), Solana Foundation
- **Topics:** Shared verification infrastructure, cross-chain protocols, standards
- **Structure:** Consortium, joint open-source projects

**Open-source community:**
- **Lean community:** Contribute tools back to Lean ecosystem
- **Move community:** Verification workshops, tutorials, documentation
- **Structure:** GitHub repos, Zulip chat, conferences

**Funding sources:**
- **Grants:** NSF, DARPA (formal methods programs), Ethereum Foundation, Web3 Foundation
- **Corporate:** Crypto companies sponsoring research
- **Endowments:** Academic chairs in formal verification

---

## Success Metrics and Milestones

How do we measure progress?

**Near-term metrics (6-12 months):**
- [ ] Axiom count: 23 → 18 (R1: Ristretto255 verified)
- [ ] Proof effort: 3 weeks → 1 week per protocol (R2: automation tactics)
- [ ] Build time: incremental <1s (R3: dependency tracking)
- [ ] Spec bugs caught: 5-10 via property-based testing (R4)

**Medium-term metrics (1-3 years):**
- [ ] Axiom count: 18 → 13 (R5: Bulletproofs verified)
- [ ] AI-assisted proof: 30% of simple theorems auto-proved (R6)
- [ ] Compositional verification: 3+ protocols composed and verified (R7)
- [ ] Cross-chain: 1 bridge verified (R8)

**Long-term metrics (3-5+ years):**
- [ ] Automatic verification: 90% of simple protocols verify without human intervention (R9)
- [ ] Verified compiler: DSL for sigma protocols compiles to verified Move (R10)
- [ ] FVaaS platform: 100+ external users (R11)
- [ ] Ecosystem: Move formal verification standard adopted by 3+ chains (R12)

**Academic impact:**
- [ ] 5+ peer-reviewed papers published
- [ ] 1 PhD thesis based on this work
- [ ] 3+ conference talks/invited presentations

**Ecosystem impact:**
- [ ] 1000+ developers trained in Move formal verification
- [ ] 50+ third-party verified Move modules (using our tools)
- [ ] 10+ academic research groups using our infrastructure

---

## Risk Assessment and Mitigation

**Technical risks:**
1. **Axiom elimination may be infeasible** (R1, R5)
   - Mitigation: Document assumptions clearly, pursue partial verification
2. **AI-assisted proving may plateau** (R6, R9)
   - Mitigation: Invest in multiple approaches (AI, SMT, heuristics), don't rely on one
3. **Verification may not scale** (performance limits)
   - Mitigation: Modular verification, incremental checking, parallel execution

**Resource risks:**
1. **Talent shortage** (few experts in both crypto and formal methods)
   - Mitigation: Training programs, partnerships with universities
2. **Funding uncertainty** (research grants are competitive)
   - Mitigation: Diversify funding sources, align with strategic partners
3. **Timeline slippage** (research is unpredictable)
   - Mitigation: Agile planning, deliver value incrementally, celebrate partial progress

**Ecosystem risks:**
1. **Low adoption** (developers don't use verification tools)
   - Mitigation: UX focus, tutorials, incentives (verified contracts get promoted)
2. **Competing standards** (fragmentation)
   - Mitigation: Early collaboration, open standards, interoperability
3. **Security theater** (formal verification becomes checkbox, not real rigor)
   - Mitigation: Education, transparency, avoid overselling ("verified" ≠ "bug-free")

---

## Resource Allocation Strategy

**How to prioritize:**

**Maximize impact:**
- Prioritize R1 (Ristretto255), R2 (automation), R4 (property testing) — high impact, medium effort
- Defer R10 (verified compiler), R11 (FVaaS) — high impact, but requires R1-R9 first

**Minimize risk:**
- Start with near-term projects (R1-R4) to build momentum
- Validate medium-term feasibility before committing to long-term (R9-R12)

**Leverage collaboration:**
- Partner on R5 (Bulletproofs) — too large for one team
- Open-source R7 (compositional framework) — community-driven development

**Resource allocation (hypothetical 5-year plan):**
| Year | Focus | Team Size | Budget |
|------|-------|-----------|--------|
| 1 | R1, R2, R3, R4 | 2-3 engineers | $500K |
| 2 | R5 (start), R6, R7 | 4-5 engineers | $800K |
| 3 | R5 (continue), R7, R8 | 5-6 engineers | $1M |
| 4 | R9, R10 (start) | 6-8 engineers | $1.5M |
| 5 | R10, R11, R12 | 8-10 engineers | $2M |

**Total 5-year budget:** ~$5.8M (salaries, compute, travel, publications)

**Reality check:** This is a research budget, not a product budget. Actual allocation depends on funding, priorities, external partnerships.

---

## Conclusion

Formal verification of cryptographic protocols is at the frontier of computer science. The CA verification effort is pushing boundaries — from manual proofs to automation, from isolated protocols to compositional frameworks, from expert-only tools to accessible platforms.

The roadmap outlined here is ambitious. Some projects (R1-R4) are achievable in the near term. Others (R9-R12) are multi-year moonshots. But even partial progress on these questions will advance the state of the art.

**Key takeaways:**
1. **Incremental progress:** Deliver value every 6-12 months, don't wait for perfection
2. **Collaborate:** This is too hard for one team — partnerships are essential
3. **Publish:** Share findings with the research community — formal verification benefits everyone
4. **Fail fast:** If an approach doesn't work, pivot quickly — research is iterative
5. **Measure:** Track metrics, celebrate milestones, learn from setbacks

The future of blockchain security is formal verification. This roadmap charts a path forward.

---

**Document metadata:**
- **Version:** 1.0
- **Author:** CA Verification Research Team
- **Maintained by:** See `CONTRIBUTING_TO_CA_VERIFICATION.md`
- **Feedback:** Research proposals, collaboration inquiries → open an issue or email research@movement.xyz
- **Last major update:** 2026-04-22

**Related documents:**
- `CONFIDENTIAL_ASSETS_UNIFIED_VERIFICATION_PLAN.md` — Current work (Phases 0-8)
- `FORMAL_METHODS_LEARNING_PATH_COMPLETE_GUIDE.md` — Training new contributors
- `AXIOM_INVENTORY.md` — Current trust assumptions
- `COMPLETION_ROADMAP.md` — Tactical roadmap to Phase 0-8 completion
