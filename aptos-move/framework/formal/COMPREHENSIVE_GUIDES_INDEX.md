# Comprehensive Guides Index

**Purpose:** Master index of all comprehensive verification guides for Confidential Assets formal verification.

**Audience:** All verification team members, auditors, newcomers.

**Scope:** Complete navigation guide to the verification documentation ecosystem.

**Last Updated:** 2026-04-22

---

## Quick Navigation

**New to formal verification?** Start with:
1. [FORMAL_VERIFICATION_THEORY_PRIMER.md](#formal-verification-theory-primer) - Learn the basics
2. [LEAN_TACTICS_COOKBOOK.md](#lean-tactics-cookbook) - Practical proof patterns
3. [AUDITOR_GUIDE.md](audit/AUDITOR_GUIDE.md) - External reviewer onboarding

**Working on proofs?** Use:
1. [BYTECODE_TRANSCRIPTION_WORKFLOW_GUIDE.md](#bytecode-transcription-workflow-guide) - Move bytecode → Lean
2. [LEAN_PROOF_TACTICS_REFERENCE.md](#lean-proof-tactics-reference) - Tactics reference
3. [NATIVE_FUNCTION_ORACLE_MODELING_GUIDE.md](#native-function-oracle-modeling-guide) - Oracle patterns

**Building infrastructure?** See:
1. [PROOF_AUTOMATION_FRAMEWORK_GUIDE.md](#proof-automation-framework-guide) - Custom tactics
2. [DIFFTEST_HARNESS_DEVELOPMENT_GUIDE.md](#difftest-harness-development-guide) - Testing framework
3. [CI_TROUBLESHOOTING_GUIDE.md](#ci-troubleshooting-guide) - CI/CD

**Coordinating verification?** Check:
1. [MSL_TO_LEAN_COORDINATION_GUIDE.md](#msl-to-lean-coordination-guide) - Cross-stack sync
2. [END_TO_END_COMPOSITION_VERIFICATION_GUIDE.md](#end-to-end-composition-verification-guide) - Claim composition
3. [VERIFICATION_METRICS_DASHBOARD_GUIDE.md](#verification-metrics-dashboard-guide) - Progress tracking

---

## Complete Guide Catalog

### Architecture and Planning

#### CONFIDENTIAL_ASSETS_UNIFIED_VERIFICATION_PLAN.md
**Status:** Master plan (living document)
**Size:** ~15,000 lines
**Purpose:** Complete Phase 0-8 verification roadmap
**Key Sections:**
- Progress tracker (Phase status)
- Tool assignment per operation
- Phasing and milestones
- Definition of "done"
**Audience:** Project leads, all team members
**Related:** All other guides implement parts of this plan

#### LEAN_ARCHITECTURE_DEEP_DIVE.md
**Status:** Complete (~42,000 chars)
**Purpose:** Technical deep dive into Lean 4 architecture patterns
**Key Sections:**
- Symbolic state design (O(N) vs O(N²))
- Step lemma library architecture
- @[irreducible] performance pattern
- Proof composition strategies
**Audience:** Lean verification engineers
**Prerequisites:** Basic Lean 4 knowledge
**Related:** BYTECODE_TRANSCRIPTION_WORKFLOW_GUIDE, PROOF_AUTOMATION_FRAMEWORK_GUIDE

#### MSL_SPECIFICATION_PATTERNS_GUIDE.md
**Status:** Complete (~44,000 chars)
**Purpose:** MSL patterns for CA verification
**Key Sections:**
- Crypto-opaque boundary pattern
- Balance preservation specs
- Frame condition patterns
- Abort condition specifications
**Audience:** MSL spec writers
**Prerequisites:** Move language knowledge
**Related:** MSL_TO_LEAN_COORDINATION_GUIDE

---

### Core Workflows

#### BYTECODE_TRANSCRIPTION_WORKFLOW_GUIDE.md
**Status:** Complete (~39,000 chars)
**Purpose:** Complete workflow from .mv bytecode to verified Lean state definitions
**Key Sections:**
- End-to-end transcription workflow (8 steps, 3-6 hours per operation)
- Bytecode analysis and instruction mapping
- Lean state construction patterns
- Quality checklist and common pitfalls
**Audience:** Verification engineers doing Lean proofs
**Prerequisites:** Basic Lean, Move bytecode format
**Related:** LEAN_TACTICS_COOKBOOK, LEAN_ARCHITECTURE_DEEP_DIVE
**Practical Value:** Step-by-step guide with complete Registration example

#### LEAN_TACTICS_COOKBOOK.md
**Status:** Complete (~39,000 chars)
**Purpose:** Practical recipes for common proof patterns
**Key Sections:**
- Basic recipes (equality, simplification, cases)
- Step lemma recipes (CopyLoc, StLoc, Call, Branch, etc.)
- PC-chaining recipes (linear, branching, multi-path)
- Oracle handling, arithmetic, debugging, performance
**Audience:** Anyone writing Lean proofs
**Prerequisites:** Completed "Theorem Proving in Lean 4"
**Related:** LEAN_PROOF_TACTICS_REFERENCE, PROOF_AUTOMATION_FRAMEWORK_GUIDE
**Practical Value:** Copy-paste recipes reduce proof time 8-10×

#### DEVELOPER_WORKFLOW_GUIDE.md
**Status:** Complete (~38,000 chars)
**Purpose:** Day-to-day development workflow with verification integrated
**Key Sections:**
- <10s iteration loop for active development
- Adding new CA operations (design → CI integration)
- Change impact analysis
- Local development setup
**Audience:** All developers working on CA
**Prerequisites:** None
**Related:** CI_TROUBLESHOOTING_GUIDE, VERIFICATION_MAINTENANCE_HANDBOOK
**Practical Value:** Fastest path from code change to verified

---

### Verification Techniques

#### NATIVE_FUNCTION_ORACLE_MODELING_GUIDE.md
**Status:** Complete (~40,000 chars)
**Purpose:** Complete methodology for modeling Move native functions as oracles
**Key Sections:**
- Oracle design principles (minimal interface, observable behavior)
- Pattern library (Boolean, value-returning, arithmetic, stateful, multi-step)
- Axiom formulation (soundness, completeness, error conditions)
- Difftest validation strategy, MSL coordination
**Audience:** Engineers working with native functions
**Prerequisites:** Understanding of native functions, basic Lean
**Related:** AXIOM_INVENTORY, TRUST_BOUNDARIES, DIFFTEST_HARNESS_DEVELOPMENT_GUIDE
**Practical Value:** 21 permanent oracles designed using these patterns

#### PROOF_AUTOMATION_FRAMEWORK_GUIDE.md
**Status:** Complete (~40,000 chars)
**Purpose:** Framework for automating repetitive proof patterns
**Key Sections:**
- Multi-level automation (built-in, library, custom, code generation)
- Custom tactic development (step_auto, pc_chain, oracle_cases)
- Proof search algorithms (heuristic, backtracking, SMT-guided)
- Code generation (generate state definitions, theorem skeletons from bytecode)
**Audience:** Infrastructure engineers, experienced Lean users
**Prerequisites:** Advanced Lean, metaprogramming knowledge
**Related:** LEAN_TACTICS_COOKBOOK, LEAN_ARCHITECTURE_DEEP_DIVE
**Practical Value:** Reduces proof LOC 8-100×, generates 80% of boilerplate

#### PHASE_6_PC_CHAINING_COMPLETE_GUIDE.md
**Status:** Complete (~27,000 chars)
**Purpose:** Systematic workflow for finishing Phase 6 PC-chaining composition proofs
**Key Sections:**
- Operation-specific guides (Normalization 4-6h, Withdrawal 5-7h, Rotation 5-7h, Transfer 9-12h)
- PC-chaining patterns and lemma usage
- Oracle case-splitting strategies
- Quality assurance checklist
**Audience:** Engineers completing Phase 6 proofs
**Prerequisites:** Completed Phase 1, step lemma library
**Related:** LEAN_TACTICS_COOKBOOK, BYTECODE_TRANSCRIPTION_WORKFLOW_GUIDE
**Practical Value:** 23-32 hour completion estimate for all 4 operations

---

### Cross-Stack Coordination

#### MSL_TO_LEAN_COORDINATION_GUIDE.md
**Status:** Complete (~40,000 chars)
**Purpose:** Coordination patterns for keeping MSL specs and Lean proofs synchronized
**Key Sections:**
- Consistency guarantees (abort codes, balance preservation, oracles)
- Update workflows (Move changes, spec changes, Lean refactoring)
- Cross-stack validation with automated checks
- Quarterly axiom review procedures
**Audience:** Verification leads, all verification engineers
**Prerequisites:** Familiarity with both MSL and Lean
**Related:** MSL_SPECIFICATION_PATTERNS_GUIDE, NATIVE_FUNCTION_ORACLE_MODELING_GUIDE
**Practical Value:** Prevents drift between stacks, catches inconsistencies automatically

#### END_TO_END_COMPOSITION_VERIFICATION_GUIDE.md
**Status:** Complete (~40,000 chars)
**Purpose:** Methodology for composing verification results into end-to-end claims
**Key Sections:**
- Three-layer composition model (per-stack → consistency → claims)
- Claim formulation (structure, taxonomy, assumptions)
- Proof composition patterns (vertical, horizontal, temporal, parallel)
- Gap analysis and audit package preparation
**Audience:** Verification leads, auditors, project managers
**Prerequisites:** Understanding of all three stacks
**Related:** CLAIMS.md, COMPOSITION_CLAIMS.md, AUDITOR_GUIDE
**Practical Value:** Framework for producing auditable end-to-end claims

#### DIFFTEST_HARNESS_DEVELOPMENT_GUIDE.md
**Status:** Complete (~40,000 chars)
**Purpose:** Complete framework for developing and maintaining difftest harness
**Key Sections:**
- Harness architecture (test runner, executors, comparator)
- Test development workflow (8-step process)
- Mock oracle implementation (simple but comprehensive)
- Coverage tracking (scenario, path, oracle, abort code levels)
**Audience:** Test engineers, verification engineers
**Prerequisites:** Rust, basic testing concepts
**Related:** COMPREHENSIVE_TESTING_STRATEGY_GUIDE, NATIVE_FUNCTION_ORACLE_MODELING_GUIDE
**Practical Value:** 97+ test scenarios, ≥95% coverage target

---

### Management and Operations

#### VERIFICATION_METRICS_DASHBOARD_GUIDE.md
**Status:** Complete (~42,000 chars)
**Purpose:** Complete metrics framework for tracking verification health
**Key Sections:**
- Core metrics (proof coverage, axiom count, build times, sorry count, test coverage)
- Dashboard designs (text terminal, web visualization, Slack integration)
- Trend analysis, alerts (green/yellow/red status)
- CI integration with quality gates
**Audience:** FV leads, project managers, engineering leadership
**Prerequisites:** None
**Related:** VERIFICATION_MAINTENANCE_HANDBOOK, CI_TROUBLESHOOTING_GUIDE
**Practical Value:** Makes verification progress visible, catches regressions

#### VERIFICATION_MAINTENANCE_HANDBOOK.md
**Status:** Complete (~48,000 chars)
**Purpose:** Complete maintenance guide for all three verification stacks
**Key Sections:**
- Move source change impact matrix
- Axiom management with quarterly review
- Emergency procedures (SEV-1 through SEV-4)
- Regression prevention workflows
**Audience:** All verification engineers, on-call engineers
**Prerequisites:** Familiarity with verification infrastructure
**Related:** CI_TROUBLESHOOTING_GUIDE, EMERGENCY_RESPONSE_PLAYBOOK
**Practical Value:** 5 hrs/week maintenance budget, systematic procedures

#### RELEASE_VERIFICATION_CHECKLIST.md
**Status:** Complete (~33,000 chars)
**Purpose:** Complete pre-release verification checklist
**Key Sections:**
- Must-have criteria (all stacks green, zero sorry, ≥95% difftest coverage)
- Verification freeze timeline (T-14 days)
- Reproducibility validation (fresh clone, Docker, multi-platform)
- Deployment and rollback plans
**Audience:** Release managers, QA leads, FV leads
**Prerequisites:** None
**Related:** SECURITY_AUDIT_PREPARATION_GUIDE, VERIFICATION_METRICS_DASHBOARD_GUIDE
**Practical Value:** Complete release checklist, prevents incomplete releases

---

### Troubleshooting and Debugging

#### CI_TROUBLESHOOTING_GUIDE.md
**Status:** Complete (~25,000 chars)
**Purpose:** Systematic diagnosis for all CI failure modes
**Key Sections:**
- Diagnosis flowchart (Lean failures, Move Prover failures, Difftest failures)
- Common error resolutions
- Debug mode instructions
- Performance regression detection
**Audience:** All developers, CI/CD maintainers
**Prerequisites:** Basic CI knowledge
**Related:** VERIFICATION_MAINTENANCE_HANDBOOK, DEVELOPER_WORKFLOW_GUIDE
**Practical Value:** Fastest path to diagnosing and fixing CI failures

#### EMERGENCY_RESPONSE_PLAYBOOK.md
**Status:** Complete (~27,000 chars)
**Purpose:** Incident response procedures for verification emergencies
**Key Sections:**
- Severity classification (SEV-1 immediate, SEV-2 1h, SEV-3 4h, SEV-4 8h)
- Security compromise procedures
- Post-incident review template
- Contact directory
**Audience:** On-call engineers, security team, FV leads
**Prerequisites:** None
**Related:** VERIFICATION_MAINTENANCE_HANDBOOK, CI_TROUBLESHOOTING_GUIDE
**Practical Value:** Clear response procedures, prevents panic decisions

---

### Testing and Quality

#### COMPREHENSIVE_TESTING_STRATEGY_GUIDE.md
**Status:** Complete (~35,000 chars)
**Purpose:** Multi-layer testing strategy across all three stacks
**Key Sections:**
- Test pyramid (Lean proofs → MSL VCs → Difftest → PBT → Integration → E2E)
- Coverage matrix (200+ theorems, 75+ VCs, 87→102 difftest, 160K+ PBT)
- Property-based testing framework design
- Test maintenance procedures
**Audience:** Test engineers, QA, verification engineers
**Prerequisites:** Testing fundamentals
**Related:** DIFFTEST_HARNESS_DEVELOPMENT_GUIDE, VERIFICATION_METRICS_DASHBOARD_GUIDE
**Practical Value:** Complete testing strategy, 160K+ automated tests target

---

### Audit and Compliance

#### SECURITY_AUDIT_PREPARATION_GUIDE.md
**Status:** Complete (~31,000 chars)
**Purpose:** Complete external audit preparation (4-6 weeks timeline)
**Key Sections:**
- Pre-audit checklist (verification health, documentation, reproducibility)
- Audit package assembly
- Auditor onboarding procedures
- Post-audit remediation workflow
**Audience:** Audit coordinators, FV leads, security team
**Prerequisites:** Verification complete
**Related:** AUDITOR_GUIDE, RELEASE_VERIFICATION_CHECKLIST, END_TO_END_COMPOSITION_VERIFICATION_GUIDE
**Practical Value:** 4-6 week timeline, complete audit package specification

#### AUDITOR_GUIDE.md
**Status:** Complete (~650 lines)
**Purpose:** External auditor onboarding and review workflow
**Key Sections:**
- 20-40 hour onboarding checklist
- Evidence review procedures
- Reproducibility validation
- Audit report template
**Audience:** External security auditors
**Prerequisites:** None (self-contained)
**Related:** SECURITY_AUDIT_PREPARATION_GUIDE, CLAIMS.md, TRUST_BOUNDARIES.md
**Practical Value:** Fastest path for external auditors to understand and verify

---

### Theory and Education

#### FORMAL_VERIFICATION_THEORY_PRIMER.md
**Status:** Complete (~40,000 chars)
**Purpose:** Educational introduction to formal verification
**Key Sections:**
- What is formal verification (definitions, examples)
- Three verification stacks explained (Lean, MSL, Difftest)
- Proof techniques, soundness vs completeness
- Learning path (0-2 months → 12+ months to expert)
**Audience:** Newcomers to formal verification
**Prerequisites:** Programming experience, basic logic
**Related:** LEAN_TACTICS_COOKBOOK, MSL_SPECIFICATION_PATTERNS_GUIDE
**Practical Value:** Onboarding document, reduces learning curve

---

## Documentation Statistics

**Total comprehensive guides:** 20+
**Total documentation:** ~930,000 characters (~465 pages)
**Coverage:**
- Architecture: 3 guides
- Workflows: 4 guides
- Techniques: 4 guides
- Coordination: 3 guides
- Management: 3 guides
- Testing: 2 guides
- Audit: 2 guides
- Theory: 1 guide

**Creation timeline:**
- Phase 7 initial guides: 10 guides (~280K chars)
- Extended session 1: 11 guides (~310K chars)
- Extended session 2: 9 guides (~340K chars)

**All guides:**
- Cross-reference each other
- Include concrete examples
- Provide troubleshooting sections
- Support unified verification plan

---

## Reading Paths

### Path 1: New Verification Engineer (0-3 months)

**Week 1-2: Foundations**
1. FORMAL_VERIFICATION_THEORY_PRIMER.md
2. CONFIDENTIAL_ASSETS_UNIFIED_VERIFICATION_PLAN.md (overview)
3. DEVELOPER_WORKFLOW_GUIDE.md

**Week 3-4: Lean Basics**
1. LEAN_ARCHITECTURE_DEEP_DIVE.md
2. LEAN_TACTICS_COOKBOOK.md
3. LEAN_PROOF_TACTICS_REFERENCE.md

**Week 5-8: Hands-On**
1. BYTECODE_TRANSCRIPTION_WORKFLOW_GUIDE.md
2. PHASE_6_PC_CHAINING_COMPLETE_GUIDE.md
3. Complete one Phase 6 proof (Normalization recommended)

**Week 9-12: Advanced**
1. NATIVE_FUNCTION_ORACLE_MODELING_GUIDE.md
2. PROOF_AUTOMATION_FRAMEWORK_GUIDE.md
3. MSL_TO_LEAN_COORDINATION_GUIDE.md

### Path 2: External Auditor (1-2 weeks)

**Day 1: Setup and Overview**
1. AUDITOR_GUIDE.md (complete)
2. CONFIDENTIAL_ASSETS_UNIFIED_VERIFICATION_PLAN.md (overview)
3. Run `./audit/verify-ca.sh`

**Day 2-3: Claims and Evidence**
1. CLAIMS.md (review all claims)
2. TRUST_BOUNDARIES.md (understand assumptions)
3. AXIOM_INVENTORY.md (review all axioms)

**Day 4-5: Deep Dive**
1. END_TO_END_COMPOSITION_VERIFICATION_GUIDE.md
2. Review one operation end-to-end (Transfer recommended)
3. Spot-check 5-10 theorems and VCs

**Day 6-7: Gap Analysis**
1. GAP_ANALYSIS.md (if exists)
2. Review difftest coverage
3. Assess crypto axioms

**Week 2: Reproducibility and Report**
1. Test Docker reproducibility
2. Run per-operation and per-claim verifications
3. Write audit report

### Path 3: Project Manager / Lead (ongoing)

**Weekly: Progress Tracking**
1. VERIFICATION_METRICS_DASHBOARD_GUIDE.md
2. Review weekly metrics report
3. Check CI status

**Monthly: Health Check**
1. VERIFICATION_MAINTENANCE_HANDBOOK.md
2. Review axiom count
3. Check regression frequency

**Quarterly: Strategic Review**
1. CONFIDENTIAL_ASSETS_UNIFIED_VERIFICATION_PLAN.md (progress tracker)
2. Review completion roadmap
3. Update resourcing plans

**Pre-Release: Certification**
1. RELEASE_VERIFICATION_CHECKLIST.md
2. Run full verification suite
3. Prepare audit package

---

## Guide Maintenance

**Update triggers:**

| Trigger | Guides to Update |
|---------|------------------|
| New operation added | BYTECODE_TRANSCRIPTION_WORKFLOW_GUIDE, DIFFTEST_HARNESS_DEVELOPMENT_GUIDE, CLAIMS.md |
| Axiom added/removed | AXIOM_INVENTORY.md, NATIVE_FUNCTION_ORACLE_MODELING_GUIDE, TRUST_BOUNDARIES.md |
| Phase complete | CONFIDENTIAL_ASSETS_UNIFIED_VERIFICATION_PLAN.md, progress tracker |
| Tool version update | All setup sections, DEVELOPER_WORKFLOW_GUIDE.md |
| New pattern discovered | Relevant pattern guide (Lean tactics, MSL specs, etc.) |
| CI pipeline changes | CI_TROUBLESHOOTING_GUIDE.md, DEVELOPER_WORKFLOW_GUIDE.md |

**Quarterly review checklist:**
- [ ] Check all guides for outdated content
- [ ] Update examples if code changed
- [ ] Fix broken cross-references
- [ ] Update statistics (axiom count, test count, etc.)
- [ ] Review and update reading paths
- [ ] Solicit feedback from users

**Guide ownership:**

| Guide Category | Primary Owner | Backup Owner |
|----------------|---------------|--------------|
| Architecture | FV Lead | Senior Lean Engineer |
| Workflows | All Engineers | Tech Lead |
| Techniques | Subject Matter Experts | FV Lead |
| Coordination | FV Lead | MSL Lead |
| Management | Project Manager | FV Lead |
| Testing | QA Lead | Test Engineer |
| Audit | Security Lead | FV Lead |
| Theory | FV Lead | Senior Engineer |

---

## Contributing

**To add a new comprehensive guide:**

1. **Identify need:** Is there a topic not covered by existing guides?
2. **Check for overlap:** Would this be better as a section in an existing guide?
3. **Create outline:** Follow standard structure (Introduction, Key Sections, Examples, Troubleshooting)
4. **Write guide:** ~30-50K characters, concrete examples, cross-references
5. **Review:** FV Lead + subject matter expert review
6. **Integrate:** Add to this index, update cross-references in related guides
7. **Announce:** Share with team, add to onboarding materials

**Guide quality standards:**
- Concrete examples (not just abstract descriptions)
- Troubleshooting section (common pitfalls and solutions)
- Cross-references to related guides
- Audience and prerequisites clearly stated
- Practical value demonstrated
- Reproducible commands/code snippets

---

## Questions and Feedback

**For questions about guides:**
- Lean guides: Ask in #lean-verification channel
- MSL guides: Ask in #msl-verification channel
- General: Ask FV Lead

**To report issues:**
- Outdated content: File issue with "docs" label
- Unclear sections: File issue with "docs-clarity" label
- Missing content: File issue with "docs-enhancement" label

**To suggest improvements:**
- Open discussion in #formal-verification
- Propose specific changes via PR
- Share feedback in quarterly review

---

**Last Updated:** 2026-04-22
**Maintained By:** Formal Verification Team
**Next Review:** 2026-07-22
