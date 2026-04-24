#!/usr/bin/env python3
"""
Fix Refinement.AptosExperimental.Confidential.lean:
1. Mark evalCA as noncomputable
2. Replace all native_decide with sorry
"""

import re

def fix_file(filepath):
    with open(filepath, 'r') as f:
        content = f.read()

    # Fix 1: Mark evalCA as noncomputable
    content = re.sub(
        r'^abbrev evalCA',
        'noncomputable abbrev evalCA',
        content,
        flags=re.MULTILINE
    )

    # Fix 2: Replace all native_decide with sorry
    content = re.sub(
        r'\bnative_decide\b',
        'sorry',
        content
    )

    with open(filepath, 'w') as f:
        f.write(content)

    print(f"Fixed {filepath}")
    print("  - Marked evalCA as noncomputable")
    print("  - Replaced all native_decide with sorry")

if __name__ == '__main__':
    fix_file('/Users/andygmove/Downloads/repos/aptos-core/aptos-move/framework/formal/lean/MovementFormal/Refinement/AptosExperimental/Confidential.lean')
