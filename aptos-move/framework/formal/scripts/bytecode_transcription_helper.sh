#!/usr/bin/env bash
set -euo pipefail

#
# bytecode_transcription_helper.sh
#
# Purpose: Semi-automated helper for transcribing Move bytecode to Lean.
# Extracts bytecode from compiled Move module and generates Lean array skeleton.
#
# Usage:
#   ./bytecode_transcription_helper.sh --module <name> --function <name> [OPTIONS]
#
# Options:
#   --module <name>      Module name (required): confidential_asset, confidential_balance, etc.
#   --function <name>    Function name (required): transfer_internal, withdraw_internal, etc.
#   --operation <name>   Operation name (optional): for output naming (transfer, withdrawal, etc.)
#   --output-dir <dir>   Output directory (default: lean/MovementFormal/Experimental/ConfidentialAsset/<Operation>)
#   --compiled-path <p>  Path to compiled Move package (default: ../aptos-experimental/build)
#   --verbose            Show detailed disassembly output
#
# Examples:
#   ./bytecode_transcription_helper.sh --module confidential_asset --function transfer_internal --operation transfer
#   ./bytecode_transcription_helper.sh --module confidential_asset --function withdraw_internal --operation withdrawal --verbose
#

# Configuration
MODULE=""
FUNCTION=""
OPERATION=""
OUTPUT_DIR=""
COMPILED_PATH="../aptos-experimental/build"
VERBOSE=false

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --module)
      MODULE="$2"
      shift 2
      ;;
    --function)
      FUNCTION="$2"
      shift 2
      ;;
    --operation)
      OPERATION="$2"
      shift 2
      ;;
    --output-dir)
      OUTPUT_DIR="$2"
      shift 2
      ;;
    --compiled-path)
      COMPILED_PATH="$2"
      shift 2
      ;;
    --verbose)
      VERBOSE=true
      shift
      ;;
    --help)
      head -n 25 "$0" | tail -n +3 | sed 's/^# //' | sed 's/^#//'
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      echo "Run with --help for usage"
      exit 1
      ;;
  esac
done

# Validate arguments
if [[ -z "$MODULE" ]]; then
  echo -e "${RED}Error: --module is required${NC}"
  echo "Run with --help for usage"
  exit 1
fi

if [[ -z "$FUNCTION" ]]; then
  echo -e "${RED}Error: --function is required${NC}"
  echo "Run with --help for usage"
  exit 1
fi

# Infer operation name from function name if not provided
if [[ -z "$OPERATION" ]]; then
  # Try to extract operation name from function name
  # E.g., "transfer_internal" -> "transfer"
  OPERATION=$(echo "$FUNCTION" | sed 's/_internal$//' | sed 's/_entry$//')
fi

# Capitalize operation name for directory
OPERATION_CAP="$(echo "${OPERATION:0:1}" | tr '[:lower:]' '[:upper:]')${OPERATION:1}"

# Set default output directory
if [[ -z "$OUTPUT_DIR" ]]; then
  OUTPUT_DIR="lean/MovementFormal/Experimental/ConfidentialAsset/$OPERATION_CAP"
fi

# Check if compiled module exists
COMPILED_MODULE_PATH="${COMPILED_PATH}/AptosExperimental/bytecode_modules/${MODULE}.mv"
if [[ ! -f "$COMPILED_MODULE_PATH" ]]; then
  echo -e "${RED}Error: Compiled module not found at: $COMPILED_MODULE_PATH${NC}"
  echo "Have you compiled the Move package?"
  echo "Try: cd aptos-move/framework/aptos-experimental && aptos move compile"
  exit 1
fi

echo -e "${BLUE}=== Bytecode Transcription Helper ===${NC}"
echo "Module: $MODULE"
echo "Function: $FUNCTION"
echo "Operation: $OPERATION"
echo "Compiled path: $COMPILED_MODULE_PATH"
echo ""

# Disassemble the module
echo -e "${YELLOW}Step 1: Disassembling module...${NC}"
DISASM_OUTPUT=$(aptos move disassemble --module-path "$COMPILED_MODULE_PATH" 2>&1 || true)

if [[ $VERBOSE == true ]]; then
  echo "$DISASM_OUTPUT"
  echo ""
fi

# Extract the function bytecode
echo -e "${YELLOW}Step 2: Extracting function bytecode...${NC}"
FUNCTION_BYTECODE=$(echo "$DISASM_OUTPUT" | awk "/^public.*fun ${FUNCTION}/,/^}/" || true)

if [[ -z "$FUNCTION_BYTECODE" ]]; then
  echo -e "${RED}Error: Could not find function '$FUNCTION' in disassembled output${NC}"
  echo "Available functions:"
  echo "$DISASM_OUTPUT" | grep "^public.*fun " | sed 's/^public.*fun /  - /'
  exit 1
