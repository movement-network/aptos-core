#!/usr/bin/env bash
# generate_test_template.sh
# Generates test case templates for Lean proofs, MSL specs, and difftest cases
# Usage:
#   ./generate_test_template.sh --type lean --operation transfer
#   ./generate_test_template.sh --type msl --operation withdraw
#   ./generate_test_template.sh --type difftest --operation normalize
#   ./generate_test_template.sh --type all --operation rotation

set -euo pipefail

# ===========================
# Configuration
# ===========================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FORMAL_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
LEAN_DIR="$FORMAL_DIR/lean"
SPEC_DIR="$(cd "$FORMAL_DIR/../../aptos-experimental/sources/confidential_asset" && pwd)"
DIFFTEST_DIR="$(cd "$FORMAL_DIR/../../../move-lean-difftest" && pwd)"

# Default values
TYPE=""
OPERATION=""
OUTPUT_DIR=""
FORCE=false
VERBOSE=false

# ===========================
# Color output
# ===========================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

info() { echo -e "${BLUE}[INFO]${NC} $*"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }

# ===========================
# Usage
# ===========================

usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Generate test case templates for CA formal verification.

OPTIONS:
    -t, --type TYPE          Template type: lean, msl, difftest, or all
    -o, --operation OP       Operation name: transfer, withdraw, normalize, rotation, register
    -d, --output-dir DIR     Output directory (default: auto-detect based on type)
    -f, --force              Overwrite existing files
    -v, --verbose            Verbose output
    -h, --help               Show this help message

EXAMPLES:
    # Generate Lean EvalEquiv template for transfer
    $(basename "$0") --type lean --operation transfer

    # Generate MSL spec template for withdraw
    $(basename "$0") --type msl --operation withdraw

    # Generate difftest corpus template for normalize
    $(basename "$0") --type difftest --operation normalize

    # Generate all templates for rotation
    $(basename "$0") --type all --operation rotation

TEMPLATE TYPES:
    lean       Generate Lean EvalEquiv.lean template with:
               - Symbolic state definition
               - Per-PC step theorems
               - Top-level eval_equiv theorem
               - Proper imports and architecture

    msl        Generate MSL spec template with:
               - Function preconditions/postconditions
               - Abort conditions
               - Balance conservation patterns
               - Frame conditions

    difftest   Generate difftest corpus template with:
               - Happy path test cases
               - Error path test cases
               - Edge cases (boundary values, etc)
               - Corpus metadata

    all        Generate all of the above

OPERATIONS:
    register       Registration operation (crypto verification)
    transfer       Confidential transfer (crypto verification + balance)
    withdraw       Withdrawal (crypto verification + FA interaction)
    normalize      Balance normalization (crypto verification)
    rotation       Key rotation (crypto verification + state update)
EOF
}

# ===========================
# Argument parsing
# ===========================

while [[ $# -gt 0 ]]; do
    case $1 in
        -t|--type)
            TYPE="$2"
            shift 2
            ;;
        -o|--operation)
            OPERATION="$2"
            shift 2
            ;;
        -d|--output-dir)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        -f|--force)
            FORCE=true
            shift
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            error "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

# Validate required arguments
if [[ -z "$TYPE" ]]; then
    error "Missing required argument: --type"
    usage
    exit 1
fi

if [[ -z "$OPERATION" ]]; then
    error "Missing required argument: --operation"
    usage
    exit 1
fi

# Validate type
case "$TYPE" in
    lean|msl|difftest|all)
        ;;
    *)
        error "Invalid type: $TYPE (must be lean, msl, difftest, or all)"
        exit 1
        ;;
esac

# Validate operation
case "$OPERATION" in
    register|transfer|withdraw|normalize|rotation)
        ;;
    *)
        error "Invalid operation: $OPERATION (must be register, transfer, withdraw, normalize, or rotation)"
        exit 1
        ;;
esac

# ===========================
# Helper functions
# ===========================

# Capitalize first letter
capitalize() {
    echo "${1^}"
}

# Convert operation name to various formats
op_to_lean_module() {
    case "$1" in
        register) echo "Registration" ;;
        transfer) echo "Transfer" ;;
        withdraw) echo "Withdrawal" ;;
        normalize) echo "Normalization" ;;
        rotation) echo "Rotation" ;;
    esac
}

op_to_move_function() {
    case "$1" in
        register) echo "register_internal" ;;
        transfer) echo "confidential_transfer_internal" ;;
        withdraw) echo "withdraw_to_internal" ;;
        normalize) echo "normalize_internal" ;;
        rotation) echo "rotate_encryption_key_internal" ;;
    esac
}

