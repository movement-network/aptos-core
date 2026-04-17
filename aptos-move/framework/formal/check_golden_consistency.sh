#!/usr/bin/env bash
# Checks that golden byte constants are consistent between Move tests and Lean source.
# Run from the repo root: bash aptos-move/framework/formal/check_golden_consistency.sh
#
# Requires: python3 (for reliable hex extraction from Lean's mixed decimal/0x format)
# Exit code 0 = all consistent, 1 = drift detected.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
LEAN_DIR="$REPO_ROOT/aptos-move/framework/formal/lean/MovementFormal"
MOVE_STDLIB_TESTS="$REPO_ROOT/aptos-move/framework/move-stdlib/tests"
MOVE_EXP_TESTS="$REPO_ROOT/aptos-move/framework/aptos-experimental/tests/confidential_asset"

FAIL=0

check() {
    local label="$1" move_hex="$2" lean_hex="$3"
    if [ "$move_hex" = "$lean_hex" ]; then
        echo "  OK  $label (${#move_hex} hex chars)"
    else
        echo "  FAIL  $label"
        echo "    Move (${#move_hex}): $move_hex"
        echo "    Lean (${#lean_hex}): $lean_hex"
        FAIL=1
    fi
}

# Extract hex from a Move function's x"..." expected value (last hex literal in function)
move_hex_in_fn() {
    local file="$1" fn_name="$2"
    awk "/fun ${fn_name}\\(/,/^[[:space:]]*\}/" "$file" \
        | grep -oE 'x"[0-9a-fA-F]+"' | tail -n 1 | sed 's/x"//;s/"//' | tr '[:upper:]' '[:lower:]'
}

# Extract hex bytes from a Lean `def name` block's ByteArray.mk #[...]
# Handles 0xNN, plain decimal (0, 1, 32), and mixed formats
lean_hex_def() {
    local file="$1" defname="$2"
    awk "/^def ${defname}[[:space:]]/,/\]/" "$file" \
        | python3 -c "
import sys, re
text = sys.stdin.read()
m = re.search(r'#\[(.*?)\]', text, re.DOTALL)
if not m:
    sys.exit(1)
vals = [v.strip() for v in m.group(1).split(',') if v.strip()]
for v in vals:
    if v.startswith('0x') or v.startswith('0X'):
        print(v[2:].lower().zfill(2), end='')
    else:
        print(format(int(v), '02x'), end='')
"
}

echo "=== Golden byte consistency: Move ↔ Lean ==="
echo ""

echo "--- SHA3-256(\"abc\") ---"
MOVE_SHA3=$(move_hex_in_fn "$MOVE_STDLIB_TESTS/formal_goldens_hash.move" "golden_sha3_256_abc")
LEAN_SHA3=$(lean_hex_def "$LEAN_DIR/Std/Hash/Sha3_256.lean" "expectedSha3_256_abc")
check "sha3_256(abc)" "$MOVE_SHA3" "$LEAN_SHA3"

echo ""
echo "--- BCS address @0x1 ---"
MOVE_ADDR1=$(move_hex_in_fn "$MOVE_STDLIB_TESTS/formal_goldens_bcs_address.move" "golden_bcs_address_0x1")
LEAN_ADDR1=$(lean_hex_def "$LEAN_DIR/Experimental/ConfidentialAsset/Registration/TranscriptAlignment.lean" "bcsAddress0x1")
check "bcs(@0x1)" "$MOVE_ADDR1" "$LEAN_ADDR1"

echo ""
echo "--- BCS address @0x2 ---"
MOVE_ADDR2=$(move_hex_in_fn "$MOVE_STDLIB_TESTS/formal_goldens_bcs_address.move" "golden_bcs_address_0x2")
LEAN_ADDR2=$(lean_hex_def "$LEAN_DIR/Experimental/ConfidentialAsset/Registration/TranscriptAlignment.lean" "bcsAddress0x2")
check "bcs(@0x2)" "$MOVE_ADDR2" "$LEAN_ADDR2"