fi

echo -e "${GREEN}Found function bytecode (${#FUNCTION_BYTECODE} characters)${NC}"
echo ""

# Parse bytecode instructions
echo -e "${YELLOW}Step 3: Parsing bytecode instructions...${NC}"

# Extract just the bytecode lines (between "Code:" and "}")
BYTECODE_LINES=$(echo "$FUNCTION_BYTECODE" | sed -n '/Code:/,/^}/p' | grep -E '^\s+[0-9]+:' || true)

if [[ -z "$BYTECODE_LINES" ]]; then
  echo -e "${RED}Error: Could not extract bytecode instructions${NC}"
  exit 1
fi

INSTRUCTION_COUNT=$(echo "$BYTECODE_LINES" | wc -l | tr -d ' ')
echo -e "${GREEN}Found $INSTRUCTION_COUNT instructions${NC}"
echo ""

# Generate Lean array skeleton
echo -e "${YELLOW}Step 4: Generating Lean array skeleton...${NC}"

# Create output directory if needed
mkdir -p "$OUTPUT_DIR"

OUTPUT_FILE="${OUTPUT_DIR}/Bytecode.lean"

# Generate Lean file header
cat > "$OUTPUT_FILE" << 'ENDOFHEADER'
import MovementFormal.MoveModel.Basic
import MovementFormal.MoveModel.Instruction

namespace MovementFormal.Experimental.ConfidentialAsset.OPERATION_CAP

open MovementFormal.MoveModel

/-!
# OPERATION_CAP Operation Bytecode

Transcribed from Move bytecode for `FUNCTION_NAME`.

## Operation Flow

TODO: Document the high-level flow (what each section of PCs does)

Total: INSTRUCTION_COUNT instructions

## Transcription Notes

This file was generated by bytecode_transcription_helper.sh and requires manual refinement:
1. Verify instruction names match Lean Instruction type
2. Fill in argument values (field indices, constants, function indices)
3. Add comments documenting what each PC does
4. Group related PCs together with section headers

-/

def FUNCTION_NAMECode : Array Instruction := #[
ENDOFHEADER

# Replace placeholders in header
sed -i.bak "s/OPERATION_CAP/$OPERATION_CAP/g" "$OUTPUT_FILE"
sed -i.bak "s/FUNCTION_NAME/${FUNCTION//_internal/Internal}/g" "$OUTPUT_FILE"
sed -i.bak "s/INSTRUCTION_COUNT/$INSTRUCTION_COUNT/g" "$OUTPUT_FILE"
rm "${OUTPUT_FILE}.bak"

