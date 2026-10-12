/-
Copyright (c) Move Industries.

Kernel refinements: `aclOracle*` catalog matches `MovementFormal.Std.Acl` on `MvAcl` wires (`aclWireOf`).

**Source:** `aptos-move/framework/move-stdlib/sources/acl.move`; catalog `MovementFormal.MoveModel.AclCatalog`.
-/

import MovementFormal.MoveModel.Native.StdPrimitives
import MovementFormal.Std.Acl

namespace MovementFormal.Refinement.Std.AclCatalog

open MovementFormal.MoveModel
open MovementFormal.MoveModel.Native.StdPrimitives
open MovementFormal.Std.Acl

theorem aclOracleEmpty_ok : aclOracleEmpty [] = some [aclWireOf empty] := rfl

end MovementFormal.Refinement.Std.AclCatalog