op_to_verifier_function() {
    case "$1" in
        register) echo "verify_registration_proof" ;;
        transfer) echo "verify_transfer_proof" ;;
        withdraw) echo "verify_withdrawal_proof" ;;
        normalize) echo "verify_normalization_proof" ;;
        rotation) echo "verify_rotation_proof" ;;
    esac
}

# ===========================
# Lean template generation
# ===========================

generate_lean_template() {
    local operation="$1"
    local module_name
    module_name=$(op_to_lean_module "$operation")
    local verifier_func
    verifier_func=$(op_to_verifier_function "$operation")

    local output_file
    if [[ -n "$OUTPUT_DIR" ]]; then
        output_file="$OUTPUT_DIR/EvalEquiv.lean"
    else
        output_file="$LEAN_DIR/MovementFormal/Experimental/ConfidentialAsset/${module_name}/EvalEquiv.lean"
    fi

    local output_dir
    output_dir=$(dirname "$output_file")

    if [[ -f "$output_file" ]] && [[ "$FORCE" != true ]]; then
        warn "File already exists: $output_file (use --force to overwrite)"
        return 1
    fi

    mkdir -p "$output_dir"

    info "Generating Lean EvalEquiv template for $operation..."

    cat > "$output_file" <<'LEAN_TEMPLATE'
/-
# EvalEquiv for {{OPERATION_NAME}}

Bytecode-level proof that `{{VERIFIER_FUNCTION}}` is semantically equivalent
to the functional simulation (oracle-based evaluation).

## Architecture

This proof follows the Phase 4 architecture validated in Registration:

- **Symbolic state**: `@[irreducible]` state constructor, not chained frames
- **Step lemmas**: Reuse per-instruction-class lemmas from `StepLemmas.*`
- **Array.get?**: Avoid bound proofs in theorem statements
- **Target build time**: ≤ 0.7s (matching Transfer, the most complex dispatcher)

## Structure

1. **Symbolic state definition** (`{{MODULE_NAME}}State`)
2. **Per-PC step theorems** (`step_pc0`, `step_pc1`, ...)
3. **Error path theorems** (`step_verify_failed`, `step_malformed_proof`)
4. **Top-level theorem** (`eval_{{operation}}_eq_run`)

## Dependencies

- `MovementFormal.MoveModel.StepLemmas.*` - per-instruction-class step library
- `MovementFormal.MoveModel.Native.{{MODULE_NAME}}` - oracle definitions
- `MovementFormal.Experimental.ConfidentialAsset.{{MODULE_NAME}}.FunctionalSim` - functional spec

-/

import MovementFormal.MoveModel.StepLemmas.Basic
import MovementFormal.MoveModel.StepLemmas.Locals
import MovementFormal.MoveModel.StepLemmas.Structs
import MovementFormal.MoveModel.StepLemmas.Calls
import MovementFormal.MoveModel.StepLemmas.Run
import MovementFormal.MoveModel.Native.{{MODULE_NAME}}
import MovementFormal.Experimental.ConfidentialAsset.{{MODULE_NAME}}.FunctionalSim
import MovementFormal.Experimental.ConfidentialAsset.ModuleEnvironment

namespace MovementFormal.Experimental.ConfidentialAsset.{{MODULE_NAME}}

open MoveModel
open StepLemmas

-- ===========================
-- Symbolic State Definition
-- ===========================

/--
Symbolic state for `{{VERIFIER_FUNCTION}}` dispatcher.

Fields represent the abstract values at each program point:
- `pc`: Current program counter
- `proof_ref`: Reference to the proof argument
- `public_inputs_ref`: Reference to public inputs
- ... (add operation-specific fields)

Using `@[irreducible]` prevents whnf from unfolding the full chain.
-/
@[irreducible]
def {{MODULE_NAME}}State
    (pc : Nat)
    (proof_ref : RefValue)
    (public_inputs_ref : RefValue)
    -- Add operation-specific locals here
    (locals : Locals)
    (stack : Stack)
    : CallFrame :=
  { initialCallFrame with
    pc := pc
    locals := locals
    stack := stack
  }

-- Projection lemmas (simp-normal forms for field access)

@[simp]
theorem {{MODULE_NAME}}State_pc (pc : Nat) (proof_ref public_inputs_ref : RefValue) (locals : Locals) (stack : Stack) :
    ({{MODULE_NAME}}State pc proof_ref public_inputs_ref locals stack).pc = pc := by
  simp [{{MODULE_NAME}}State]

@[simp]
theorem {{MODULE_NAME}}State_locals (pc : Nat) (proof_ref public_inputs_ref : RefValue) (locals : Locals) (stack : Stack) :
    ({{MODULE_NAME}}State pc proof_ref public_inputs_ref locals stack).locals = locals := by
  simp [{{MODULE_NAME}}State]

@[simp]
theorem {{MODULE_NAME}}State_stack (pc : Nat) (proof_ref public_inputs_ref : RefValue) (locals : Locals) (stack : Stack) :
    ({{MODULE_NAME}}State pc proof_ref public_inputs_ref locals stack).stack = stack := by
  simp [{{MODULE_NAME}}State]

-- ===========================
-- Per-PC Step Theorems
-- ===========================

section PerPCSteps

-- Named implicits for environment, frame, call stack, memory store
variable {env : ModuleEnvironment}
variable {frame : CallFrame}
variable {cs : CallStack}
variable {ms : MemoryStore}

-- TODO: Add named implicits for operation-specific values
-- variable {proof : ProofBytes}
-- variable {public_inputs : PublicInputs}

/--
PC 0: Entry point - load proof reference.
Instruction: ImmBorrowLoc 0
-/
theorem step_pc0 :
    step env ({{MODULE_NAME}}State 0 proof_ref public_inputs_ref locals []) cs ms =
    StepResult.continue
      ({{MODULE_NAME}}State 1 proof_ref public_inputs_ref locals [.ref proof_ref])
      cs ms := by
  simp only [step, {{MODULE_NAME}}State]
  -- Apply step lemma for ImmBorrowLoc
  rw [step_immBorrowLoc_frame]
  -- Complete with rfl or simp
  rfl

/--
PC 1: Load public inputs reference.
Instruction: ImmBorrowLoc 1
-/
theorem step_pc1 :
    step env ({{MODULE_NAME}}State 1 proof_ref public_inputs_ref locals [.ref proof_ref]) cs ms =
    StepResult.continue
      ({{MODULE_NAME}}State 2 proof_ref public_inputs_ref locals [.ref public_inputs_ref, .ref proof_ref])
      cs ms := by
  simp only [step, {{MODULE_NAME}}State]
  rw [step_immBorrowLoc_frame]
  rfl

-- TODO: Add remaining per-PC step theorems (step_pc2, step_pc3, ...)
-- Follow the pattern:
-- 1. State the theorem with precise before/after states
-- 2. Simplify using `simp only [step, {{MODULE_NAME}}State]`
-- 3. Apply appropriate step lemma from StepLemmas.*
-- 4. Close with rfl or simp

-- Example for a call instruction (PC N: Call to verify_*_proof_internal):
/-
theorem step_pcN_call :
    step env ({{MODULE_NAME}}State N ...) cs ms =
    StepResult.continue
      ({{MODULE_NAME}}State (N+1) ... [oracle_result])
      cs ms := by
  simp only [step, {{MODULE_NAME}}State]
  rw [step_call_frame]
  -- Oracle evaluation
  simp [{{verifier_func}}_oracle]
  rfl
-/

end PerPCSteps

-- ===========================
-- Error Path Theorems
-- ===========================

section ErrorPaths

variable {env : ModuleEnvironment}
variable {cs : CallStack}
variable {ms : MemoryStore}

/--
Error path: Verification failed (oracle returns false).
Abort code: 65537 (ESIGMA_PROTOCOL_VERIFY_FAILED)
-/
theorem step_verify_failed :
    -- TODO: State the error condition
    -- Typically: oracle returns `.some false` or `.none` for malformed input
    True := by
  sorry

/--
Error path: Malformed proof structure.
Abort code: 65538 (or operation-specific error code)
-/
theorem step_malformed_proof :
    -- TODO: State the malformed input condition
    True := by
  sorry

end ErrorPaths

-- ===========================
-- Top-Level Theorem
-- ===========================

/--
Main theorem: `{{VERIFIER_FUNCTION}}` bytecode evaluation is equivalent to
the functional simulation.

This theorem:
1. Unfolds `eval_{{operation}}` to `run` with the entry PC
2. Chains through all PC steps (step_pc0, step_pc1, ...)
3. Handles error paths (verify_failed, malformed_proof)
4. Proves equivalence to the oracle-based functional sim

**Target build time:** ≤ 0.7s (within Phase 4 budget)
-/
theorem eval_{{operation}}_eq_run
    (env : ModuleEnvironment)
    (proof : ProofBytes)
    (public_inputs : PublicInputs)
    (cs : CallStack)
    (ms : MemoryStore)
    : eval_{{operation}} env proof public_inputs cs ms =
      run env ({{MODULE_NAME}}State 0 proof_ref public_inputs_ref initial_locals []) cs ms := by
  -- TODO: Complete the proof
  -- Structure:
  -- 1. Unfold eval_{{operation}} definition
  -- 2. Apply step_pc0, step_pc1, ... in sequence
  -- 3. Handle oracle call with step_pcN_call
  -- 4. Match functional sim result
  -- 5. Case split on oracle outcome (success vs error paths)
  sorry

-- ===========================
-- Functional Sim Reduction
-- ===========================

/--
Reduction lemma: functional sim result shape for success case.
-/
theorem {{operation}}_functional_sim_success
    (proof : ProofBytes)
    (public_inputs : PublicInputs)
    (h_verify : {{verifier_func}}_oracle proof public_inputs = .some true)
    : {{operation}}_functional_sim proof public_inputs = .returned [] .empty := by
  sorry

/--
Reduction lemma: functional sim result shape for verification failure.
-/
theorem {{operation}}_functional_sim_verify_failed
    (proof : ProofBytes)
    (public_inputs : PublicInputs)
    (h_verify : {{verifier_func}}_oracle proof public_inputs = .some false)
    : {{operation}}_functional_sim proof public_inputs = .aborted 65537 := by
  sorry

/--
Reduction lemma: functional sim result shape for malformed proof.
-/
theorem {{operation}}_functional_sim_malformed
    (proof : ProofBytes)
    (public_inputs : PublicInputs)
    (h_malformed : {{verifier_func}}_oracle proof public_inputs = .none)
    : {{operation}}_functional_sim proof public_inputs = .aborted 65538 := by
  sorry

end MovementFormal.Experimental.ConfidentialAsset.{{MODULE_NAME}}
LEAN_TEMPLATE

    # Replace placeholders
    sed -i.bak "s/{{OPERATION_NAME}}/$operation/g" "$output_file"
    sed -i.bak "s/{{MODULE_NAME}}/$module_name/g" "$output_file"
    sed -i.bak "s/{{VERIFIER_FUNCTION}}/$verifier_func/g" "$output_file"
    sed -i.bak "s/{{operation}}/$operation/g" "$output_file"
    rm -f "$output_file.bak"

    success "Generated Lean template: $output_file"

    if [[ "$VERBOSE" == true ]]; then
        info "File size: $(wc -l < "$output_file") lines"
        info "Next steps:"
        echo "  1. Fill in symbolic state fields for $operation"
        echo "  2. Add per-PC step theorems (typically 10-25 PCs)"
        echo "  3. Complete error path theorems"
        echo "  4. Prove eval_${operation}_eq_run"
        echo "  5. Build with: lake build MovementFormal.Experimental.ConfidentialAsset.${module_name}.EvalEquiv"
    fi
}