# Parse each bytecode instruction and generate Lean equivalent
PC=0
while IFS= read -r line; do
  # Extract instruction name and arguments
  INSTR=$(echo "$line" | awk '{print $2}')
  ARGS=$(echo "$line" | awk '{$1=$2=""; print $0}' | sed 's/^ *//' | tr -d '()' || true)

  # Map Move bytecode instruction to Lean Instruction
  LEAN_INSTR=""
  case "$INSTR" in
    ImmBorrowLoc)
      LEAN_INSTR="Instruction.immBorrowLoc $ARGS"
      ;;
    MutBorrowLoc)
      LEAN_INSTR="Instruction.mutBorrowLoc $ARGS"
      ;;
    ImmBorrowField)
      LEAN_INSTR="Instruction.immBorrowField $ARGS"
      ;;
    MutBorrowField)
      LEAN_INSTR="Instruction.mutBorrowField $ARGS"
      ;;
    CopyLoc)
      LEAN_INSTR="Instruction.copyLoc $ARGS"
      ;;
    MoveLoc)
      LEAN_INSTR="Instruction.moveLoc $ARGS"
      ;;
    StLoc)
      LEAN_INSTR="Instruction.stLoc $ARGS"
      ;;
    ReadRef)
      LEAN_INSTR="Instruction.readRef"
      ;;
    WriteRef)
      LEAN_INSTR="Instruction.writeRef"
      ;;
    LdConst)
      LEAN_INSTR="Instruction.ldConst $ARGS"
      ;;
    LdTrue)
      LEAN_INSTR="Instruction.ldTrue"
      ;;
    LdFalse)
      LEAN_INSTR="Instruction.ldFalse"
      ;;
    Call)
      LEAN_INSTR="Instruction.call $ARGS"
      ;;
    BrTrue)
      LEAN_INSTR="Instruction.brTrue $ARGS"
      ;;
    BrFalse)
      LEAN_INSTR="Instruction.brFalse $ARGS"
      ;;
    Branch)
      LEAN_INSTR="Instruction.branch $ARGS"
      ;;
    Ret)
      LEAN_INSTR="Instruction.ret"
      ;;
    Abort)
      LEAN_INSTR="Instruction.abort"
      ;;
    Not)
      LEAN_INSTR="Instruction.not"
      ;;
    And)
      LEAN_INSTR="Instruction.and"
      ;;
    Or)
      LEAN_INSTR="Instruction.or"
      ;;
    Eq)
      LEAN_INSTR="Instruction.eq"
      ;;
    Neq)
      LEAN_INSTR="Instruction.neq"
      ;;
    Lt)
      LEAN_INSTR="Instruction.lt"
      ;;
    Le)
      LEAN_INSTR="Instruction.le"
      ;;
    Gt)
      LEAN_INSTR="Instruction.gt"
      ;;
    Ge)
      LEAN_INSTR="Instruction.ge"
      ;;
    Add)
      LEAN_INSTR="Instruction.add"
      ;;
    Sub)
      LEAN_INSTR="Instruction.sub"
      ;;
    Mul)
      LEAN_INSTR="Instruction.mul"
      ;;
    Div)
      LEAN_INSTR="Instruction.div"
      ;;
    Mod)
      LEAN_INSTR="Instruction.mod"
      ;;
    VecPack)
      LEAN_INSTR="Instruction.vecPack $ARGS"
      ;;
    VecLen)
      LEAN_INSTR="Instruction.vecLen $ARGS"
      ;;
    VecImmBorrow)
      LEAN_INSTR="Instruction.vecImmBorrow $ARGS"
      ;;
    VecMutBorrow)
      LEAN_INSTR="Instruction.vecMutBorrow $ARGS"
      ;;
    VecPushBack)
      LEAN_INSTR="Instruction.vecPushBack $ARGS"
      ;;
    VecPopBack)
      LEAN_INSTR="Instruction.vecPopBack $ARGS"
      ;;
    VecUnpack)
      LEAN_INSTR="Instruction.vecUnpack $ARGS"
      ;;
    VecSwap)
      LEAN_INSTR="Instruction.vecSwap $ARGS"
      ;;
    Pack)
      LEAN_INSTR="Instruction.pack $ARGS"
      ;;
    Unpack)
      LEAN_INSTR="Instruction.unpack $ARGS"
      ;;
    *)
      LEAN_INSTR="Instruction.unknown  -- TODO: Map $INSTR"
      ;;
  esac

  # Add comment with original bytecode
  COMMENT="-- PC $PC: $INSTR $ARGS"

  # Determine if this is the last instruction
  NEXT_PC=$((PC + 1))
  if [[ $NEXT_PC -eq $INSTRUCTION_COUNT ]]; then
    # Last instruction, no comma
    echo "  $LEAN_INSTR       $COMMENT" >> "$OUTPUT_FILE"
  else
    # Not last, add comma
    echo "  $LEAN_INSTR,      $COMMENT" >> "$OUTPUT_FILE"
  fi

  PC=$((PC + 1))
done <<< "$BYTECODE_LINES"

# Generate Lean file footer
cat >> "$OUTPUT_FILE" << 'ENDOFFOOTER'
]

#eval FUNCTION_NAMECode.size  -- Should output: INSTRUCTION_COUNT

end MovementFormal.Experimental.ConfidentialAsset.OPERATION_CAP
ENDOFFOOTER

# Replace placeholders in footer
sed -i.bak "s/OPERATION_CAP/$OPERATION_CAP/g" "$OUTPUT_FILE"
sed -i.bak "s/FUNCTION_NAME/${FUNCTION//_internal/Internal}/g" "$OUTPUT_FILE"
sed -i.bak "s/INSTRUCTION_COUNT/$INSTRUCTION_COUNT/g" "$OUTPUT_FILE"
rm "${OUTPUT_FILE}.bak"

echo -e "${GREEN}✅ Bytecode transcription skeleton generated!${NC}"
echo ""
echo "Output file: $OUTPUT_FILE"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "  1. Review the generated file and verify instruction mappings"
echo "  2. Fill in missing argument values (look for 'TODO' comments)"
echo "  3. Add section headers grouping related PCs (e.g., '-- PC 0-3: Check frozen')"
echo "  4. Document the operation flow in the header comment"
echo "  5. Test compilation: lake build MovementFormal.Experimental.ConfidentialAsset.$OPERATION_CAP.Bytecode"
echo ""
echo -e "${BLUE}Tip: Compare with disassembly output for argument values:${NC}"
echo "  aptos move disassemble --module-path $COMPILED_MODULE_PATH | less"
echo ""
echo -e "${BLUE}Tip: See BYTECODE_TRANSCRIPTION_GUIDE.md for detailed transcription instructions${NC}"
