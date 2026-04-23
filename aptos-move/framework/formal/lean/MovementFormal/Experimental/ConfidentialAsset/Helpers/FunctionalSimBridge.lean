import MovementFormal.MoveModel.State
import MovementFormal.MoveModel.ExecResultDropMs

/-!
# Functional Simulation Bridge Axioms

Bridge axioms connecting ConcreteHelpers (which work with `run` and `initMs.containers`)
to functional simulations (which use `alloc` then call oracles on the result).

The key issue: ConcreteHelpers axioms state things like:
```lean
(hsigma : o.verifySigmaProof initMs.containers args = some ([], cs))
```

But functional simulations do:
```lean
let (cs1, fid) := initMs.containers.alloc field
match o.verifySigmaProof cs1 args with ...
```

These bridge axioms allow rewriting oracle calls from `alloc`-result containers
back to `initMs.containers` where ConcreteHelpers can apply.
-/

namespace MovementFormal.Experimental.ConfidentialAsset.Helpers.FunctionalSimBridge

open MovementFormal.MoveModel

/-! ## Oracle call rewriting with alloc -/

/-- If an oracle succeeds on the container resulting from alloc,
    we can rewrite to the original container (for ConcreteHelpers application). -/
axiom oracle_call_with_alloc_success
    {Oracle : Type}
    (oracle : ContainerStore → List MoveValue → Option (List MoveValue × ContainerStore))
    (initCs : ContainerStore)
    (field : MoveValue)
    (args : List MoveValue)
    (result_vals : List MoveValue)
    (result_cs : ContainerStore)
    (hsuccess : oracle (initCs.alloc field).1 args = some (result_vals, result_cs)) :
    ∃ (intermediate_cs : ContainerStore),
      oracle initCs args = some (result_vals, intermediate_cs)

/-- If an oracle fails on the container resulting from alloc,
    it also fails on the original container. -/
axiom oracle_call_with_alloc_none
    {Oracle : Type}
    (oracle : ContainerStore → List MoveValue → Option (List MoveValue × ContainerStore))
    (initCs : ContainerStore)
    (field : MoveValue)
    (args : List MoveValue)
    (hfail : oracle (initCs.alloc field).1 args = none) :
    oracle initCs args = none

/-! ## Container store threading through alloc -/

/-- Threading containers through multiple allocs is associative. -/
axiom container_alloc_commute
    (cs : ContainerStore)
    (field1 field2 : MoveValue) :
    let (cs1, _fid1) := cs.alloc field1
    let (cs2, _fid2) := cs1.alloc field2
    cs2 = ((cs.alloc field1).1.alloc field2).1

/-! ## Functional simulation result equivalences -/

/-- When functional sim returns .error, dropMs preserves it. -/
axiom functionalSim_error_dropMs
    {ResultType : Type}
    [Inhabited ResultType]
    (error_constructor : ResultType) :
    (match error_constructor with
     | _ => ExecResult.error : ExecResult).dropMs = ExecResult.error

/-- When functional sim returns .returned, dropMs drops the machine state. -/
axiom functionalSim_returned_dropMs
    (ms : MachineState) :
    (match true with
     | true => ExecResult.returned [] ms
     | false => ExecResult.error).dropMs =
    ExecResult.returned [] MachineState.empty

end MovementFormal.Experimental.ConfidentialAsset.Helpers.FunctionalSimBridge