# ===========================
# MSL template generation
# ===========================

generate_msl_template() {
    local operation="$1"
    local move_func
    move_func=$(op_to_move_function "$operation")

    local output_file
    if [[ -n "$OUTPUT_DIR" ]]; then
        output_file="$OUTPUT_DIR/${operation}_spec_template.spec.move"
    else
        # Template goes to a temp location (user copies to actual spec file)
        output_file="$FORMAL_DIR/templates/${operation}_spec_template.spec.move"
    fi

    local output_dir
    output_dir=$(dirname "$output_file")

    if [[ -f "$output_file" ]] && [[ "$FORCE" != true ]]; then
        warn "File already exists: $output_file (use --force to overwrite)"
        return 1
    fi

    mkdir -p "$output_dir"

    info "Generating MSL spec template for $operation..."

    cat > "$output_file" <<'MSL_TEMPLATE'
// MSL Spec Template for {{OPERATION_NAME}}
// Generated by generate_test_template.sh
//
// This template provides a starting point for writing Move Prover specs.
// Fill in TODOs with operation-specific logic.
//
// See MSL_SPEC_PATTERN_LIBRARY.md for detailed pattern documentation.

spec aptos_experimental::confidential_asset {

    // ===========================
    // Spec Functions (Helpers)
    // ===========================

    /// Sum of encrypted balance chunks.
    /// Pattern: Balance Conservation (Pattern #1)
    spec fun sum_balance_chunks(balance: vector<u8>): u256 {
        if (len(balance) == 0) {
            0
        } else {
            chunk_value(balance[0]) + sum_balance_chunks(slice(balance, 1, len(balance)))
        }
    }

    /// Extract numeric value from a single chunk.
    /// NOTE: This is a crypto-opaque abstraction - the verifier doesn't see inside.
    spec fun chunk_value(chunk: u8): u256;

    // TODO: Add operation-specific spec functions here
    // Examples:
    // - spec fun is_valid_proof(...): bool;
    // - spec fun extract_public_inputs(...): PublicInputs;

    // ===========================
    // Function Spec: {{MOVE_FUNCTION}}
    // ===========================

    spec {{MOVE_FUNCTION}}(
        // TODO: Fill in parameter list
        // Example:
        // store: &mut ConfidentialAssetStore,
        // proof: &vector<u8>,
        // public_inputs: &vector<u8>
    ) {
        // -------------------
        // Preconditions
        // -------------------

        // TODO: Add preconditions (requires clauses)
        // Examples:
        // - requires exists<ConfidentialAssetStore>(addr);
        // - requires !global<ConfidentialAssetStore>(addr).frozen;
        // - requires len(proof) > 0;

        // -------------------
        // Abort Conditions
        // -------------------

        pragma aborts_if_is_strict;

        // Pattern: Frozen Account Guard (Pattern #9)
        // TODO: Uncomment if operation checks frozen state
        // aborts_if global<ConfidentialAssetStore>(addr).frozen
        //     with ETOKEN_IS_FROZEN;

        // Pattern: Allow List Enforcement (Pattern #10)
        // TODO: Uncomment if operation checks allow list
        // let config = global<FAConfig>(addr);
        // aborts_if config.allow_list_enabled &&
        //           !vec_contains(config.allowed_addresses, sender)
        //     with ENOT_IN_ALLOW_LIST;

        // Pattern: Proof Verification Guard (Pattern #11)
        // TODO: Add proof verification abort condition
        // aborts_if !verify_{{operation}}_proof(proof, public_inputs)
        //     with ESIGMA_PROTOCOL_VERIFY_FAILED;

        // TODO: Add other abort conditions
        // Examples:
        // - aborts_if len(proof) == 0 with EINVALID_PROOF;
        // - aborts_if len(public_inputs) != EXPECTED_SIZE with EINVALID_PUBLIC_INPUTS;

        // -------------------
        // Postconditions
        // -------------------

        // Pattern: Balance Conservation (Pattern #1)
        // TODO: Uncomment if operation mutates balance
        // let pre_store = old(global<ConfidentialAssetStore>(addr));
        // let post_store = global<ConfidentialAssetStore>(addr);
        // ensures sum_balance_chunks(post_store.pending_balance) ==
        //         sum_balance_chunks(pre_store.pending_balance) + delta;

        // Pattern: Length Preservation Invariant (Pattern #2)
        // TODO: Uncomment if operation preserves chunk structure
        // ensures len(post_store.pending_balance) == len(pre_store.pending_balance);
        // ensures len(post_store.actual_balance) == len(pre_store.actual_balance);

        // Pattern: Frame Condition (Pattern #4)
        // TODO: Specify which fields are NOT modified
        // Examples:
        // ensures post_store.allow_list_enabled == pre_store.allow_list_enabled;
        // ensures post_store.auditor == pre_store.auditor;

        // TODO: Add operation-specific postconditions
        // Examples for key rotation:
        // ensures post_store.encryption_pubkey == new_pubkey;

        // -------------------
        // Modifies
        // -------------------

        // TODO: Specify which resources are modified
        // modifies global<ConfidentialAssetStore>(addr);

        // -------------------
        // Pragmas
        // -------------------

        // Pattern: Pragma Opaque (Pattern #5)
        // Mark crypto verification as opaque (Lean proves this part)
        // TODO: Uncomment if operation calls crypto verification
        // pragma opaque = verify_{{operation}}_proof;
    }

    // ===========================
    // Crypto Verification (Opaque)
    // ===========================

    // Pattern: Pragma Opaque for Crypto Boundaries (Pattern #5)
    // The crypto verification is proved in Lean (bytecode level).
    // Move Prover treats this as an uninterpreted function.

    // TODO: Uncomment and fill in if operation has crypto verification
    /*
    spec verify_{{operation}}_proof(
        proof: &vector<u8>,
        public_inputs: &vector<u8>
    ): bool {
        pragma opaque;
        // Axiomatic spec: returns true iff proof is valid
        // (Lean proves the bytecode implementation matches sigma protocol)
        ensures result == is_valid_{{operation}}_proof(proof, public_inputs);
    }
    */

    // ===========================
    // Helper Invariants
    // ===========================

    // Pattern: Quantified Invariants (Pattern #8)
    // TODO: Add invariants that hold over vector elements
    // Example:
    // invariant forall i in 0..len(store.pending_balance):
    //     chunk_is_valid(store.pending_balance[i]);

}
MSL_TEMPLATE

    # Replace placeholders
    sed -i.bak "s/{{OPERATION_NAME}}/$operation/g" "$output_file"
    sed -i.bak "s/{{MOVE_FUNCTION}}/$move_func/g" "$output_file"
    sed -i.bak "s/{{operation}}/$operation/g" "$output_file"
    rm -f "$output_file.bak"

    success "Generated MSL template: $output_file"

    if [[ "$VERBOSE" == true ]]; then
        info "File size: $(wc -l < "$output_file") lines"
        info "Next steps:"
        echo "  1. Fill in parameter list for $move_func"
        echo "  2. Add preconditions (requires clauses)"
        echo "  3. Complete abort conditions (all error paths)"
        echo "  4. Add postconditions (ensures clauses)"
        echo "  5. Test with: movement move prove --filter $move_func"
        echo "  6. See MSL_SPEC_PATTERN_LIBRARY.md for detailed patterns"
    fi
}