echo ""
echo "--- BCS address @0x3 ---"
MOVE_ADDR3=$(move_hex_in_fn "$MOVE_STDLIB_TESTS/formal_goldens_bcs_address.move" "golden_bcs_address_0x3")
LEAN_ADDR3=$(lean_hex_def "$LEAN_DIR/Experimental/ConfidentialAsset/Registration/TranscriptAlignment.lean" "bcsAddress0x3")
check "bcs(@0x3)" "$MOVE_ADDR3" "$LEAN_ADDR3"

echo ""
echo "--- BCS address @0x10 ---"
MOVE_ADDR10=$(move_hex_in_fn "$MOVE_STDLIB_TESTS/formal_goldens_bcs_address.move" "golden_bcs_address_0x10")
LEAN_ADDR10=$(lean_hex_def "$LEAN_DIR/Experimental/ConfidentialAsset/Registration/TranscriptAlignment.lean" "bcsAddress0x10")
check "bcs(@0x10)" "$MOVE_ADDR10" "$LEAN_ADDR10"

echo ""
echo "--- BCS address @0x20 ---"
MOVE_ADDR20=$(move_hex_in_fn "$MOVE_STDLIB_TESTS/formal_goldens_bcs_address.move" "golden_bcs_address_0x20")
LEAN_ADDR20=$(lean_hex_def "$LEAN_DIR/Experimental/ConfidentialAsset/Registration/TranscriptAlignment.lean" "bcsAddress0x20")
check "bcs(@0x20)" "$MOVE_ADDR20" "$LEAN_ADDR20"

echo ""
echo "--- BCS address @0x30 ---"
MOVE_ADDR30=$(move_hex_in_fn "$MOVE_STDLIB_TESTS/formal_goldens_bcs_address.move" "golden_bcs_address_0x30")
LEAN_ADDR30=$(lean_hex_def "$LEAN_DIR/Experimental/ConfidentialAsset/Registration/TranscriptAlignment.lean" "bcsAddress0x30")
check "bcs(@0x30)" "$MOVE_ADDR30" "$LEAN_ADDR30"

echo ""
echo "--- Ristretto basepoint compressed ---"
# Move doesn't hardcode this; it uses ristretto255::basepoint_compressed().
# But the Lean constant must match. Check the hex appears in the FS golden messages.
LEAN_BP=$(lean_hex_def "$LEAN_DIR/Experimental/ConfidentialAsset/Registration/TranscriptAlignment.lean" "ristrettoBasepointCompressedBytes")
echo "  INFO  basepoint = $LEAN_BP (verify against ristretto spec: e2f2ae0a6abc4e71...)"

echo ""
echo "--- FS message golden #1 (chain_id=9, @0x1/@0x2/@0x3) ---"
MOVE_FS1=$(move_hex_in_fn "$MOVE_EXP_TESTS/formal_goldens_registration.move" "golden_registration_fs_message_matches_expected_bytes")
LEAN_FS1=$(lean_hex_def "$LEAN_DIR/Experimental/ConfidentialAsset/Registration/TranscriptAlignment.lean" "expectedRegistrationFsMsgMoveGolden")
check "fs_msg_1" "$MOVE_FS1" "$LEAN_FS1"

echo ""
echo "--- FS message golden #2 (chain_id=42, @0x10/@0x20/@0x30) ---"
MOVE_FS2=$(move_hex_in_fn "$MOVE_EXP_TESTS/formal_goldens_registration.move" "golden_registration_fs_message_second_scenario")
LEAN_FS2=$(lean_hex_def "$LEAN_DIR/Experimental/ConfidentialAsset/Registration/TranscriptAlignment.lean" "expectedRegistrationFsMsg2")
check "fs_msg_2" "$MOVE_FS2" "$LEAN_FS2"

echo ""
if [ "$FAIL" -eq 0 ]; then
    echo "All golden bytes consistent."
else
    echo "DRIFT DETECTED — update the out-of-date side to match."
    exit 1
fi