# ===========================
# Difftest template generation
# ===========================

generate_difftest_template() {
    local operation="$1"

    local output_file
    if [[ -n "$OUTPUT_DIR" ]]; then
        output_file="$OUTPUT_DIR/${operation}_difftest_template.md"
    else
        output_file="$FORMAL_DIR/templates/${operation}_difftest_template.md"
    fi

    local output_dir
    output_dir=$(dirname "$output_file")

    if [[ -f "$output_file" ]] && [[ "$FORCE" != true ]]; then
        warn "File already exists: $output_file (use --force to overwrite)"
        return 1
    fi

    mkdir -p "$output_dir"

    info "Generating difftest corpus template for $operation..."

    cat > "$output_file" <<'DIFFTEST_TEMPLATE'
# Difftest Corpus Template: {{OPERATION_NAME}}

Generated by generate_test_template.sh

This template provides a starting point for writing difftest corpus entries.
Each test case pins VM behavior against the Lean model for a specific input.

See CONFIDENTIAL_ASSETS_DIFFERENTIAL_TESTING_PLAN.md for detailed guidance.

---

## Test Case Structure

Each difftest corpus entry needs:

1. **Test ID**: Unique identifier (e.g., `{{operation}}_happy_path_001`)
2. **Description**: What this test case covers
3. **Input**: Concrete input bytes (proof, public inputs, account state)
4. **Expected output**: VM execution result (success, abort code, state changes)
5. **Tags**: Operation name, test category (happy_path, error_path, edge_case)

---

## Happy Path Test Cases

### Test: {{operation}}_happy_path_001
**Description**: Valid proof, unfrozen account, standard inputs

**Input:**
- Proof: `<TODO: hex-encoded proof bytes>`
- Public inputs: `<TODO: hex-encoded public input bytes>`
- Account state:
  - Frozen: `false`
  - Allow list enabled: `false`
  - Pending balance: `<TODO: initial balance chunks>`
  - Actual balance: `<TODO: initial balance chunks>`

**Expected output:**
- Result: `Success`
- State changes:
  - Pending balance: `<TODO: updated balance chunks>`
  - Actual balance: `<TODO: updated balance chunks>`
  - (other fields unchanged)

**Tags:** `{{operation}}`, `happy_path`, `valid_proof`

---

### Test: {{operation}}_happy_path_002
**Description**: Valid proof, maximum values (boundary test)

**Input:**
- Proof: `<TODO: proof for maximum value transfer>`
- Public inputs: `<TODO: maximum value public inputs>`
- Account state:
  - Frozen: `false`
  - Allow list enabled: `false`
  - Pending balance: `<TODO: maximum balance>`
  - Actual balance: `<TODO: maximum balance>`

**Expected output:**
- Result: `Success`
- State changes:
  - (TODO: specify expected state)

**Tags:** `{{operation}}`, `happy_path`, `boundary_value`

---

### Test: {{operation}}_happy_path_003
**Description**: Valid proof, zero values (edge case)

**Input:**
- Proof: `<TODO: proof for zero value>`
- Public inputs: `<TODO: zero value public inputs>`
- Account state:
  - Frozen: `false`
  - Allow list enabled: `false`
  - Pending balance: `<TODO: zero or minimal balance>`
  - Actual balance: `<TODO: zero or minimal balance>`

**Expected output:**
- Result: `Success`
- State changes:
  - (TODO: specify expected state)

**Tags:** `{{operation}}`, `happy_path`, `zero_value`

---

## Error Path Test Cases

### Test: {{operation}}_error_frozen_account
**Description**: Attempt operation on frozen account

**Input:**
- Proof: `<TODO: valid proof bytes>`
- Public inputs: `<TODO: valid public inputs>`
- Account state:
  - Frozen: `true` ← KEY DIFFERENCE
  - Allow list enabled: `false`
  - Pending balance: `<TODO: any balance>`
  - Actual balance: `<TODO: any balance>`

**Expected output:**
- Result: `Aborted`
- Abort code: `196613` (ETOKEN_IS_FROZEN)
- State changes: None (aborted before mutation)

**Tags:** `{{operation}}`, `error_path`, `frozen_account`

---

### Test: {{operation}}_error_verify_failed
**Description**: Invalid proof (verification failure)

**Input:**
- Proof: `<TODO: INVALID proof bytes (e.g., wrong signature)>`
- Public inputs: `<TODO: valid public inputs>`
- Account state:
  - Frozen: `false`
  - Allow list enabled: `false`
  - Pending balance: `<TODO: any balance>`
  - Actual balance: `<TODO: any balance>`

**Expected output:**
- Result: `Aborted`
- Abort code: `65537` (ESIGMA_PROTOCOL_VERIFY_FAILED)
- State changes: None

**Tags:** `{{operation}}`, `error_path`, `invalid_proof`

---

### Test: {{operation}}_error_malformed_proof
**Description**: Malformed proof structure (deserialization failure)

**Input:**
- Proof: `<TODO: MALFORMED proof bytes (truncated, wrong length, etc.)>`
- Public inputs: `<TODO: valid public inputs>`
- Account state:
  - Frozen: `false`
  - Allow list enabled: `false`
  - Pending balance: `<TODO: any balance>`
  - Actual balance: `<TODO: any balance>`

**Expected output:**
- Result: `Aborted`
- Abort code: `<TODO: malformed proof error code (65538?)>`
- State changes: None

**Tags:** `{{operation}}`, `error_path`, `malformed_input`

---

### Test: {{operation}}_error_allow_list
**Description**: Operation on account not in allow list

**Input:**
- Proof: `<TODO: valid proof bytes>`
- Public inputs: `<TODO: valid public inputs>`
- Account state:
  - Frozen: `false`
  - Allow list enabled: `true` ← KEY DIFFERENCE
  - Allowed addresses: `[<other addresses, not this one>]`
  - Pending balance: `<TODO: any balance>`
  - Actual balance: `<TODO: any balance>`

**Expected output:**
- Result: `Aborted`
- Abort code: `<TODO: allow list error code (196614?)>`
- State changes: None

**Tags:** `{{operation}}`, `error_path`, `allow_list`

---

## Edge Cases

### Test: {{operation}}_edge_concurrent_balance_update
**Description**: Operation immediately after another balance mutation

**Input:**
- Proof: `<TODO: valid proof for second operation>`
- Public inputs: `<TODO: valid public inputs>`
- Account state (AFTER PREVIOUS OP):
  - Frozen: `false`
  - Allow list enabled: `false`
  - Pending balance: `<TODO: balance from previous op>`
  - Actual balance: `<TODO: balance from previous op>`

**Expected output:**
- Result: `Success`
- State changes:
  - Pending balance: `<TODO: cumulative result>`
  - Actual balance: `<TODO: cumulative result>`

**Tags:** `{{operation}}`, `edge_case`, `concurrent_mutation`

---

### Test: {{operation}}_edge_empty_balance
**Description**: Operation on account with empty balance

**Input:**
- Proof: `<TODO: proof for operation on empty balance>`
- Public inputs: `<TODO: public inputs>`
- Account state:
  - Frozen: `false`
  - Allow list enabled: `false`
  - Pending balance: `[]` ← EMPTY
  - Actual balance: `[]` ← EMPTY

**Expected output:**
- Result: `<TODO: Success or Abort?>`
- Abort code (if aborted): `<TODO: appropriate error code>`
- State changes:
  - (TODO: specify expected behavior)

**Tags:** `{{operation}}`, `edge_case`, `empty_balance`

---

## Implementation Steps

1. **Generate concrete test inputs:**
   - Use Rust test harness to generate valid proofs and public inputs
   - Serialize to hex for corpus entries
   - See `move-lean-difftest/tests/confidential_asset_test.rs` for examples

2. **Run VM to capture actual output:**
   ```bash
   # Run operation in Move VM
   movement move run --function {{operation}}_internal --args <input-hex>
   # Capture output (success/abort, state changes)
   ```

3. **Create Lean model inputs:**
   - Transcribe hex inputs to Lean `ByteArray` values
   - See `BytecodeDifftestBridge.lean` for transcription format

4. **Add to difftest corpus:**
   - Update `move-lean-difftest/corpus/confidential_asset/{{operation}}.json`
   - Schema: `{ "id": "...", "input": {...}, "expected": {...}, "tags": [...] }`

5. **Verify with difftest runner:**
   ```bash
   ./move-lean-difftest/difftest.sh --suite confidential_asset --filter {{operation}}
   # Expect: all tests PASS (VM output matches Lean model output)
   ```

6. **Add to CI:**
   - Update `.github/workflows/ca-verification-suite.yaml`
   - Add {{operation}} tests to difftest job matrix

---

## Coverage Goals

Aim for:
- **3-5 happy path cases** (standard, boundary, edge cases)
- **5-8 error path cases** (all abort codes covered)
- **2-4 edge cases** (concurrent ops, empty state, etc.)

**Total: 10-17 test cases per operation**

This coverage ensures:
1. VM behavior is pinned for common inputs
2. All error paths are tested (abort code correctness)
3. Edge cases are handled correctly
4. Lean model faithfully matches VM (difftest passes)

---

## Next Steps

1. Fill in concrete hex values for inputs (use Rust test harness)
2. Run VM to capture expected outputs
3. Create Lean transcriptions
4. Add to `move-lean-difftest/corpus/confidential_asset/{{operation}}.json`
5. Run difftest: `./move-lean-difftest/difftest.sh --filter {{operation}}`
6. Iterate until all tests PASS
DIFFTEST_TEMPLATE

    # Replace placeholders
    sed -i.bak "s/{{OPERATION_NAME}}/$operation/g" "$output_file"
    sed -i.bak "s/{{operation}}/$operation/g" "$output_file"
    rm -f "$output_file.bak"

    success "Generated difftest template: $output_file"

    if [[ "$VERBOSE" == true ]]; then
        info "File size: $(wc -l < "$output_file") lines"
        info "Next steps:"
        echo "  1. Generate concrete test inputs (use Rust test harness)"
        echo "  2. Run VM to capture outputs"
        echo "  3. Create Lean transcriptions"
        echo "  4. Add to move-lean-difftest/corpus/confidential_asset/${operation}.json"
        echo "  5. Run: ./move-lean-difftest/difftest.sh --filter $operation"
        echo "  6. See CONFIDENTIAL_ASSETS_DIFFERENTIAL_TESTING_PLAN.md for details"
    fi
}

# ===========================
# Main execution
# ===========================

main() {
    info "Generating test templates for operation: $OPERATION (type: $TYPE)"

    case "$TYPE" in
        lean)
            generate_lean_template "$OPERATION"
            ;;
        msl)
            generate_msl_template "$OPERATION"
            ;;
        difftest)
            generate_difftest_template "$OPERATION"
            ;;
        all)
            generate_lean_template "$OPERATION"
            generate_msl_template "$OPERATION"
            generate_difftest_template "$OPERATION"
            ;;
    esac

    echo
    success "Template generation complete!"

    if [[ "$TYPE" == "all" ]]; then
        info "Generated 3 templates for $OPERATION"
        echo "  - Lean EvalEquiv template"
        echo "  - MSL spec template"
        echo "  - Difftest corpus template"
    fi

    echo
    info "See the following guides for detailed patterns:"
    echo "  - PROOF_PATTERNS_LIBRARY.md (Lean proof patterns)"
    echo "  - MSL_SPEC_PATTERN_LIBRARY.md (MSL spec patterns)"
    echo "  - CONTRIBUTING_TO_CA_VERIFICATION.md (workflow and standards)"
}

main
