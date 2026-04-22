import MovementFormal.Experimental.ConfidentialAsset.Registration.EvalEquiv.Part3

/-!
This file is **Part4** of the split `EvalEquiv` proof (see `Registration.EvalEquiv`).
-/


namespace MovementFormal.Experimental.ConfidentialAsset.Registration.EvalEquiv

open MovementFormal.MoveModel
open MovementFormal.MoveModel.Native.Registration
open MovementFormal.MoveModel.Programs.Registration
open MovementFormal.Experimental.ConfidentialAsset.Registration.FunctionalSim
open MovementFormal.Experimental.ConfidentialAsset.Registration.Formal

set_option linter.unusedSimpArgs false

/-! ## Composed happy-path chain: PC 2 → PC 9

Threads `registration_run_from_pc2_to_pc6_somePath` with `registration_run_from_pc6_to_pc9_somePath`
to produce a single run-level equality covering the entry-to-`rCompressed`-stored fragment of the
registration bytecode. This is the smallest meaningful end-to-end composition and is used below to
build up to the full PC 2 → `returned` chain needed to discharge
`registration_eval_equiv_singleton_tail`. -/

theorem registration_run_pc2_to_pc9_happyPath
    (o : RegistrationNativeOracle)
    (chainId : UInt8) (sender contract token ekBa commitBa respBa : ByteArray)
    (mv rCompressed : MoveValue) (rest : List MoveValue)
    (hmv : mv = .struct_ (.bool true :: rCompressed :: rest))
    (fuel : Nat) (hf : 9 ≤ fuel) :
    run (registrationModuleEnv o)
        (registrationFrameAtPc2 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
          (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa))
        [] [mv] MachineState.empty (fuel - 2) =
      run (registrationModuleEnv o)
        (registrationFramePc9AfterStLoc8 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
          (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa) mv rCompressed)
        [] [] (registrationMsAfterOptionExtractDup1 mv) (fuel - 9) := by
  have h1 := registration_run_from_pc2_to_pc6_somePath o chainId sender contract token ekBa commitBa respBa
    mv true (rCompressed :: rest) hmv rfl fuel (by omega)
  have h2 := registration_run_from_pc6_to_pc9_somePath o chainId sender contract token ekBa commitBa respBa
    mv rCompressed rest hmv (fuel - 6) (by omega)
  rw [h1, h2]
  have hfuel_eq : (fuel - 6) - 3 = fuel - 9 := by omega
  rw [hfuel_eq]

/-- Extends `registration_run_pc2_to_pc9_happyPath` through the `newScalarFromBytes` singleton
branch, the `option::is_some`/`option::extract` of `sOpt`, and the constant-DST `stLoc`
(`sVal` now in local 10, `msg` buffer in local 11), arriving just before PC 20
(`mutBorrowLoc 11` to begin appending `chainId`). -/
theorem registration_run_pc2_to_pc20_happyPath
    (o : RegistrationNativeOracle)
    (chainId : UInt8) (sender contract token ekBa commitBa respBa : ByteArray)
    (mv rCompressed sOpt sVal : MoveValue) (rest srest' : List MoveValue)
    (hmv : mv = .struct_ (.bool true :: rCompressed :: rest))
    (hsOpt : sOpt = .struct_ (.bool true :: sVal :: srest'))
    (hsc : o.newScalarFromBytes [.vector .u8 (respBa.toList.map .u8)] = some [sOpt])
    (fuel : Nat) (hf : 20 ≤ fuel) :
    run (registrationModuleEnv o)
        (registrationFrameAtPc2 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
          (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa))
        [] [mv] MachineState.empty (fuel - 2) =
      run (registrationModuleEnv o)
        (registrationFramePc20AfterStLoc11 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
          (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa) mv rCompressed sOpt sVal)
        [] [] (registrationMsAfterOptionExtractDup3 mv sOpt) (fuel - 20) := by
  have h1 := registration_run_pc2_to_pc9_happyPath o chainId sender contract token ekBa commitBa respBa
    mv rCompressed rest hmv fuel (by omega)
  have h2 := registration_run_from_pc9_to_pc12_singletonPath o chainId sender contract token ekBa commitBa respBa
    mv rCompressed sOpt hsc (fuel - 9) (by omega)
  have h3 := registration_run_from_pc12_to_pc15_someSOptPath o chainId sender contract token ekBa commitBa respBa
    mv rCompressed sOpt true (sVal :: srest') hsOpt rfl (fuel - 12) (by omega)
  have h4 := registration_run_from_pc15_to_pc18_singletonSomePath o chainId sender contract token ekBa commitBa respBa
    mv rCompressed sOpt sVal srest' hsOpt (fuel - 15) (by omega)
  have h5 := registration_run_from_pc18_to_pc20_path o chainId sender contract token ekBa commitBa respBa
    mv rCompressed sOpt sVal (fuel - 18) (by omega)
  rw [h1, h2]
  rw [show (fuel - 9) - 3 = fuel - 12 from by omega]
  rw [h3]
  rw [show (fuel - 12) - 3 = fuel - 15 from by omega]
  rw [h4]
  rw [show (fuel - 15) - 3 = fuel - 18 from by omega]
  rw [h5]
  rw [show (fuel - 18) - 2 = fuel - 20 from by omega]

/-- Store size of `registrationMsAfterAppendContract`: the post-append MS has size 7
(`registrationMsAfterImmBorrow2_contract` already alloced contract at ref 6, and the write at ref 4
does not change size). -/
theorem registrationMsAfterAppendContract_store_size
    (mv sOpt : MoveValue) (chainId : UInt8) (sender contract : ByteArray) :
    (registrationMsAfterAppendContract mv sOpt chainId sender contract).containers.store.size = 7 := by
  have hwrite := registration_write_append_contract_eq mv sOpt chainId sender contract
  have hlt := registration_contract_lt4 mv sOpt chainId sender contract
  have hw' :
      (registrationMsAfterImmBorrow2_contract mv sOpt chainId sender contract).containers.write 4
        (.vector .u8 (((fiatShamirRegistrationDstBytesList ++ [.u8 chainId]) ++ sender.toList.map .u8)
          ++ contract.toList.map .u8)) =
        some ⟨(registrationMsAfterImmBorrow2_contract mv sOpt chainId sender contract).containers.store.set 4
          (.vector .u8 (((fiatShamirRegistrationDstBytesList ++ [.u8 chainId]) ++ sender.toList.map .u8)
            ++ contract.toList.map .u8)) hlt⟩ := by
      simp [ContainerStore.write, hlt]
  rw [hw'] at hwrite
  have hstore : (registrationMsAfterAppendContract mv sOpt chainId sender contract).containers.store =
      (registrationMsAfterImmBorrow2_contract mv sOpt chainId sender contract).containers.store.set 4
        (.vector .u8 (((fiatShamirRegistrationDstBytesList ++ [.u8 chainId]) ++ sender.toList.map .u8)
          ++ contract.toList.map .u8)) hlt := by
    have h := (Option.some.inj hwrite).symm
    exact congrArg ContainerStore.store h
  have halloc : (registrationMsAfterImmBorrow2_contract mv sOpt chainId sender contract).containers =
      ((registrationMsAfterAppendSender mv sOpt chainId sender).containers.alloc (.address contract)).1 := rfl
  rw [hstore, Array.size_set, halloc]
  simp [ContainerStore.alloc, Array.size_push, registrationMsAfterAppendSender_store_size]

/-- `registrationMsAfterAppendContract` at ref 4 holds the concrete `DST ++ [chainId] ++ BCS(sender) ++ BCS(contract)` buffer. -/
theorem registrationMsAfterAppendContract_read4
    (mv sOpt : MoveValue) (chainId : UInt8) (sender contract : ByteArray) :
    (registrationMsAfterAppendContract mv sOpt chainId sender contract).containers.read 4 =
      some (.vector .u8 (((fiatShamirRegistrationDstBytesList ++ [.u8 chainId]) ++ sender.toList.map .u8)
        ++ contract.toList.map .u8)) :=
  ContainerStore.read_of_write
    (registrationMsAfterImmBorrow2_contract mv sOpt chainId sender contract).containers 4 _
    (registrationMsAfterAppendContract mv sOpt chainId sender contract).containers
    (registration_contract_lt4 mv sOpt chainId sender contract)
    (registration_write_append_contract_eq mv sOpt chainId sender contract)

/-- Allocating `token` on `registrationMsAfterAppendContract` does not disturb the read at ref 4. -/
theorem registrationMsAfterAppendContract_alloc_token_read4
    (mv sOpt : MoveValue) (chainId : UInt8) (sender contract token : ByteArray) :
    ((registrationMsAfterAppendContract mv sOpt chainId sender contract).containers.alloc
        (.address token)).1.read 4 =
      some (.vector .u8 (((fiatShamirRegistrationDstBytesList ++ [.u8 chainId]) ++ sender.toList.map .u8)
        ++ contract.toList.map .u8)) :=
  containerStore_read_alloc_of_read_some _ _ 4 _
    (registrationMsAfterAppendContract_read4 mv sOpt chainId sender contract)

/-- After `alloc token`, ref 4 is still in bounds (size grew from 7 to 8). -/
theorem registrationMsAfterAppendContract_alloc_token_lt4
    (mv sOpt : MoveValue) (chainId : UInt8) (sender contract token : ByteArray) :
    4 < ((registrationMsAfterAppendContract mv sOpt chainId sender contract).containers.alloc
        (.address token)).1.store.size := by
  simp [ContainerStore.alloc, Array.size_push,
    registrationMsAfterAppendContract_store_size]

/-- Canonical post-PC 34 ContainerStore (after `call 6` appends `BCS(token)` to ref 4). -/
def registrationCsAfterAppendToken
    (mv sOpt : MoveValue) (chainId : UInt8) (sender contract token : ByteArray) : ContainerStore :=
  ⟨((registrationMsAfterAppendContract mv sOpt chainId sender contract).containers.alloc
      (.address token)).1.store.set 4
    (.vector .u8 ((((fiatShamirRegistrationDstBytesList ++ [.u8 chainId]) ++ sender.toList.map .u8)
      ++ contract.toList.map .u8) ++ token.toList.map .u8))
    (registrationMsAfterAppendContract_alloc_token_lt4 mv sOpt chainId sender contract token)⟩

theorem registrationMsAfterAppendContract_alloc_token_write4
    (mv sOpt : MoveValue) (chainId : UInt8) (sender contract token : ByteArray) :
    ((registrationMsAfterAppendContract mv sOpt chainId sender contract).containers.alloc
        (.address token)).1.write 4
      (.vector .u8 ((((fiatShamirRegistrationDstBytesList ++ [.u8 chainId]) ++ sender.toList.map .u8)
        ++ contract.toList.map .u8) ++ token.toList.map .u8)) =
      some (registrationCsAfterAppendToken mv sOpt chainId sender contract token) := by
  simp only [ContainerStore.write,
    dif_pos (registrationMsAfterAppendContract_alloc_token_lt4 mv sOpt chainId sender contract token)]
  rfl

/-- `msg` bytes at ref 4 after appending `BCS(token)` (post-PC 35). -/
abbrev registrationMsgBytesAfterToken (mv sOpt : MoveValue) (chainId : UInt8) (sender contract token : ByteArray) :
    List MoveValue :=
  (((fiatShamirRegistrationDstBytesList ++ [.u8 chainId]) ++ sender.toList.map .u8) ++ contract.toList.map .u8) ++
    token.toList.map .u8

set_option maxHeartbeats 800000 in
theorem registrationCsAfterAppendToken_read4
    (mv sOpt : MoveValue) (chainId : UInt8) (sender contract token : ByteArray) :
    (registrationCsAfterAppendToken mv sOpt chainId sender contract token).read 4 =
      some (.vector .u8 (registrationMsgBytesAfterToken mv sOpt chainId sender contract token)) := by
  let csPre :=
    ((registrationMsAfterAppendContract mv sOpt chainId sender contract).containers.alloc (.address token)).1
  have hlt : 4 < csPre.store.size :=
    registrationMsAfterAppendContract_alloc_token_lt4 mv sOpt chainId sender contract token
  have hw := registrationMsAfterAppendContract_alloc_token_write4 mv sOpt chainId sender contract token
  exact ContainerStore.read_of_write csPre 4
    (.vector .u8 ((((fiatShamirRegistrationDstBytesList ++ [.u8 chainId]) ++ sender.toList.map .u8)
      ++ contract.toList.map .u8) ++ token.toList.map .u8))
    (registrationCsAfterAppendToken mv sOpt chainId sender contract token) hlt hw

theorem registrationCsAfterAppendToken_lt4_store
    (mv sOpt : MoveValue) (chainId : UInt8) (sender contract token : ByteArray) :
    4 < (registrationCsAfterAppendToken mv sOpt chainId sender contract token).store.size := by
  unfold registrationCsAfterAppendToken
  simp only [Array.size_set]
  have hsz : ((registrationMsAfterAppendContract mv sOpt chainId sender contract).containers.alloc
      (.address token)).1.store.size = 8 := by
    simp only [ContainerStore.alloc, Array.size_push, registrationMsAfterAppendContract_store_size]
  rw [hsz]
  decide

/-- Post-PC 38 `ContainerStore`: `BCS(ek)` appended to `msg` at ref 4. -/
def registrationCsAfterAppendPubkeyBytes
    (mv sOpt : MoveValue) (chainId : UInt8) (sender contract token : ByteArray) (ekBytesList : List MoveValue) :
    ContainerStore :=
  ⟨(registrationCsAfterAppendToken mv sOpt chainId sender contract token).store.set 4
      (.vector .u8 (registrationMsgBytesAfterToken mv sOpt chainId sender contract token ++ ekBytesList))
    (registrationCsAfterAppendToken_lt4_store mv sOpt chainId sender contract token)⟩

theorem registrationCsAfterAppendPubkeyBytes_write_eq
    (mv sOpt : MoveValue) (chainId : UInt8) (sender contract token : ByteArray) (ekBytesList : List MoveValue) :
    (registrationCsAfterAppendToken mv sOpt chainId sender contract token).write 4
        (.vector .u8 (registrationMsgBytesAfterToken mv sOpt chainId sender contract token ++ ekBytesList)) =
      some (registrationCsAfterAppendPubkeyBytes mv sOpt chainId sender contract token ekBytesList) := by
  have hlt := registrationCsAfterAppendToken_lt4_store mv sOpt chainId sender contract token
  simp only [registrationCsAfterAppendPubkeyBytes, ContainerStore.write, dif_pos hlt]

theorem registrationCsAfterAppendPubkeyBytes_read4
    (mv sOpt : MoveValue) (chainId : UInt8) (sender contract token : ByteArray) (ekBytesList : List MoveValue) :
    (registrationCsAfterAppendPubkeyBytes mv sOpt chainId sender contract token ekBytesList).read 4 =
      some (.vector .u8 (registrationMsgBytesAfterToken mv sOpt chainId sender contract token ++ ekBytesList)) := by
  let csTok := registrationCsAfterAppendToken mv sOpt chainId sender contract token
  have hlt : 4 < csTok.store.size :=
    registrationCsAfterAppendToken_lt4_store mv sOpt chainId sender contract token
  have hw := registrationCsAfterAppendPubkeyBytes_write_eq mv sOpt chainId sender contract token ekBytesList
  exact ContainerStore.read_of_write csTok 4
    (.vector .u8 (registrationMsgBytesAfterToken mv sOpt chainId sender contract token ++ ekBytesList))
    (registrationCsAfterAppendPubkeyBytes mv sOpt chainId sender contract token ekBytesList) hlt hw

theorem registrationCsAfterAppendPubkeyBytes_lt4_store
    (mv sOpt : MoveValue) (chainId : UInt8) (sender contract token : ByteArray) (ekBytesList : List MoveValue) :
    4 < (registrationCsAfterAppendPubkeyBytes mv sOpt chainId sender contract token ekBytesList).store.size := by
  unfold registrationCsAfterAppendPubkeyBytes
  simp only [Array.size_set]
  simpa using registrationCsAfterAppendToken_lt4_store mv sOpt chainId sender contract token

/-- `msg` at ref 4 after PC 39 (token + EK bytes). -/
abbrev registrationMsgBytesAfterPubkey (mv sOpt : MoveValue) (chainId : UInt8) (sender contract token : ByteArray)
    (ekBytesList : List MoveValue) : List MoveValue :=
  registrationMsgBytesAfterToken mv sOpt chainId sender contract token ++ ekBytesList

/-- Post-PC 42 `ContainerStore`: `compressed_point_to_bytes` + append to `msg` at ref 4. -/
def registrationCsAfterAppendCompressedPointBytes
    (mv sOpt : MoveValue) (chainId : UInt8) (sender contract token : ByteArray) (ekBytesList rcBytesList : List MoveValue) :
    ContainerStore :=
  ⟨(registrationCsAfterAppendPubkeyBytes mv sOpt chainId sender contract token ekBytesList).store.set 4
      (.vector .u8 (registrationMsgBytesAfterPubkey mv sOpt chainId sender contract token ekBytesList ++ rcBytesList))
    (registrationCsAfterAppendPubkeyBytes_lt4_store mv sOpt chainId sender contract token ekBytesList)⟩

theorem registrationCsAfterAppendCompressedPointBytes_write_eq
    (mv sOpt : MoveValue) (chainId : UInt8) (sender contract token : ByteArray) (ekBytesList rcBytesList : List MoveValue) :
    (registrationCsAfterAppendPubkeyBytes mv sOpt chainId sender contract token ekBytesList).write 4
        (.vector .u8 (registrationMsgBytesAfterPubkey mv sOpt chainId sender contract token ekBytesList ++
          rcBytesList)) =
      some (registrationCsAfterAppendCompressedPointBytes mv sOpt chainId sender contract token ekBytesList
        rcBytesList) := by
  have hlt := registrationCsAfterAppendPubkeyBytes_lt4_store mv sOpt chainId sender contract token ekBytesList
  simp only [registrationCsAfterAppendCompressedPointBytes, ContainerStore.write, dif_pos hlt]

/-- Full Fiat–Shamir `msg` wire at ref 4 after PC 42 (before `moveLoc 11` / SHA2-512 at PC 43–44). -/
abbrev registrationMsgBytesForFs (mv sOpt : MoveValue) (chainId : UInt8) (sender contract token : ByteArray)
    (ekBytesList rcBytesList : List MoveValue) : List MoveValue :=
  registrationMsgBytesAfterPubkey mv sOpt chainId sender contract token ekBytesList ++ rcBytesList

theorem registrationCsAfterAppendCompressedPointBytes_read4
    (mv sOpt : MoveValue) (chainId : UInt8) (sender contract token : ByteArray) (ekBytesList rcBytesList : List MoveValue) :
    (registrationCsAfterAppendCompressedPointBytes mv sOpt chainId sender contract token ekBytesList rcBytesList).read 4 =
      some (.vector .u8 (registrationMsgBytesForFs mv sOpt chainId sender contract token ekBytesList rcBytesList)) := by
  let csPre := registrationCsAfterAppendPubkeyBytes mv sOpt chainId sender contract token ekBytesList
  have hlt : 4 < csPre.store.size :=
    registrationCsAfterAppendPubkeyBytes_lt4_store mv sOpt chainId sender contract token ekBytesList
  have hw := registrationCsAfterAppendCompressedPointBytes_write_eq mv sOpt chainId sender contract token ekBytesList
      rcBytesList
  have h := ContainerStore.read_of_write csPre 4
      (.vector .u8 (registrationMsgBytesAfterPubkey mv sOpt chainId sender contract token ekBytesList ++ rcBytesList))
      (registrationCsAfterAppendCompressedPointBytes mv sOpt chainId sender contract token ekBytesList rcBytesList) hlt hw
  simpa [registrationMsgBytesForFs] using h

/-! ### PC 31 → PC 35 on the concrete post-contract MS

`registration_run_from_pc31_to_pc35_abstractMs` ends with a nested `{ ms with … }` update. The
same `ContainerStore` is obtained by a **single** `containers` update to
`registrationCsAfterAppendToken`, which matches how later PCs are stated and avoids repeating
the nested record shape when composing upward. -/

/-- Machine state after PC 35 when starting from `registrationMsAfterAppendContract` (token bytes
appended to `msg` at ref 4). -/
def registrationMsAfterAppendTokenMsg
    (mv sOpt : MoveValue) (chainId : UInt8) (sender contract token : ByteArray) : MachineState :=
  { (registrationMsAfterAppendContract mv sOpt chainId sender contract) with
    containers := registrationCsAfterAppendToken mv sOpt chainId sender contract token }

set_option maxHeartbeats 800000 in
theorem registration_ms_pc35_nested_record_eq_single
    (mv sOpt : MoveValue) (chainId : UInt8) (sender contract token : ByteArray) :
    { { (registrationMsAfterAppendContract mv sOpt chainId sender contract) with
        containers := ((registrationMsAfterAppendContract mv sOpt chainId sender contract).containers.alloc
            (.address token)).1 }
      with containers := registrationCsAfterAppendToken mv sOpt chainId sender contract token } =
      registrationMsAfterAppendTokenMsg mv sOpt chainId sender contract token := by
  rfl

/-- Machine state after PC 38: `pubkey_to_bytes` + `vector::append` extended `msg` at ref 4. -/
def registrationMsAfterAppendPubkeyMsg
    (mv sOpt : MoveValue) (chainId : UInt8) (sender contract token : ByteArray) (ekBytesList : List MoveValue) :
    MachineState :=
  { (registrationMsAfterAppendTokenMsg mv sOpt chainId sender contract token) with
    containers := registrationCsAfterAppendPubkeyBytes mv sOpt chainId sender contract token ekBytesList }

theorem registration_ms_pc39_abstract_output_eq_appendPubkey
    (mv sOpt : MoveValue) (chainId : UInt8) (sender contract token : ByteArray) (ekBytesList : List MoveValue) :
    { containers := registrationCsAfterAppendPubkeyBytes mv sOpt chainId sender contract token ekBytesList,
      globals := (registrationMsAfterAppendTokenMsg mv sOpt chainId sender contract token).globals,
      faBalances := (registrationMsAfterAppendTokenMsg mv sOpt chainId sender contract token).faBalances } =
      registrationMsAfterAppendPubkeyMsg mv sOpt chainId sender contract token ekBytesList := by
  rfl

/-- Machine state after PC 42: commitment point bytes appended to `msg` at ref 4. -/
def registrationMsAfterAppendCompressedPointMsg
    (mv sOpt : MoveValue) (chainId : UInt8) (sender contract token : ByteArray) (ekBytesList rcBytesList : List MoveValue) :
    MachineState :=
  { (registrationMsAfterAppendPubkeyMsg mv sOpt chainId sender contract token ekBytesList) with
    containers := registrationCsAfterAppendCompressedPointBytes mv sOpt chainId sender contract token ekBytesList
      rcBytesList }

theorem registration_ms_pc43_abstract_output_eq_appendCompressed
    (mv sOpt : MoveValue) (chainId : UInt8) (sender contract token : ByteArray) (ekBytesList rcBytesList : List MoveValue) :
    { containers :=
        registrationCsAfterAppendCompressedPointBytes mv sOpt chainId sender contract token ekBytesList rcBytesList,
      globals := (registrationMsAfterAppendPubkeyMsg mv sOpt chainId sender contract token ekBytesList).globals,
      faBalances :=
        (registrationMsAfterAppendPubkeyMsg mv sOpt chainId sender contract token ekBytesList).faBalances } =
      registrationMsAfterAppendCompressedPointMsg mv sOpt chainId sender contract token ekBytesList rcBytesList := by
  rfl

/-- After PC 51–54: `imm_borrow` allocates refs for Fiat–Shamir basis `H` and response scalar `s`,
then `point_mul` stores `s * H` in local 15 — two fresh container cells on the prior `msg` state. -/
def registrationMsAfterPointMulSH
    (mv sOpt : MoveValue) (chainId : UInt8) (sender contract token : ByteArray) (ekBytesList rcBytesList : List MoveValue)
    (hPoint sVal : MoveValue) : MachineState :=
  let ms := registrationMsAfterAppendCompressedPointMsg mv sOpt chainId sender contract token ekBytesList rcBytesList
  { ms with containers := ((ms.containers.alloc hPoint).1.alloc sVal).1 }

theorem registration_ms_pc55_abstract_output_eq_pointMulSH
    (mv sOpt : MoveValue) (chainId : UInt8) (sender contract token : ByteArray) (ekBytesList rcBytesList : List MoveValue)
    (hPoint sVal : MoveValue) :
    { (registrationMsAfterAppendCompressedPointMsg mv sOpt chainId sender contract token ekBytesList rcBytesList) with
      containers :=
        (((registrationMsAfterAppendCompressedPointMsg mv sOpt chainId sender contract token ekBytesList rcBytesList).containers.alloc
              hPoint).1.alloc sVal).1 } =
      registrationMsAfterPointMulSH mv sOpt chainId sender contract token ekBytesList rcBytesList hPoint sVal := by
  rfl

/-- After PC 55–58: three fresh allocs (`s*H`, EK point, challenge `e`) then `point_mul` yields `e * K`
on the stack before `stLoc 16`. -/
def registrationMsAfterPointMulEkE
    (mv sOpt : MoveValue) (chainId : UInt8) (sender contract token : ByteArray) (ekBytesList rcBytesList : List MoveValue)
    (hPoint sVal hsPt ekPt eScalar : MoveValue) : MachineState :=
  let ms := registrationMsAfterPointMulSH mv sOpt chainId sender contract token ekBytesList rcBytesList hPoint sVal
  { ms with containers := (((ms.containers.alloc hsPt).1.alloc ekPt).1.alloc eScalar).1 }

theorem registration_ms_pc59_abstract_output_eq_pointMulEkE
    (mv sOpt : MoveValue) (chainId : UInt8) (sender contract token : ByteArray) (ekBytesList rcBytesList : List MoveValue)
    (hPoint sVal hsPt ekPt eScalar : MoveValue) :
    { (registrationMsAfterPointMulSH mv sOpt chainId sender contract token ekBytesList rcBytesList hPoint sVal) with
      containers :=
        ((((registrationMsAfterPointMulSH mv sOpt chainId sender contract token ekBytesList rcBytesList hPoint sVal).containers.alloc
                hsPt).1.alloc ekPt).1.alloc eScalar).1 } =
      registrationMsAfterPointMulEkE mv sOpt chainId sender contract token ekBytesList rcBytesList hPoint sVal hsPt ekPt
        eScalar := by
  rfl

theorem registration_ms_pointMulEkE_read_hsPt
    (mv sOpt : MoveValue) (chainId : UInt8) (sender contract token : ByteArray) (ekBytesList rcBytesList : List MoveValue)
    (hPoint sVal hsPt ekPt eScalar : MoveValue) :
    (registrationMsAfterPointMulEkE mv sOpt chainId sender contract token ekBytesList rcBytesList hPoint sVal hsPt ekPt
          eScalar).containers.read
        ((registrationMsAfterPointMulSH mv sOpt chainId sender contract token ekBytesList rcBytesList hPoint sVal).containers.alloc
            hsPt).2 =
      some hsPt := by
  let ms := registrationMsAfterPointMulSH mv sOpt chainId sender contract token ekBytesList rcBytesList hPoint sVal
  let cs1 := (ms.containers.alloc hsPt).1
  let rid := (ms.containers.alloc hsPt).2
  let cs2 := (cs1.alloc ekPt).1
  let cs3 := (cs2.alloc eScalar).1
  have h1 : cs1.read rid = some hsPt := containerStore_read_alloc_new ms.containers hsPt
  have h2 : cs2.read rid = some hsPt := containerStore_read_alloc_of_read_some cs1 ekPt rid hsPt h1
  have h3 : cs3.read rid = some hsPt := containerStore_read_alloc_of_read_some cs2 eScalar rid hsPt h2
  simpa [registrationMsAfterPointMulEkE, ms, cs1, cs2, cs3, rid] using h3

/-- After PC 59–62: `e * ek` is stored, then `point_add` combines it with `s * H` (local 17 holds the sum). -/
def registrationMsAfterPointAddLhs
    (mv sOpt : MoveValue) (chainId : UInt8) (sender contract token : ByteArray) (ekBytesList rcBytesList : List MoveValue)
    (hPoint sVal hsPt ekPt eScalar ekePt : MoveValue) : MachineState :=
  let ms := registrationMsAfterPointMulEkE mv sOpt chainId sender contract token ekBytesList rcBytesList hPoint sVal hsPt ekPt
      eScalar
  { ms with containers := (ms.containers.alloc ekePt).1 }

theorem registration_ms_pc63_abstract_output_eq_pointAddLhs
    (mv sOpt : MoveValue) (chainId : UInt8) (sender contract token : ByteArray) (ekBytesList rcBytesList : List MoveValue)
    (hPoint sVal hsPt ekPt eScalar ekePt : MoveValue) :
    { (registrationMsAfterPointMulEkE mv sOpt chainId sender contract token ekBytesList rcBytesList hPoint sVal hsPt ekPt
            eScalar) with
      containers := ((registrationMsAfterPointMulEkE mv sOpt chainId sender contract token ekBytesList rcBytesList hPoint sVal
              hsPt ekPt eScalar).containers.alloc ekePt).1 } =
      registrationMsAfterPointAddLhs mv sOpt chainId sender contract token ekBytesList rcBytesList hPoint sVal hsPt ekPt
        eScalar ekePt := by
  rfl

/-- After PC 63–65: commitment `R` is decompressed to `rhsPt` for the final equality check. -/
def registrationMsAfterPointDecompressRhs
    (mv sOpt : MoveValue) (chainId : UInt8) (sender contract token : ByteArray) (ekBytesList rcBytesList : List MoveValue)
    (rCompressed hPoint sVal hsPt ekPt eScalar ekePt lhsPt _rhsPt : MoveValue) : MachineState :=
  let ms := registrationMsAfterPointAddLhs mv sOpt chainId sender contract token ekBytesList rcBytesList hPoint sVal hsPt ekPt
      eScalar ekePt
  { ms with containers := (ms.containers.alloc rCompressed).1 }

theorem registration_ms_pc66_abstract_output_eq_decompressRhs
    (mv sOpt : MoveValue) (chainId : UInt8) (sender contract token : ByteArray) (ekBytesList rcBytesList : List MoveValue)
    (rCompressed hPoint sVal hsPt ekPt eScalar ekePt lhsPt rhsPt : MoveValue) :
    { (registrationMsAfterPointAddLhs mv sOpt chainId sender contract token ekBytesList rcBytesList hPoint sVal hsPt ekPt
            eScalar ekePt) with
      containers :=
        ((registrationMsAfterPointAddLhs mv sOpt chainId sender contract token ekBytesList rcBytesList hPoint sVal hsPt ekPt
              eScalar ekePt).containers.alloc rCompressed).1 } =
      registrationMsAfterPointDecompressRhs mv sOpt chainId sender contract token ekBytesList rcBytesList rCompressed hPoint
        sVal hsPt ekPt eScalar ekePt lhsPt rhsPt := by
  rfl

/-- Final container store after a successful `verify_registration_proof` return: `point_equals` borrows LHS/RHS. -/
def registrationMsAfterRegistrationReturned
    (mv sOpt : MoveValue) (chainId : UInt8) (sender contract token : ByteArray) (ekBytesList rcBytesList : List MoveValue)
    (rCompressed hPoint sVal hsPt ekPt eScalar ekePt lhsPt rhsPt : MoveValue) : MachineState :=
  let ms := registrationMsAfterPointDecompressRhs mv sOpt chainId sender contract token ekBytesList rcBytesList rCompressed
      hPoint sVal hsPt ekPt eScalar ekePt lhsPt rhsPt
  { ms with containers := ((ms.containers.alloc lhsPt).1.alloc rhsPt).1 }

theorem registration_ms_returned_abstract_output_eq
    (mv sOpt : MoveValue) (chainId : UInt8) (sender contract token : ByteArray) (ekBytesList rcBytesList : List MoveValue)
    (rCompressed hPoint sVal hsPt ekPt eScalar ekePt lhsPt rhsPt : MoveValue) :
    { (registrationMsAfterPointDecompressRhs mv sOpt chainId sender contract token ekBytesList rcBytesList rCompressed hPoint
            sVal hsPt ekPt eScalar ekePt lhsPt rhsPt) with
      containers :=
        (((registrationMsAfterPointDecompressRhs mv sOpt chainId sender contract token ekBytesList rcBytesList rCompressed
                  hPoint sVal hsPt ekPt eScalar ekePt lhsPt rhsPt).containers.alloc lhsPt).1.alloc rhsPt).1 } =
      registrationMsAfterRegistrationReturned mv sOpt chainId sender contract token ekBytesList rcBytesList rCompressed hPoint
        sVal hsPt ekPt eScalar ekePt lhsPt rhsPt := by
  rfl

set_option maxHeartbeats 800000 in
theorem registration_run_pc35_to_pc39_afterTokenMsg
    (o : RegistrationNativeOracle)
    (chainId : UInt8) (sender contract token ekBa commitBa respBa : ByteArray)
    (mv rCompressed sOpt sVal : MoveValue) (ekBytesList : List MoveValue)
    (horacle : o.pubkeyToBytes [.struct_ [.vector .u8 (ekBa.toList.map .u8)]] =
      some [.vector .u8 ekBytesList])
    (fuel : Nat) (_hf : 4 ≤ fuel) :
    run (registrationModuleEnv o)
        ({ registrationFramePc22AfterMoveLoc0 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
              (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa) mv rCompressed sOpt sVal with
            pc := 35 })
        [] [] (registrationMsAfterAppendTokenMsg mv sOpt chainId sender contract token) fuel =
      run (registrationModuleEnv o)
        ({ registrationFramePc22AfterMoveLoc0 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
              (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa) mv rCompressed sOpt sVal with
            pc := 39 })
        [] [] (registrationMsAfterAppendPubkeyMsg mv sOpt chainId sender contract token ekBytesList) (fuel - 4) := by
  have hread4 :
      (registrationMsAfterAppendTokenMsg mv sOpt chainId sender contract token).containers.read 4 =
        some (.vector .u8 (registrationMsgBytesAfterToken mv sOpt chainId sender contract token)) := by
    simp [registrationMsAfterAppendTokenMsg, registrationCsAfterAppendToken_read4]
  have hwrite4 :
      (registrationMsAfterAppendTokenMsg mv sOpt chainId sender contract token).containers.write 4
        (.vector .u8 (registrationMsgBytesAfterToken mv sOpt chainId sender contract token ++ ekBytesList)) =
        some (registrationCsAfterAppendPubkeyBytes mv sOpt chainId sender contract token ekBytesList) := by
    simp [registrationMsAfterAppendTokenMsg, registrationCsAfterAppendPubkeyBytes_write_eq]
  have hmain :=
    registration_run_from_pc35_to_pc39_abstractMs o chainId sender contract token ekBa commitBa respBa
      mv rCompressed sOpt sVal (registrationMsAfterAppendTokenMsg mv sOpt chainId sender contract token)
      ekBytesList (registrationMsgBytesAfterToken mv sOpt chainId sender contract token)
      (registrationCsAfterAppendPubkeyBytes mv sOpt chainId sender contract token ekBytesList) horacle hread4
      hwrite4 fuel _hf
  let fr39 := { registrationFramePc22AfterMoveLoc0 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
        (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa) mv rCompressed sOpt sVal with pc := 39 }
  exact hmain.trans (congrArg (fun ms' =>
      run (registrationModuleEnv o) fr39 [] [] ms' (fuel - 4))
    registration_ms_pc39_abstract_output_eq_appendPubkey)

set_option maxHeartbeats 800000 in
theorem registration_run_pc39_to_pc43_afterPubkeyMsg
    (o : RegistrationNativeOracle)
    (chainId : UInt8) (sender contract token ekBa commitBa respBa : ByteArray)
    (mv rCompressed sOpt sVal : MoveValue) (ekBytesList rcBytesList : List MoveValue)
    (horacle : o.compressedPointToBytes [rCompressed] = some [.vector .u8 rcBytesList])
    (fuel : Nat) (_hf : 4 ≤ fuel) :
    run (registrationModuleEnv o)
        ({ registrationFramePc22AfterMoveLoc0 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
              (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa) mv rCompressed sOpt sVal with
            pc := 39 })
        [] [] (registrationMsAfterAppendPubkeyMsg mv sOpt chainId sender contract token ekBytesList) fuel =
      run (registrationModuleEnv o)
        ({ registrationFramePc22AfterMoveLoc0 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
              (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa) mv rCompressed sOpt sVal with
            pc := 43 })
        [] []
        (registrationMsAfterAppendCompressedPointMsg mv sOpt chainId sender contract token ekBytesList rcBytesList)
        (fuel - 4) := by
  have hread4 :
      (registrationMsAfterAppendPubkeyMsg mv sOpt chainId sender contract token ekBytesList).containers.read 4 =
        some (.vector .u8 (registrationMsgBytesAfterPubkey mv sOpt chainId sender contract token ekBytesList)) := by
    simp [registrationMsAfterAppendPubkeyMsg, registrationCsAfterAppendPubkeyBytes_read4]
  have hwrite4 :
      (registrationMsAfterAppendPubkeyMsg mv sOpt chainId sender contract token ekBytesList).containers.write 4
        (.vector .u8 (registrationMsgBytesAfterPubkey mv sOpt chainId sender contract token ekBytesList ++ rcBytesList)) =
        some (registrationCsAfterAppendCompressedPointBytes mv sOpt chainId sender contract token ekBytesList
          rcBytesList) := by
    simp [registrationMsAfterAppendPubkeyMsg, registrationCsAfterAppendCompressedPointBytes_write_eq]
  have hmain :=
    registration_run_from_pc39_to_pc43_abstractMs o chainId sender contract token ekBa commitBa respBa
      mv rCompressed sOpt sVal (registrationMsAfterAppendPubkeyMsg mv sOpt chainId sender contract token ekBytesList)
      rcBytesList (registrationMsgBytesAfterPubkey mv sOpt chainId sender contract token ekBytesList)
      (registrationCsAfterAppendCompressedPointBytes mv sOpt chainId sender contract token ekBytesList rcBytesList)
      horacle hread4 hwrite4 fuel _hf
  let fr43 := { registrationFramePc22AfterMoveLoc0 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
        (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa) mv rCompressed sOpt sVal with pc := 43 }
  exact hmain.trans (congrArg (fun ms' =>
      run (registrationModuleEnv o) fr43 [] [] ms' (fuel - 4))
    registration_ms_pc43_abstract_output_eq_appendCompressed)

/-- PC 43 → PC 46: `moveLoc 11` loads full FS `msg` from ref 4, SHA2-512 → challenge scalar `eScalar`.

`newScalarFromSha2_512` is the Lean model of the native; the hypothesis ties it to the exact
`registrationMsgBytesForFs` wire (the same bytes the container holds at ref 4). -/
set_option maxHeartbeats 800000 in
theorem registration_run_pc43_to_pc46_afterCompressedPointMsg
    (o : RegistrationNativeOracle)
    (chainId : UInt8) (sender contract token ekBa commitBa respBa : ByteArray)
    (mv rCompressed sOpt sVal : MoveValue) (ekBytesList rcBytesList : List MoveValue) (eScalar : MoveValue)
    (hnative : newScalarFromSha2_512
        [.vector .u8 (registrationMsgBytesForFs mv sOpt chainId sender contract token ekBytesList rcBytesList)] =
      some [eScalar])
    (fuel : Nat) (_hf : 3 ≤ fuel) :
    run (registrationModuleEnv o)
        ({ registrationFramePc22AfterMoveLoc0 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
              (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa) mv rCompressed sOpt sVal with
            pc := 43 })
        [] [] (registrationMsAfterAppendCompressedPointMsg mv sOpt chainId sender contract token ekBytesList rcBytesList)
        fuel =
      run (registrationModuleEnv o)
        (registrationFramePc46AfterStLoc12 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
            (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa) mv rCompressed sOpt sVal
            eScalar)
        [] []
        (registrationMsAfterAppendCompressedPointMsg mv sOpt chainId sender contract token ekBytesList rcBytesList)
        (fuel - 3) := by
  let msgVal :=
    .vector .u8 (registrationMsgBytesForFs mv sOpt chainId sender contract token ekBytesList rcBytesList)
  have hread :
      (registrationMsAfterAppendCompressedPointMsg mv sOpt chainId sender contract token ekBytesList rcBytesList).containers
          .read 4 =
        some msgVal := by
    dsimp [msgVal]
    simp [registrationMsAfterAppendCompressedPointMsg, registrationCsAfterAppendCompressedPointBytes_read4]
  exact registration_run_from_pc43_to_pc46_abstractMs o chainId sender contract token ekBa commitBa respBa
    mv rCompressed sOpt sVal
    (registrationMsAfterAppendCompressedPointMsg mv sOpt chainId sender contract token ekBytesList rcBytesList) msgVal
    eScalar hread hnative fuel _hf

/-- PC 46 → PC 48: `hash_to_point_base` (empty-arg native) stores basis point H in local 13.

`MachineState` is unchanged (only locals / `pc` advance); the oracle hypothesis is the explicit
`hashToPointBase` contract used by the registration transcript. -/
set_option maxHeartbeats 800000 in
theorem registration_run_pc46_to_pc48_afterEStored
    (o : RegistrationNativeOracle)
    (chainId : UInt8) (sender contract token ekBa commitBa respBa : ByteArray)
    (mv rCompressed sOpt sVal : MoveValue) (ekBytesList rcBytesList : List MoveValue) (eScalar hPoint : MoveValue)
    (horacle : o.hashToPointBase [] = some [hPoint])
    (fuel : Nat) (_hf : 2 ≤ fuel) :
    run (registrationModuleEnv o)
        ({ registrationFramePc46AfterStLoc12 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
              (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa) mv rCompressed sOpt sVal
              eScalar with pc := 46 })
        [] [] (registrationMsAfterAppendCompressedPointMsg mv sOpt chainId sender contract token ekBytesList rcBytesList)
        fuel =
      run (registrationModuleEnv o)
        (registrationFramePc48AfterStLoc13 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
            (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa) mv rCompressed sOpt sVal
            eScalar hPoint)
        [] [] (registrationMsAfterAppendCompressedPointMsg mv sOpt chainId sender contract token ekBytesList rcBytesList)
        (fuel - 2) := by
  exact registration_run_from_pc46_to_pc48_abstractMs o chainId sender contract token ekBa commitBa respBa
    mv rCompressed sOpt sVal eScalar
    (registrationMsAfterAppendCompressedPointMsg mv sOpt chainId sender contract token ekBytesList rcBytesList) hPoint
    horacle fuel _hf

/-- PC 48 → PC 51: load EK wire, `pubkey_to_point`, store curve point in local 14. -/
set_option maxHeartbeats 800000 in
theorem registration_run_pc48_to_pc51_afterHStored
    (o : RegistrationNativeOracle)
    (chainId : UInt8) (sender contract token ekBa commitBa respBa : ByteArray)
    (mv rCompressed sOpt sVal eScalar hPoint ekPt : MoveValue) (ekBytesList rcBytesList : List MoveValue)
    (horacle : o.pubkeyToPoint [.struct_ [.vector .u8 (ekBa.toList.map .u8)]] = some [ekPt])
    (fuel : Nat) (_hf : 3 ≤ fuel) :
    run (registrationModuleEnv o)
        ({ registrationFramePc48AfterStLoc13 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
              (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa) mv rCompressed sOpt sVal
              eScalar hPoint with pc := 48 })
        [] [] (registrationMsAfterAppendCompressedPointMsg mv sOpt chainId sender contract token ekBytesList rcBytesList)
        fuel =
      run (registrationModuleEnv o)
        (registrationFramePc51AfterStLoc14 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
            (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa) mv rCompressed sOpt sVal
            eScalar hPoint ekPt)
        [] [] (registrationMsAfterAppendCompressedPointMsg mv sOpt chainId sender contract token ekBytesList rcBytesList)
        (fuel - 3) := by
  exact registration_run_from_pc48_to_pc51_abstractMs o chainId sender contract token ekBa commitBa respBa
    mv rCompressed sOpt sVal eScalar hPoint
    (registrationMsAfterAppendCompressedPointMsg mv sOpt chainId sender contract token ekBytesList rcBytesList) ekPt
    horacle fuel _hf

/-- PC 51 → PC 55: `s * H` via `point_mul` after EK is a curve point (local 14). -/
set_option maxHeartbeats 800000 in
theorem registration_run_pc51_to_pc55_afterEkPtStored
    (o : RegistrationNativeOracle)
    (chainId : UInt8) (sender contract token ekBa commitBa respBa : ByteArray)
    (mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt : MoveValue) (ekBytesList rcBytesList : List MoveValue)
    (hmul : o.pointMul [hPoint, sVal] = some [hsPt])
    (fuel : Nat) (_hf : 4 ≤ fuel) :
    run (registrationModuleEnv o)
        ({ registrationFramePc51AfterStLoc14 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
              (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa) mv rCompressed sOpt sVal
              eScalar hPoint ekPt with pc := 51 })
        [] [] (registrationMsAfterAppendCompressedPointMsg mv sOpt chainId sender contract token ekBytesList rcBytesList)
        fuel =
      run (registrationModuleEnv o)
        (registrationFramePc55AfterStLoc15 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
            (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa) mv rCompressed sOpt sVal
            eScalar hPoint ekPt hsPt)
        [] [] (registrationMsAfterPointMulSH mv sOpt chainId sender contract token ekBytesList rcBytesList hPoint sVal)
        (fuel - 4) := by
  simpa [registration_ms_pc55_abstract_output_eq_pointMulSH] using
    registration_run_from_pc51_to_pc55_abstractMs o chainId sender contract token ekBa commitBa respBa
      mv rCompressed sOpt sVal eScalar hPoint ekPt
      (registrationMsAfterAppendCompressedPointMsg mv sOpt chainId sender contract token ekBytesList rcBytesList) hsPt
      hmul fuel _hf

/-- PC 55 → PC 59: `e * ek` (`point_mul` on EK and Fiat–Shamir challenge). -/
set_option maxHeartbeats 800000 in
theorem registration_run_pc55_to_pc59_afterSHStored
    (o : RegistrationNativeOracle)
    (chainId : UInt8) (sender contract token ekBa commitBa respBa : ByteArray)
    (mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt : MoveValue) (ekBytesList rcBytesList : List MoveValue)
    (hemul : o.pointMul [ekPt, eScalar] = some [ekePt])
    (fuel : Nat) (_hf : 4 ≤ fuel) :
    run (registrationModuleEnv o)
        ({ registrationFramePc55AfterStLoc15 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
              (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa) mv rCompressed sOpt sVal
              eScalar hPoint ekPt hsPt with pc := 55 })
        [] [] (registrationMsAfterPointMulSH mv sOpt chainId sender contract token ekBytesList rcBytesList hPoint sVal)
        fuel =
      run (registrationModuleEnv o)
        ({ registrationFramePc58AfterImmBorrow12 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
              (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa) mv rCompressed sOpt sVal
              eScalar hPoint ekPt hsPt with pc := 59 })
        [] [ekePt, .immRef
            ((registrationMsAfterPointMulSH mv sOpt chainId sender contract token ekBytesList rcBytesList hPoint sVal).containers.alloc
                hsPt).2]
        (registrationMsAfterPointMulEkE mv sOpt chainId sender contract token ekBytesList rcBytesList hPoint sVal hsPt ekPt
          eScalar)
        (fuel - 4) := by
  simpa [registration_ms_pc59_abstract_output_eq_pointMulEkE] using
    registration_run_from_pc55_to_pc59_abstractMs o chainId sender contract token ekBa commitBa respBa
      mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt
      (registrationMsAfterPointMulSH mv sOpt chainId sender contract token ekBytesList rcBytesList hPoint sVal) ekePt
      hemul fuel _hf

/-- PC 59 → PC 63: `point_add` yields the Schnorr LHS; local 17 holds `lhsPt`. -/
set_option maxHeartbeats 800000 in
theorem registration_run_pc59_to_pc63_afterEkEStack
    (o : RegistrationNativeOracle)
    (chainId : UInt8) (sender contract token ekBa commitBa respBa : ByteArray)
    (mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt : MoveValue) (ekBytesList rcBytesList : List MoveValue)
    (hadd : o.pointAdd [hsPt, ekePt] = some [lhsPt])
    (fuel : Nat) (_hf : 4 ≤ fuel) :
    run (registrationModuleEnv o)
        ({ registrationFramePc58AfterImmBorrow12 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
              (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa) mv rCompressed sOpt sVal
              eScalar hPoint ekPt hsPt with pc := 59 })
        [] [ekePt, .immRef
            ((registrationMsAfterPointMulSH mv sOpt chainId sender contract token ekBytesList rcBytesList hPoint sVal).containers.alloc
                hsPt).2]
        (registrationMsAfterPointMulEkE mv sOpt chainId sender contract token ekBytesList rcBytesList hPoint sVal hsPt ekPt
          eScalar)
        fuel =
      run (registrationModuleEnv o)
        (registrationFramePc63AfterStLoc17 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
            (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa) mv rCompressed sOpt sVal
            eScalar hPoint ekPt hsPt ekePt lhsPt)
        [] [] (registrationMsAfterPointAddLhs mv sOpt chainId sender contract token ekBytesList rcBytesList hPoint sVal hsPt
            ekPt eScalar ekePt)
        (fuel - 4) := by
  have hread :=
    registration_ms_pointMulEkE_read_hsPt mv sOpt chainId sender contract token ekBytesList rcBytesList hPoint sVal hsPt ekPt
      eScalar
  simpa [registration_ms_pc63_abstract_output_eq_pointAddLhs] using
    registration_run_from_pc59_to_pc63_abstractMs o chainId sender contract token ekBa commitBa respBa
      mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt
      (registrationMsAfterPointMulEkE mv sOpt chainId sender contract token ekBytesList rcBytesList hPoint sVal hsPt ekPt
        eScalar)
      ((registrationMsAfterPointMulSH mv sOpt chainId sender contract token ekBytesList rcBytesList hPoint sVal).containers.alloc
          hsPt).2
      hread hadd fuel _hf

/-- PC 63 → PC 66: decompress commitment `R` to an affine point for `point_equals`. -/
set_option maxHeartbeats 800000 in
theorem registration_run_pc63_to_pc66_afterLhsStored
    (o : RegistrationNativeOracle)
    (chainId : UInt8) (sender contract token ekBa commitBa respBa : ByteArray)
    (mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt rhsPt : MoveValue) (ekBytesList rcBytesList : List MoveValue)
    (hdec : o.pointDecompress [rCompressed] = some [rhsPt])
    (fuel : Nat) (_hf : 3 ≤ fuel) :
    run (registrationModuleEnv o)
        (registrationFramePc63AfterStLoc17 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
            (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa) mv rCompressed sOpt sVal
            eScalar hPoint ekPt hsPt ekePt lhsPt)
        [] [] (registrationMsAfterPointAddLhs mv sOpt chainId sender contract token ekBytesList rcBytesList hPoint sVal hsPt ekPt
            eScalar ekePt)
        fuel =
      run (registrationModuleEnv o)
        (registrationFramePc66AfterStLoc18 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
            (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa) mv rCompressed sOpt sVal eScalar
            hPoint ekPt hsPt ekePt lhsPt rhsPt)
        [] []
        (registrationMsAfterPointDecompressRhs mv sOpt chainId sender contract token ekBytesList rcBytesList rCompressed hPoint
            sVal hsPt ekPt eScalar ekePt lhsPt rhsPt)
        (fuel - 3) := by
  simpa [registration_ms_pc66_abstract_output_eq_decompressRhs] using
    registration_run_from_pc63_to_pc66_abstractMs o chainId sender contract token ekBa commitBa respBa
      mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt rhsPt
      (registrationMsAfterPointAddLhs mv sOpt chainId sender contract token ekBytesList rcBytesList hPoint sVal hsPt ekPt
        eScalar ekePt)
      hdec fuel _hf

/-- PC 66 → returned: `point_equals` true, then `ret` (successful verification). -/
set_option maxHeartbeats 800000 in
theorem registration_run_pc66_to_returned_afterDecompress
    (o : RegistrationNativeOracle)
    (chainId : UInt8) (sender contract token ekBa commitBa respBa : ByteArray)
    (mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt rhsPt : MoveValue) (ekBytesList rcBytesList : List MoveValue)
    (heq : o.pointEquals [lhsPt, rhsPt] = some [.bool true])
    (fuel : Nat) (_hf : 5 ≤ fuel) :
    run (registrationModuleEnv o)
        (registrationFramePc66AfterStLoc18 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
            (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa) mv rCompressed sOpt sVal eScalar
            hPoint ekPt hsPt ekePt lhsPt rhsPt)
        [] []
        (registrationMsAfterPointDecompressRhs mv sOpt chainId sender contract token ekBytesList rcBytesList rCompressed hPoint
            sVal hsPt ekPt eScalar ekePt lhsPt rhsPt)
        fuel =
      ExecResult.returned [] (registrationMsAfterRegistrationReturned mv sOpt chainId sender contract token ekBytesList
          rcBytesList rCompressed hPoint sVal hsPt ekPt eScalar ekePt lhsPt rhsPt) := by
  simpa [registration_ms_returned_abstract_output_eq] using
    registration_run_from_pc66_to_returned_abstractMs o chainId sender contract token ekBa commitBa respBa
      mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt rhsPt
      (registrationMsAfterPointDecompressRhs mv sOpt chainId sender contract token ekBytesList rcBytesList rCompressed hPoint
        sVal hsPt ekPt eScalar ekePt lhsPt rhsPt)
      heq fuel _hf

set_option maxHeartbeats 800000 in
theorem registration_run_pc31_to_pc35_afterAppendContract
    (o : RegistrationNativeOracle)
    (chainId : UInt8) (sender contract token ekBa commitBa respBa : ByteArray)
    (mv rCompressed sOpt sVal : MoveValue)
    (fuel : Nat) (_hf : 4 ≤ fuel) :
    run (registrationModuleEnv o)
        ({ registrationFramePc22AfterMoveLoc0 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
              (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa) mv rCompressed sOpt sVal with
            pc := 31 })
        [] [] (registrationMsAfterAppendContract mv sOpt chainId sender contract) fuel =
      run (registrationModuleEnv o)
        ({ registrationFramePc33AfterImmBorrow4 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
              (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa) mv rCompressed sOpt sVal with
            pc := 35 })
        [] [] (registrationMsAfterAppendTokenMsg mv sOpt chainId sender contract token) (fuel - 4) := by
  let existing :=
    ((fiatShamirRegistrationDstBytesList ++ [.u8 chainId]) ++ sender.toList.map .u8) ++
      contract.toList.map .u8
  have hread4 :=
    registrationMsAfterAppendContract_alloc_token_read4 mv sOpt chainId sender contract token
  have hread4' :
      ((registrationMsAfterAppendContract mv sOpt chainId sender contract).containers.alloc
          (.address token)).1.read 4 =
        some (.vector .u8 existing) := by
    simpa [existing] using hread4
  have hwrite4 :=
    registrationMsAfterAppendContract_alloc_token_write4 mv sOpt chainId sender contract token
  have hwrite4' :
      ((registrationMsAfterAppendContract mv sOpt chainId sender contract).containers.alloc
          (.address token)).1.write 4
        (.vector .u8 (existing ++ token.toList.map .u8)) =
        some (registrationCsAfterAppendToken mv sOpt chainId sender contract token) := by
    simpa [existing, List.append_assoc] using hwrite4
  have hmain :=
    registration_run_from_pc31_to_pc35_abstractMs o chainId sender contract token ekBa commitBa respBa
      mv rCompressed sOpt sVal (registrationMsAfterAppendContract mv sOpt chainId sender contract)
      existing (registrationCsAfterAppendToken mv sOpt chainId sender contract token) hread4' hwrite4'
      fuel _hf
  let fr35 := { registrationFramePc33AfterImmBorrow4 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
        (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa) mv rCompressed sOpt sVal with pc := 35 }
  exact hmain.trans (congrArg (fun ms' =>
      run (registrationModuleEnv o) fr35 [] [] ms' (fuel - 4))
    registration_ms_pc35_nested_record_eq_single)

/-- Extends `registration_run_pc2_to_pc20_happyPath` through the `msg`-buffer construction
chain (PC 20–30): alloc `msg` ref 4, push `chainId`, append BCS(sender), append BCS(contract)
to arrive at PC 31 with stack `[]` and ref 4 holding `DST ++ [chainId] ++ BCS(sender) ++ BCS(contract)`. -/
theorem registration_run_pc2_to_pc31_happyPath
    (o : RegistrationNativeOracle)
    (chainId : UInt8) (sender contract token ekBa commitBa respBa : ByteArray)
    (mv rCompressed sOpt sVal : MoveValue) (rest srest' : List MoveValue)
    (hmv : mv = .struct_ (.bool true :: rCompressed :: rest))
    (hsOpt : sOpt = .struct_ (.bool true :: sVal :: srest'))
    (hsc : o.newScalarFromBytes [.vector .u8 (respBa.toList.map .u8)] = some [sOpt])
    (fuel : Nat) (hf : 31 ≤ fuel) :
    run (registrationModuleEnv o)
        (registrationFrameAtPc2 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
          (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa))
        [] [mv] MachineState.empty (fuel - 2) =
      run (registrationModuleEnv o)
        ({ registrationFramePc22AfterMoveLoc0 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
              (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa) mv rCompressed sOpt sVal with
            pc := 31 })
        [] [] (registrationMsAfterAppendContract mv sOpt chainId sender contract) (fuel - 31) := by
  have h1 := registration_run_pc2_to_pc20_happyPath o chainId sender contract token ekBa commitBa respBa
    mv rCompressed sOpt sVal rest srest' hmv hsOpt hsc fuel (by omega)
  have h2 := registration_run_from_pc20_to_pc22_path o chainId sender contract token ekBa commitBa respBa
    mv rCompressed sOpt sVal (fuel - 20) (by omega)
  have h3 := registration_run_from_pc22_to_pc25_path o chainId sender contract token ekBa commitBa respBa
    mv rCompressed sOpt sVal (fuel - 22) (by omega)
  have h4 := registration_run_from_pc25_to_pc28_path o chainId sender contract token ekBa commitBa respBa
    mv rCompressed sOpt sVal (fuel - 25) (by omega)
  have h5 := registration_run_from_pc28_to_pc31_path o chainId sender contract token ekBa commitBa respBa
    mv rCompressed sOpt sVal (fuel - 28) (by omega)
  rw [h1, h2]
  rw [show (fuel - 20) - 2 = fuel - 22 from by omega]
  rw [h3]
  rw [show (fuel - 22) - 3 = fuel - 25 from by omega]
  rw [h4]
  rw [show (fuel - 25) - 3 = fuel - 28 from by omega]
  rw [h5]
  rw [show (fuel - 28) - 3 = fuel - 31 from by omega]

/-- PC 2 → PC 35 on the registration happy path: `msg` at ref 4 includes `BCS(token)`.

Composed by **transitivity** of `registration_run_pc2_to_pc31_happyPath` and
`registration_run_pc31_to_pc35_afterAppendContract` so Lean never has to unify the abstract-MS
output of `registration_run_from_pc31_to_pc35_abstractMs` with `registrationMsAfterAppendContract`
in a single `whnf` step (the failure mode described below). -/
theorem registration_run_pc2_to_pc35_happyPath
    (o : RegistrationNativeOracle)
    (chainId : UInt8) (sender contract token ekBa commitBa respBa : ByteArray)
    (mv rCompressed sOpt sVal : MoveValue) (rest srest' : List MoveValue)
    (hmv : mv = .struct_ (.bool true :: rCompressed :: rest))
    (hsOpt : sOpt = .struct_ (.bool true :: sVal :: srest'))
    (hsc : o.newScalarFromBytes [.vector .u8 (respBa.toList.map .u8)] = some [sOpt])
    (fuel : Nat) (hf : 35 ≤ fuel) :
    run (registrationModuleEnv o)
        (registrationFrameAtPc2 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
          (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa))
        [] [mv] MachineState.empty (fuel - 2) =
      run (registrationModuleEnv o)
        ({ registrationFramePc33AfterImmBorrow4 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
              (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa) mv rCompressed sOpt sVal with
            pc := 35 })
        [] [] (registrationMsAfterAppendTokenMsg mv sOpt chainId sender contract token) (fuel - 35) := by
  have hf31 : 31 ≤ fuel := by omega
  have h31 := registration_run_pc2_to_pc31_happyPath o chainId sender contract token ekBa commitBa respBa
    mv rCompressed sOpt sVal rest srest' hmv hsOpt hsc fuel hf31
  have hf35 : 4 ≤ fuel - 31 := by omega
  have h35 := registration_run_pc31_to_pc35_afterAppendContract o chainId sender contract token ekBa commitBa respBa
    mv rCompressed sOpt sVal (fuel - 31) hf35
  exact h31.trans h35

/-- PC 2 → PC 39: through PC 35 then `pubkey_to_bytes` + append EK bytes to `msg`. -/
theorem registration_run_pc2_to_pc39_happyPath
    (o : RegistrationNativeOracle)
    (chainId : UInt8) (sender contract token ekBa commitBa respBa : ByteArray)
    (mv rCompressed sOpt sVal : MoveValue) (rest srest' : List MoveValue)
    (ekBytesList : List MoveValue)
    (hmv : mv = .struct_ (.bool true :: rCompressed :: rest))
    (hsOpt : sOpt = .struct_ (.bool true :: sVal :: srest'))
    (hsc : o.newScalarFromBytes [.vector .u8 (respBa.toList.map .u8)] = some [sOpt])
    (horacle : o.pubkeyToBytes [.struct_ [.vector .u8 (ekBa.toList.map .u8)]] =
      some [.vector .u8 ekBytesList])
    (fuel : Nat) (hf : 39 ≤ fuel) :
    run (registrationModuleEnv o)
        (registrationFrameAtPc2 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
          (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa))
        [] [mv] MachineState.empty (fuel - 2) =
      run (registrationModuleEnv o)
        ({ registrationFramePc22AfterMoveLoc0 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
              (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa) mv rCompressed sOpt sVal with
            pc := 39 })
        [] [] (registrationMsAfterAppendPubkeyMsg mv sOpt chainId sender contract token ekBytesList) (fuel - 39) := by
  have hf35 : 35 ≤ fuel := by omega
  have h235 := registration_run_pc2_to_pc35_happyPath o chainId sender contract token ekBa commitBa respBa
    mv rCompressed sOpt sVal rest srest' hmv hsOpt hsc fuel hf35
  have hf39 : 4 ≤ fuel - 35 := by omega
  have h3539 := registration_run_pc35_to_pc39_afterTokenMsg o chainId sender contract token ekBa commitBa respBa
    mv rCompressed sOpt sVal ekBytesList horacle (fuel - 35) hf39
  exact h235.trans h3539

/-- PC 2 → PC 43: through PC 39 then `compressed_point_to_bytes` + append commitment bytes to `msg`. -/
theorem registration_run_pc2_to_pc43_happyPath
    (o : RegistrationNativeOracle)
    (chainId : UInt8) (sender contract token ekBa commitBa respBa : ByteArray)
    (mv rCompressed sOpt sVal : MoveValue) (rest srest' : List MoveValue)
    (ekBytesList rcBytesList : List MoveValue)
    (hmv : mv = .struct_ (.bool true :: rCompressed :: rest))
    (hsOpt : sOpt = .struct_ (.bool true :: sVal :: srest'))
    (hsc : o.newScalarFromBytes [.vector .u8 (respBa.toList.map .u8)] = some [sOpt])
    (horacle : o.pubkeyToBytes [.struct_ [.vector .u8 (ekBa.toList.map .u8)]] =
      some [.vector .u8 ekBytesList])
    (hcompress : o.compressedPointToBytes [rCompressed] = some [.vector .u8 rcBytesList])
    (fuel : Nat) (hf : 43 ≤ fuel) :
    run (registrationModuleEnv o)
        (registrationFrameAtPc2 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
          (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa))
        [] [mv] MachineState.empty (fuel - 2) =
      run (registrationModuleEnv o)
        ({ registrationFramePc22AfterMoveLoc0 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
              (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa) mv rCompressed sOpt sVal with
            pc := 43 })
        [] []
        (registrationMsAfterAppendCompressedPointMsg mv sOpt chainId sender contract token ekBytesList rcBytesList)
        (fuel - 43) := by
  have hf39 : 39 ≤ fuel := by omega
  have h239 := registration_run_pc2_to_pc39_happyPath o chainId sender contract token ekBa commitBa respBa
    mv rCompressed sOpt sVal rest srest' ekBytesList hmv hsOpt hsc horacle fuel hf39
  have hf43 : 4 ≤ fuel - 39 := by omega
  have h3943 := registration_run_pc39_to_pc43_afterPubkeyMsg o chainId sender contract token ekBa commitBa respBa
    mv rCompressed sOpt sVal ekBytesList rcBytesList hcompress (fuel - 39) hf43
  exact h239.trans h3943

/-- PC 2 → PC 46: through PC 43 then SHA2-512 on `registrationMsgBytesForFs` yields `eScalar`. -/
theorem registration_run_pc2_to_pc46_happyPath
    (o : RegistrationNativeOracle)
    (chainId : UInt8) (sender contract token ekBa commitBa respBa : ByteArray)
    (mv rCompressed sOpt sVal : MoveValue) (rest srest' : List MoveValue)
    (ekBytesList rcBytesList : List MoveValue) (eScalar : MoveValue)
    (hmv : mv = .struct_ (.bool true :: rCompressed :: rest))
    (hsOpt : sOpt = .struct_ (.bool true :: sVal :: srest'))
    (hsc : o.newScalarFromBytes [.vector .u8 (respBa.toList.map .u8)] = some [sOpt])
    (horacle : o.pubkeyToBytes [.struct_ [.vector .u8 (ekBa.toList.map .u8)]] =
      some [.vector .u8 ekBytesList])
    (hcompress : o.compressedPointToBytes [rCompressed] = some [.vector .u8 rcBytesList])
    (hnative : newScalarFromSha2_512
        [.vector .u8 (registrationMsgBytesForFs mv sOpt chainId sender contract token ekBytesList rcBytesList)] =
      some [eScalar])
    (fuel : Nat) (hf : 46 ≤ fuel) :
    run (registrationModuleEnv o)
        (registrationFrameAtPc2 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
          (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa))
        [] [mv] MachineState.empty (fuel - 2) =
      run (registrationModuleEnv o)
        (registrationFramePc46AfterStLoc12 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
            (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa) mv rCompressed sOpt sVal
            eScalar)
        [] []
        (registrationMsAfterAppendCompressedPointMsg mv sOpt chainId sender contract token ekBytesList rcBytesList)
        (fuel - 46) := by
  have hf43 : 43 ≤ fuel := by omega
  have h243 := registration_run_pc2_to_pc43_happyPath o chainId sender contract token ekBa commitBa respBa
    mv rCompressed sOpt sVal rest srest' ekBytesList rcBytesList hmv hsOpt hsc horacle hcompress fuel hf43
  have hf46 : 3 ≤ fuel - 43 := by omega
  have h4346 := registration_run_pc43_to_pc46_afterCompressedPointMsg o chainId sender contract token ekBa commitBa respBa
    mv rCompressed sOpt sVal ekBytesList rcBytesList eScalar hnative (fuel - 43) hf46
  exact h243.trans h4346

/-- PC 2 → PC 48: adds `hash_to_point_base` (basis H) after the FS challenge scalar is stored. -/
theorem registration_run_pc2_to_pc48_happyPath
    (o : RegistrationNativeOracle)
    (chainId : UInt8) (sender contract token ekBa commitBa respBa : ByteArray)
    (mv rCompressed sOpt sVal : MoveValue) (rest srest' : List MoveValue)
    (ekBytesList rcBytesList : List MoveValue) (eScalar hPoint : MoveValue)
    (hmv : mv = .struct_ (.bool true :: rCompressed :: rest))
    (hsOpt : sOpt = .struct_ (.bool true :: sVal :: srest'))
    (hsc : o.newScalarFromBytes [.vector .u8 (respBa.toList.map .u8)] = some [sOpt])
    (horacle : o.pubkeyToBytes [.struct_ [.vector .u8 (ekBa.toList.map .u8)]] =
      some [.vector .u8 ekBytesList])
    (hcompress : o.compressedPointToBytes [rCompressed] = some [.vector .u8 rcBytesList])
    (hnative : newScalarFromSha2_512
        [.vector .u8 (registrationMsgBytesForFs mv sOpt chainId sender contract token ekBytesList rcBytesList)] =
      some [eScalar])
    (hhash : o.hashToPointBase [] = some [hPoint])
    (fuel : Nat) (hf : 48 ≤ fuel) :
    run (registrationModuleEnv o)
        (registrationFrameAtPc2 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
          (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa))
        [] [mv] MachineState.empty (fuel - 2) =
      run (registrationModuleEnv o)
        (registrationFramePc48AfterStLoc13 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
            (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa) mv rCompressed sOpt sVal
            eScalar hPoint)
        [] []
        (registrationMsAfterAppendCompressedPointMsg mv sOpt chainId sender contract token ekBytesList rcBytesList)
        (fuel - 48) := by
  have hf46 : 46 ≤ fuel := by omega
  have h246 := registration_run_pc2_to_pc46_happyPath o chainId sender contract token ekBa commitBa respBa
    mv rCompressed sOpt sVal rest srest' ekBytesList rcBytesList eScalar hmv hsOpt hsc horacle hcompress hnative fuel
    hf46
  have hf48 : 2 ≤ fuel - 46 := by omega
  have h4648 := registration_run_pc46_to_pc48_afterEStored o chainId sender contract token ekBa commitBa respBa
    mv rCompressed sOpt sVal ekBytesList rcBytesList eScalar hPoint hhash (fuel - 46) hf48
  exact h246.trans h4648

/-- PC 2 → PC 51: after PC 48, `pubkey_to_point` stores the EK as a curve point (local 14). -/
theorem registration_run_pc2_to_pc51_happyPath
    (o : RegistrationNativeOracle)
    (chainId : UInt8) (sender contract token ekBa commitBa respBa : ByteArray)
    (mv rCompressed sOpt sVal : MoveValue) (rest srest' : List MoveValue)
    (ekBytesList rcBytesList : List MoveValue) (eScalar hPoint ekPt : MoveValue)
    (hmv : mv = .struct_ (.bool true :: rCompressed :: rest))
    (hsOpt : sOpt = .struct_ (.bool true :: sVal :: srest'))
    (hsc : o.newScalarFromBytes [.vector .u8 (respBa.toList.map .u8)] = some [sOpt])
    (horacle : o.pubkeyToBytes [.struct_ [.vector .u8 (ekBa.toList.map .u8)]] =
      some [.vector .u8 ekBytesList])
    (hcompress : o.compressedPointToBytes [rCompressed] = some [.vector .u8 rcBytesList])
    (hnative : newScalarFromSha2_512
        [.vector .u8 (registrationMsgBytesForFs mv sOpt chainId sender contract token ekBytesList rcBytesList)] =
      some [eScalar])
    (hhash : o.hashToPointBase [] = some [hPoint])
    (hekp : o.pubkeyToPoint [.struct_ [.vector .u8 (ekBa.toList.map .u8)]] = some [ekPt])
    (fuel : Nat) (hf : 51 ≤ fuel) :
    run (registrationModuleEnv o)
        (registrationFrameAtPc2 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
          (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa))
        [] [mv] MachineState.empty (fuel - 2) =
      run (registrationModuleEnv o)
        (registrationFramePc51AfterStLoc14 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
            (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa) mv rCompressed sOpt sVal
            eScalar hPoint ekPt)
        [] []
        (registrationMsAfterAppendCompressedPointMsg mv sOpt chainId sender contract token ekBytesList rcBytesList)
        (fuel - 51) := by
  have hf48 : 48 ≤ fuel := by omega
  have h248 := registration_run_pc2_to_pc48_happyPath o chainId sender contract token ekBa commitBa respBa
    mv rCompressed sOpt sVal rest srest' ekBytesList rcBytesList eScalar hPoint hmv hsOpt hsc horacle hcompress hnative
    hhash fuel hf48
  have hf51 : 3 ≤ fuel - 48 := by omega
  have h4851 := registration_run_pc48_to_pc51_afterHStored o chainId sender contract token ekBa commitBa respBa
    mv rCompressed sOpt sVal eScalar hPoint ekPt ekBytesList rcBytesList hekp (fuel - 48) hf51
  exact h248.trans h4851

/-- PC 2 → PC 55: Fiat–Shamir `H`, EK as point, then `s * H` stored (local 15). -/
theorem registration_run_pc2_to_pc55_happyPath
    (o : RegistrationNativeOracle)
    (chainId : UInt8) (sender contract token ekBa commitBa respBa : ByteArray)
    (mv rCompressed sOpt sVal : MoveValue) (rest srest' : List MoveValue)
    (ekBytesList rcBytesList : List MoveValue) (eScalar hPoint ekPt hsPt : MoveValue)
    (hmv : mv = .struct_ (.bool true :: rCompressed :: rest))
    (hsOpt : sOpt = .struct_ (.bool true :: sVal :: srest'))
    (hsc : o.newScalarFromBytes [.vector .u8 (respBa.toList.map .u8)] = some [sOpt])
    (horacle : o.pubkeyToBytes [.struct_ [.vector .u8 (ekBa.toList.map .u8)]] =
      some [.vector .u8 ekBytesList])
    (hcompress : o.compressedPointToBytes [rCompressed] = some [.vector .u8 rcBytesList])
    (hnative : newScalarFromSha2_512
        [.vector .u8 (registrationMsgBytesForFs mv sOpt chainId sender contract token ekBytesList rcBytesList)] =
      some [eScalar])
    (hhash : o.hashToPointBase [] = some [hPoint])
    (hekp : o.pubkeyToPoint [.struct_ [.vector .u8 (ekBa.toList.map .u8)]] = some [ekPt])
    (hmul : o.pointMul [hPoint, sVal] = some [hsPt])
    (fuel : Nat) (hf : 55 ≤ fuel) :
    run (registrationModuleEnv o)
        (registrationFrameAtPc2 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
          (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa))
        [] [mv] MachineState.empty (fuel - 2) =
      run (registrationModuleEnv o)
        (registrationFramePc55AfterStLoc15 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
            (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa) mv rCompressed sOpt sVal
            eScalar hPoint ekPt hsPt)
        [] []
        (registrationMsAfterPointMulSH mv sOpt chainId sender contract token ekBytesList rcBytesList hPoint sVal)
        (fuel - 55) := by
  have hf51 : 51 ≤ fuel := by omega
  have h251 := registration_run_pc2_to_pc51_happyPath o chainId sender contract token ekBa commitBa respBa
    mv rCompressed sOpt sVal rest srest' ekBytesList rcBytesList eScalar hPoint ekPt hmv hsOpt hsc horacle hcompress
    hnative hhash hekp fuel hf51
  have hf55 : 4 ≤ fuel - 51 := by omega
  have h5155 := registration_run_pc51_to_pc55_afterEkPtStored o chainId sender contract token ekBa commitBa respBa
    mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekBytesList rcBytesList hmul (fuel - 51) hf55
  exact h251.trans h5155

/-- PC 2 → PC 59: through `s * H` then `e * ek` on the stack at PC 59. -/
theorem registration_run_pc2_to_pc59_happyPath
    (o : RegistrationNativeOracle)
    (chainId : UInt8) (sender contract token ekBa commitBa respBa : ByteArray)
    (mv rCompressed sOpt sVal : MoveValue) (rest srest' : List MoveValue)
    (ekBytesList rcBytesList : List MoveValue) (eScalar hPoint ekPt hsPt ekePt : MoveValue)
    (hmv : mv = .struct_ (.bool true :: rCompressed :: rest))
    (hsOpt : sOpt = .struct_ (.bool true :: sVal :: srest'))
    (hsc : o.newScalarFromBytes [.vector .u8 (respBa.toList.map .u8)] = some [sOpt])
    (horacle : o.pubkeyToBytes [.struct_ [.vector .u8 (ekBa.toList.map .u8)]] =
      some [.vector .u8 ekBytesList])
    (hcompress : o.compressedPointToBytes [rCompressed] = some [.vector .u8 rcBytesList])
    (hnative : newScalarFromSha2_512
        [.vector .u8 (registrationMsgBytesForFs mv sOpt chainId sender contract token ekBytesList rcBytesList)] =
      some [eScalar])
    (hhash : o.hashToPointBase [] = some [hPoint])
    (hekp : o.pubkeyToPoint [.struct_ [.vector .u8 (ekBa.toList.map .u8)]] = some [ekPt])
    (hmulSH : o.pointMul [hPoint, sVal] = some [hsPt])
    (hmulEkE : o.pointMul [ekPt, eScalar] = some [ekePt])
    (fuel : Nat) (hf : 59 ≤ fuel) :
    run (registrationModuleEnv o)
        (registrationFrameAtPc2 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
          (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa))
        [] [mv] MachineState.empty (fuel - 2) =
      run (registrationModuleEnv o)
        ({ registrationFramePc58AfterImmBorrow12 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
              (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa) mv rCompressed sOpt sVal
              eScalar hPoint ekPt hsPt with pc := 59 })
        [] [ekePt, .immRef
            ((registrationMsAfterPointMulSH mv sOpt chainId sender contract token ekBytesList rcBytesList hPoint sVal).containers.alloc
                hsPt).2]
        (registrationMsAfterPointMulEkE mv sOpt chainId sender contract token ekBytesList rcBytesList hPoint sVal hsPt ekPt
          eScalar)
        (fuel - 59) := by
  have hf55 : 55 ≤ fuel := by omega
  have h255 := registration_run_pc2_to_pc55_happyPath o chainId sender contract token ekBa commitBa respBa
    mv rCompressed sOpt sVal rest srest' ekBytesList rcBytesList eScalar hPoint ekPt hsPt hmv hsOpt hsc horacle hcompress
    hnative hhash hekp hmulSH fuel hf55
  have hf59 : 4 ≤ fuel - 55 := by omega
  have h5559 := registration_run_pc55_to_pc59_afterSHStored o chainId sender contract token ekBa commitBa respBa
    mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt ekBytesList rcBytesList hmulEkE (fuel - 55) hf59
  exact h255.trans h5559

/-- PC 2 → PC 63: Schnorr LHS `s*H + e*ek` accumulated into local 17. -/
theorem registration_run_pc2_to_pc63_happyPath
    (o : RegistrationNativeOracle)
    (chainId : UInt8) (sender contract token ekBa commitBa respBa : ByteArray)
    (mv rCompressed sOpt sVal : MoveValue) (rest srest' : List MoveValue)
    (ekBytesList rcBytesList : List MoveValue) (eScalar hPoint ekPt hsPt ekePt lhsPt : MoveValue)
    (hmv : mv = .struct_ (.bool true :: rCompressed :: rest))
    (hsOpt : sOpt = .struct_ (.bool true :: sVal :: srest'))
    (hsc : o.newScalarFromBytes [.vector .u8 (respBa.toList.map .u8)] = some [sOpt])
    (horacle : o.pubkeyToBytes [.struct_ [.vector .u8 (ekBa.toList.map .u8)]] =
      some [.vector .u8 ekBytesList])
    (hcompress : o.compressedPointToBytes [rCompressed] = some [.vector .u8 rcBytesList])
    (hnative : newScalarFromSha2_512
        [.vector .u8 (registrationMsgBytesForFs mv sOpt chainId sender contract token ekBytesList rcBytesList)] =
      some [eScalar])
    (hhash : o.hashToPointBase [] = some [hPoint])
    (hekp : o.pubkeyToPoint [.struct_ [.vector .u8 (ekBa.toList.map .u8)]] = some [ekPt])
    (hmulSH : o.pointMul [hPoint, sVal] = some [hsPt])
    (hmulEkE : o.pointMul [ekPt, eScalar] = some [ekePt])
    (hadd : o.pointAdd [hsPt, ekePt] = some [lhsPt])
    (fuel : Nat) (hf : 63 ≤ fuel) :
    run (registrationModuleEnv o)
        (registrationFrameAtPc2 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
          (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa))
        [] [mv] MachineState.empty (fuel - 2) =
      run (registrationModuleEnv o)
        (registrationFramePc63AfterStLoc17 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
            (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa) mv rCompressed sOpt sVal
            eScalar hPoint ekPt hsPt ekePt lhsPt)
        [] [] (registrationMsAfterPointAddLhs mv sOpt chainId sender contract token ekBytesList rcBytesList hPoint sVal hsPt
            ekPt eScalar ekePt)
        (fuel - 63) := by
  have hf59 : 59 ≤ fuel := by omega
  have h259 := registration_run_pc2_to_pc59_happyPath o chainId sender contract token ekBa commitBa respBa
    mv rCompressed sOpt sVal rest srest' ekBytesList rcBytesList eScalar hPoint ekPt hsPt ekePt hmv hsOpt hsc horacle
    hcompress hnative hhash hekp hmulSH hmulEkE fuel hf59
  have hf63 : 4 ≤ fuel - 59 := by omega
  have h5963 := registration_run_pc59_to_pc63_afterEkEStack o chainId sender contract token ekBa commitBa respBa
    mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt ekBytesList rcBytesList hadd (fuel - 59) hf63
  exact h259.trans h5963

/-- PC 2 → returned: full happy-path bytecode run ends in `ExecResult.returned` with the final
`ContainerStore` (still subject to `registration_eval_equiv_singleton_tail` for relating `eval`/`run`). -/
theorem registration_run_pc2_to_returned_happyPath
    (o : RegistrationNativeOracle)
    (chainId : UInt8) (sender contract token ekBa commitBa respBa : ByteArray)
    (mv rCompressed sOpt sVal : MoveValue) (rest srest' : List MoveValue)
    (ekBytesList rcBytesList : List MoveValue) (eScalar hPoint ekPt hsPt ekePt lhsPt rhsPt : MoveValue)
    (hmv : mv = .struct_ (.bool true :: rCompressed :: rest))
    (hsOpt : sOpt = .struct_ (.bool true :: sVal :: srest'))
    (hsc : o.newScalarFromBytes [.vector .u8 (respBa.toList.map .u8)] = some [sOpt])
    (horacle : o.pubkeyToBytes [.struct_ [.vector .u8 (ekBa.toList.map .u8)]] =
      some [.vector .u8 ekBytesList])
    (hcompress : o.compressedPointToBytes [rCompressed] = some [.vector .u8 rcBytesList])
    (hnative : newScalarFromSha2_512
        [.vector .u8 (registrationMsgBytesForFs mv sOpt chainId sender contract token ekBytesList rcBytesList)] =
      some [eScalar])
    (hhash : o.hashToPointBase [] = some [hPoint])
    (hekp : o.pubkeyToPoint [.struct_ [.vector .u8 (ekBa.toList.map .u8)]] = some [ekPt])
    (hmulSH : o.pointMul [hPoint, sVal] = some [hsPt])
    (hmulEkE : o.pointMul [ekPt, eScalar] = some [ekePt])
    (hadd : o.pointAdd [hsPt, ekePt] = some [lhsPt])
    (hdec : o.pointDecompress [rCompressed] = some [rhsPt])
    (heq : o.pointEquals [lhsPt, rhsPt] = some [.bool true])
    (fuel : Nat) (hf : 71 ≤ fuel) :
    run (registrationModuleEnv o)
        (registrationFrameAtPc2 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
          (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa))
        [] [mv] MachineState.empty (fuel - 2) =
      ExecResult.returned [] (registrationMsAfterRegistrationReturned mv sOpt chainId sender contract token
          ekBytesList rcBytesList rCompressed hPoint sVal hsPt ekPt eScalar ekePt lhsPt rhsPt) := by
  have hf63 : 63 ≤ fuel := by omega
  have h263 := registration_run_pc2_to_pc63_happyPath o chainId sender contract token ekBa commitBa respBa
    mv rCompressed sOpt sVal rest srest' ekBytesList rcBytesList eScalar hPoint ekPt hsPt ekePt lhsPt hmv hsOpt hsc
    horacle hcompress hnative hhash hekp hmulSH hmulEkE hadd fuel hf63
  have hf6366 : 3 ≤ fuel - 63 := by omega
  have h6366 := registration_run_pc63_to_pc66_afterLhsStored o chainId sender contract token ekBa commitBa respBa
    mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt rhsPt ekBytesList rcBytesList hdec (fuel - 63)
    hf6366
  have hf71 : 5 ≤ fuel - 66 := by omega
  have h66ret := registration_run_pc66_to_returned_afterDecompress o chainId sender contract token ekBa commitBa respBa
    mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt rhsPt ekBytesList rcBytesList heq (fuel - 66) hf71
  exact h263.trans h6366 |>.trans h66ret

/-! ## Proved L2 ≡ L1.5 fragment (Schnorr success + wire coherence)

When `pubkey_to_bytes` / `compressed_point_to_bytes` return the **canonical** BCS lists for `ekBa` /
`commitBa`, the Fiat–Shamir wire in `FunctionalSim.buildFSMessageMv` is **definitionally** the same
list as `registrationMsgBytesForFs` used in the bytecode proof chain — so the SHA2-512 challenge in
`verifyRegistrationBytecodeResult` matches the VM path. Together with
`registration_run_pc2_to_returned_happyPath`, this yields `(run …).dropMs = verifyRegistrationBytecodeResult`
**without** `registration_eval_equiv_singleton_tail` on this path. -/

theorem registrationMsgBytesForFs_eq_functionalSim_wire
    (mv sOpt : MoveValue) (chainId : UInt8) (sender contract token ekBa commitBa : ByteArray)
    (ekBytesList rcBytesList : List MoveValue)
    (hek : ekBytesList = ekBa.toList.map .u8)
    (hrc : rcBytesList = commitBa.toList.map .u8) :
    registrationMsgBytesForFs mv sOpt chainId sender contract token ekBytesList rcBytesList =
      fiatShamirDstMvU8s ++ [.u8 chainId] ++ sender.toList.map .u8 ++ contract.toList.map .u8 ++
        token.toList.map .u8 ++ ekBa.toList.map .u8 ++ commitBa.toList.map .u8 := by
  have hdst : fiatShamirRegistrationDstBytesList = fiatShamirDstMvU8s := by
    simp [fiatShamirRegistrationDstBytesList, fiatShamirDstMvU8s, fiatShamirDstMvU8s_eq_registrationDstBytes_toList_map]
  have htok :
      registrationMsgBytesAfterToken mv sOpt chainId sender contract token =
        fiatShamirDstMvU8s ++ [.u8 chainId] ++ sender.toList.map .u8 ++ contract.toList.map .u8 ++
          token.toList.map .u8 := by
    simp [registrationMsgBytesAfterToken, hdst, List.append_assoc]
  simp [registrationMsgBytesForFs, registrationMsgBytesAfterPubkey, hek, hrc, htok]

set_option maxHeartbeats 800000 in
theorem verifyRegistrationBytecodeResult_eq_returned_of_schnorr_hmac_bundle
    (o : RegistrationNativeOracle)
    (chainId : UInt8) (sender contract token ekBa commitBa respBa : ByteArray)
    (mv rCompressed sOpt sVal : MoveValue) (rest srest' : List MoveValue)
    (ekBytesList rcBytesList : List MoveValue) (eScalar hPoint ekPt hsPt ekePt lhsPt rhsPt : MoveValue)
    (hmv : mv = .struct_ (.bool true :: rCompressed :: rest))
    (hsOpt : sOpt = .struct_ (.bool true :: sVal :: srest'))
    (hl : o.newCompressedPointFromBytes [.vector .u8 (commitBa.toList.map .u8)] = some [mv])
    (hsc : o.newScalarFromBytes [.vector .u8 (respBa.toList.map .u8)] = some [sOpt])
    (horacle : o.pubkeyToBytes [.struct_ [.vector .u8 (ekBa.toList.map .u8)]] =
      some [.vector .u8 ekBytesList])
    (hcompress : o.compressedPointToBytes [rCompressed] = some [.vector .u8 rcBytesList])
    (hek : ekBytesList = ekBa.toList.map .u8)
    (hrc : rcBytesList = commitBa.toList.map .u8)
    (hnative : newScalarFromSha2_512
        [.vector .u8 (registrationMsgBytesForFs mv sOpt chainId sender contract token ekBytesList rcBytesList)] =
      some [eScalar])
    (hhash : o.hashToPointBase [] = some [hPoint])
    (hekp : o.pubkeyToPoint [.struct_ [.vector .u8 (ekBa.toList.map .u8)]] = some [ekPt])
    (hmulSH : o.pointMul [hPoint, sVal] = some [hsPt])
    (hmulEkE : o.pointMul [ekPt, eScalar] = some [ekePt])
    (hadd : o.pointAdd [hsPt, ekePt] = some [lhsPt])
    (hdec : o.pointDecompress [rCompressed] = some [rhsPt])
    (heq : o.pointEquals [lhsPt, rhsPt] = some [.bool true]) :
    verifyRegistrationBytecodeResult o (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa) =
      ExecResult.returned [] MachineState.empty := by
  have hpub : o.pubkeyToBytes [.struct_ [.vector .u8 (ekBa.toList.map .u8)]] =
      some [.vector .u8 (ekBa.toList.map .u8)] := by simpa [hek] using horacle
  have hcomp2 : o.compressedPointToBytes [rCompressed] =
      some [.vector .u8 (commitBa.toList.map .u8)] := by simpa [hrc] using hcompress
  have hbmv :=
    buildFSMessageMv_list_gen o chainId sender contract token ekBa commitBa (.struct_ [.vector .u8 (ekBa.toList.map .u8)])
      rCompressed hpub hcomp2
  -- `buildFSMessageMv_list_gen` concludes with the flattened `fiatShamirDstMvU8s ++ …` wire; re-express as
  -- `registrationMsgBytesForFs` (same bytes as the bytecode/MS chain) for `blockCDE` / `newScalarFromSha2_512`.
  rw [← registrationMsgBytesForFs_eq_functionalSim_wire mv sOpt chainId sender contract token ekBa commitBa ekBytesList
      rcBytesList hek hrc] at hbmv
  simp only [verifyRegistrationBytecodeResult, verifyRegistrationBytecodeResult.blockB,
    verifyRegistrationBytecodeResult.blockCDE, registrationVerifyArgs, match_single?, single?, hl, hsc, hbmv, hnative,
    hhash, hekp, hmulSH, hmulEkE, hadd, hdec, heq, hmv, hsOpt, optionIsSome, optionExtract, bind, Option.bind]

/-- Same conclusion as `registration_eval_equiv_singleton_tail` on the **proved** Schnorr success bundle
(including canonical EK / commitment bytes) and sufficient fuel. -/
theorem registration_eval_equiv_singleton_tail_of_schnorr_hmac_bundle
    (o : RegistrationNativeOracle)
    (chainId : UInt8) (sender contract token ekBa commitBa respBa : ByteArray)
    (mv rCompressed sOpt sVal : MoveValue) (rest srest' : List MoveValue)
    (ekBytesList rcBytesList : List MoveValue) (eScalar hPoint ekPt hsPt ekePt lhsPt rhsPt : MoveValue)
    (hmv : mv = .struct_ (.bool true :: rCompressed :: rest))
    (hsOpt : sOpt = .struct_ (.bool true :: sVal :: srest'))
    (hl : o.newCompressedPointFromBytes [.vector .u8 (commitBa.toList.map .u8)] = some [mv])
    (hsc : o.newScalarFromBytes [.vector .u8 (respBa.toList.map .u8)] = some [sOpt])
    (horacle : o.pubkeyToBytes [.struct_ [.vector .u8 (ekBa.toList.map .u8)]] =
      some [.vector .u8 ekBytesList])
    (hcompress : o.compressedPointToBytes [rCompressed] = some [.vector .u8 rcBytesList])
    (hek : ekBytesList = ekBa.toList.map .u8)
    (hrc : rcBytesList = commitBa.toList.map .u8)
    (hnative : newScalarFromSha2_512
        [.vector .u8 (registrationMsgBytesForFs mv sOpt chainId sender contract token ekBytesList rcBytesList)] =
      some [eScalar])
    (hhash : o.hashToPointBase [] = some [hPoint])
    (hekp : o.pubkeyToPoint [.struct_ [.vector .u8 (ekBa.toList.map .u8)]] = some [ekPt])
    (hmulSH : o.pointMul [hPoint, sVal] = some [hsPt])
    (hmulEkE : o.pointMul [ekPt, eScalar] = some [ekePt])
    (hadd : o.pointAdd [hsPt, ekePt] = some [lhsPt])
    (hdec : o.pointDecompress [rCompressed] = some [rhsPt])
    (heq : o.pointEquals [lhsPt, rhsPt] = some [.bool true])
    (fuel : Nat)
    (_hf200 : fuel ≥ 200) :
    (run (registrationModuleEnv o)
        (registrationFrameAtPc2 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
          (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa))
        [] [mv] MachineState.empty (fuel - 2)).dropMs =
      verifyRegistrationBytecodeResult o
        (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa) := by
  have hf71 : 71 ≤ fuel := by omega
  have hr := registration_run_pc2_to_returned_happyPath o chainId sender contract token ekBa commitBa respBa mv
    rCompressed sOpt sVal rest srest' ekBytesList rcBytesList eScalar hPoint ekPt hsPt ekePt lhsPt rhsPt hmv hsOpt hsc
    horacle hcompress hnative hhash hekp hmulSH hmulEkE hadd hdec heq fuel hf71
  have hv := verifyRegistrationBytecodeResult_eq_returned_of_schnorr_hmac_bundle o chainId sender contract token ekBa
    commitBa respBa mv rCompressed sOpt sVal rest srest' ekBytesList rcBytesList eScalar hPoint ekPt hsPt ekePt lhsPt
    rhsPt hmv hsOpt hl hsc horacle hcompress hek hrc hnative hhash hekp hmulSH hmulEkE hadd hdec heq
  have hdrop :
      (run (registrationModuleEnv o)
            (registrationFrameAtPc2 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
              (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa))
            [] [mv] MachineState.empty (fuel - 2)).dropMs =
        ExecResult.returned [] MachineState.empty := by
    rw [hr]
    simp [ExecResult.dropMs]
  rw [hdrop, hv]

/-! ### Elaboration-cost wall at the first abstract-MS composition

**Update:** `registration_run_pc31_to_pc35_afterAppendContract` proves the PC 31→35 segment for the
concrete post-contract machine state by instantiating `registration_run_from_pc31_to_pc35_abstractMs`
and folding the nested record update to `registrationMsAfterAppendTokenMsg` (see
`registration_ms_pc35_nested_record_eq_single`). **`registration_run_pc2_to_pc35_happyPath`** composes
pc2→31 with pc31→35 by transitivity (no single-step application of the abstract lemma to the deep
`registrationMsAfterAppendContract` def in the composed goal). Proved transitive chains continue
through `ret` on the oracle-driven happy path (`registration_run_pc2_to_returned_happyPath`). Further
steps toward eliminating `registration_eval_equiv_singleton_tail` relate that `run`/`eval` path to
`verifyRegistrationBytecodeResult` (`dropMs` refactor or `MachineState.ofContainers` / `@[irreducible]`
plan as needed).

A **naive** one-shot proof that threads `registration_run_pc2_to_pc31_happyPath` through
`registration_run_from_pc31_to_pc35_abstractMs` (instantiating the abstract lemma in the **same**
theorem as the pc2→31 chain) consistently times out at `whnf` / `isDefEq` even with
`maxHeartbeats = 3200000`. The **transitive** theorem `registration_run_pc2_to_pc35_happyPath` above
avoids that by composing two already-elaborated equalities. The cost of the naive approach is
concentrated in elaborating the output `MachineState` expression, which in pc31→pc35 is stated as
`{ { ms with containers := (ms.containers.alloc (.address token)).1 } with containers := csFinal }`
— a nested record update where both `ms = registrationMsAfterAppendContract …` and
`csFinal = registrationCsAfterAppendToken …` are themselves defs that unfold into deep
`match`-on-write chains rooted at `MachineState.empty`. When Lean checks the argument types of
`registration_run_from_pc31_to_pc35_abstractMs` it apparently tries to reduce the `Array.set …`
expression inside `registrationCsAfterAppendToken`, which itself carries a compound `store.size`
proof that unfolds the entire MS chain back through `registrationMsAfterAppendSender`,
`registrationMsAfterImmBorrow1_sender`, …

Bumping heartbeats to 6.4M did not help in earlier experiments (see `116840.txt` terminal log —
the file-level compile ran 22 min before the first `whnf` timeout at 6.4M). The helpers
`registrationMsAfterAppendContract_store_size`, `_read4`, `_alloc_token_read4`, `_alloc_token_lt4`,
`registrationCsAfterAppendToken`, and `_alloc_token_write4` DO compile (they live above this
comment); the bottleneck is specifically the composition theorem's argument-checking phase.

**What would actually work** (future work, deferred due to compile budget):
1. Reformulate the pc31→…→pc66 chain so each step's output MS is stated in terms of
   `MachineState.ofContainers` against a named `ContainerStore`, avoiding `{ ms with … }` updates.
2. Or, mark the expensive defs (`registrationMsAfterAppendSender`, `registrationMsAfterImmBorrow2_contract`,
   `registrationMsAfterAppendContract`, `registrationCsAfterAppendToken`) as `@[irreducible]` and
   prove their unfolding equations once; downstream proofs then reason only via the equations.
3. Or, migrate the remaining chain lemmas to a `dropMs`-based statement (since the axiom's
   conclusion is `(run …).dropMs = func`, tracking full MS is unnecessary from here on).

Each of these is a refactor of 3 000–6 000 lines of existing chain lemmas. The proved `run` chain on
the happy path reaches `ExecResult.returned` (`registration_run_pc2_to_returned_happyPath`); the axiom
`registration_eval_equiv_singleton_tail` below remains the trusted bridge from `eval` to this `run`
story and to `verifyRegistrationBytecodeResult` where the statements differ (e.g. `dropMs`). -/

/-! ## Functional sim: same early errors as bytecode -/

theorem verifyRegistration_func_error_of_compressed_none
    (o : RegistrationNativeOracle)
    (chainId : UInt8) (sender contract token ekBa commitBa respBa : ByteArray)
    (h : o.newCompressedPointFromBytes
          [.vector .u8 (commitBa.toList.map .u8)] = none) :
    verifyRegistrationBytecodeResult o
        (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa) = .error := by
  simp only [verifyRegistrationBytecodeResult, registrationVerifyArgs, h, single?]

theorem verifyRegistration_func_error_of_compressed_not_singleton
    (o : RegistrationNativeOracle)
    (chainId : UInt8) (sender contract token ekBa commitBa respBa : ByteArray)
    (l : List MoveValue)
    (hl : o.newCompressedPointFromBytes [.vector .u8 (commitBa.toList.map .u8)] = some l)
    (hlen : l.length ≠ 1) :
    verifyRegistrationBytecodeResult o
        (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa) = .error := by
  simp only [verifyRegistrationBytecodeResult, registrationVerifyArgs, hl]
  cases l with
  | nil => simp [single?]
  | cons a as =>
    cases as with
    | nil => simp at hlen
    | cons b t => simp [single?]

/-- Bytecode `eval` reaches `.error` on the same early paths as the functional sim:
    after `moveLoc 5`, `call 0` (`new_compressed_point_from_bytes`) fails in one step
    when the oracle returns `none` or a non-singleton list. -/
theorem registration_eval_early_error_matches_func
    (o : RegistrationNativeOracle)
    (chainId : UInt8) (sender contract token ekBa commitBa respBa : ByteArray)
    (fuel : Nat) (hf : 2 ≤ fuel)
    (hnp : o.newCompressedPointFromBytes [.vector .u8 (commitBa.toList.map .u8)] = none ∨
      ∃ l, o.newCompressedPointFromBytes [.vector .u8 (commitBa.toList.map .u8)] = some l ∧ l.length ≠ 1) :
    eval (registrationModuleEnv o) verifyRegistrationProofIdx
        (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
        fuel MachineState.empty = .error := by
  let args := registrationVerifyArgs chainId sender contract token ekBa commitBa respBa
  have hlen : args.length = 7 := registrationVerifyArgs_len _ _ _ _ _ _ _
  rw [eval_registration_eq_run o args fuel MachineState.empty hlen]
  let f1 :=
    ({ registrationInitFrame args with
        pc := 1,
        locals :=
          (registrationInitFrame args).locals.set 5 none (registrationInitFrame_idx5_lt args hlen) })
  have hs0 := registration_step0_moveLoc5 o chainId sender contract token ekBa commitBa respBa
  have hs1 :
      step (registrationModuleEnv o) f1 [] [.vector .u8 (commitBa.toList.map .u8)] MachineState.empty =
        ExecResult.error := by
    rcases hnp with hnone | ⟨l, hl, hlne⟩
    · exact registration_step1_call0_none o chainId sender contract token ekBa commitBa respBa hnone
    · exact registration_step1_call0_not_singleton o chainId sender contract token ekBa commitBa respBa l hl hlne
  exact run_ok_then_second_errors (registrationModuleEnv o) (registrationInitFrame args) f1 [] []
    [.vector .u8 (commitBa.toList.map .u8)] MachineState.empty MachineState.empty fuel hf hs0 hs1

/-! ## L2 ≡ L1.5: `eval` vs `verifyRegistrationBytecodeResult`

**Status.** Early-error paths and `single?` scaffolding are proved. After `moveLoc` / `call 0`,
singleton `[mv]` reaches PC 2 (`registration_step1_call0_singleton`, `registration_run_eq_from_pc2_singleton`).
On the success path, per-PC step lemmas are mechanized through PC 20:

- PC 2 `stLoc 7`, PC 3 `immBorrowLoc 7`, PC 4 `call 1` (`option::is_some`),
  PC 5 `brFalse 79` (fall-through when `tag = true`), PC 6 `mutBorrowLoc 7`,
  PC 7 `call 2` (`option::extract`), PC 8 `stLoc 8` (store `rCompressed`),
  PC 9 `moveLoc 6` (push `respBytes`), PC 10 `call 3` (`new_scalar_from_bytes`, singleton case),
  PC 11 `stLoc 9` (store `sOpt`), PC 12 `immBorrowLoc 9` (alloc `sOpt` at ref `2`),
  PC 13 `call 1` (`option::is_some` on `&sOpt`), PC 14 `brFalse 74` (fall-through when `stag = true`),
  PC 15 `mutBorrowLoc 9` (alloc `sOpt` at ref `3`), PC 16 `call 2` (`option::extract` on `&mut sOpt`),
  PC 17 `stLoc 10` (store `sVal`), PC 18 `ldConst 5` (push DST), PC 19 `stLoc 11` (store `msg`),
  PC 20 `mutBorrowLoc 11` (alloc `msg` at ref `4`), PC 21 `moveLoc 0` (push `chainId`),
  PC 22 `call 4` (`vector::push_back<u8>` chainId onto `&mut msg`),
  PC 23 `mutBorrowLoc 11` (reuse existing ref `4` — no realloc),
  PC 24 `immBorrowLoc 1` (alloc `sender` address at ref `5`, push `immRef 5`;
         `immBorrowLoc` does NOT update `localRefs` since `&` refs are not tracked per-slot
         in the current step semantics — see `Step.lean`),
  PC 25 `call 5` (`bcs::to_bytes<address>(&sender)` — reads ref 5, pushes senderBytes),
  PC 26 `call 6` (`vector::append<u8>(&mut msg, senderBytes)` — ref 4 becomes DST ++ [chainId] ++ senderBytes),
  PC 27 `mutBorrowLoc 11` (reuse ref 4, pc→28),
  PC 28 `immBorrowLoc 2` (alloc `contract_address` at ref `6`),
  PC 29 `call 5` (`bcs::to_bytes<address>(&contract)` — pushes contractBytes),
  PC 30 `call 6` (`vector::append<u8>` — ref 4 becomes DST ++ [chainId] ++ senderBytes ++ contractBytes),
  PC 31 `mutBorrowLoc 11` (generic form; reuse ref 4, pc→32),
  PC 32 `immBorrowLoc 4` (generic form; alloc at `ms.containers.store.size`),
  PC 33 `call 5` `bcs::to_bytes<address>` (generic form; takes `refId` and `addr` with `ms.containers.read refId = some (.address addr)`),
  PC 34 `call 6` `vector::append<u8>` (generic form; takes `existing`/`appended`/`cs'` with read+write hypotheses),
  PC 35 `mutBorrowLoc 11` (generic form; reuse ref 4, pc→36),
  PC 36 `copyLoc 3` (generic form; push `ek` struct value, no localRef),
  PC 37 `call 7` `pubkey_to_bytes` (generic form; takes `ekBytes` output with `o.pubkeyToBytes [ek] = some [ekBytes]`; `wrapOracleImmRef1` deref is identity on struct),
  PC 38 `call 6` `vector::append<u8>` (generic form; pc 38→39),
  PC 39 `mutBorrowLoc 11` (generic form; pc 39→40),
  PC 40 `copyLoc 8` (generic form; push `rCompressed` from local 8, no localRef at idx 8),
  PC 41 `call 8` `compressed_point_to_bytes` (generic form; `.native o.compressedPointToBytes`; takes `rcBytes` output),
  PC 42 `call 6` `vector::append<u8>` (generic form; pc 42→43).

**Scalability note:** PC 31 onward are stated generically over an arbitrary input `MachineState`
(via `..._generic` lemmas). This avoids the exponential whnf blow-up that occurred when earlier
PCs directly referred to the deep MS chain (`registrationMsAfterAppendContract`, etc.) in the
theorem signature — each layer roughly doubles elaboration cost, quickly exceeding even
`maxHeartbeats 3200000`. The specialised corollaries used downstream are obtained by applying
the generic lemma with the actual MS and read/write hypotheses.

Combinator `registration_run_from_pc2_to_pc6_somePath` / `registration_run_from_entry_to_pc6_somePath`
chain PC 2 → PC 6. The full concrete-MS block is composed through `ret` on the oracle-driven happy
path (`registration_run_pc2_to_returned_happyPath`), and the Fiat–Shamir wire matches
`FunctionalSim.buildFSMessageMv` when EK / commitment bytes are canonical
(`registrationMsgBytesForFs_eq_functionalSim_wire` with `hek` / `hrc`). On that bundle,
`registration_eval_equiv_singleton_tail_of_schnorr_hmac_bundle` proves `(run …).dropMs =
verifyRegistrationBytecodeResult` **without** the axiom below.

The unconditional axiom remains for **arbitrary** oracles (error / abort / non-canonical byte
paths not yet split into separate theorems). Concrete agreement is also checked by `native_decide`
in `BytecodeDifftestEval.lean`.

**PC 43 note (historical):** the generic `moveLoc` ref-read branch once blocked automation; the
composed chain now uses explicit container lemmas instead of one-shot `simp` on `step`. -/

set_option maxRecDepth 8192 in
set_option maxHeartbeats 800000 in

/-- **Trusted bridge (L2 ≡ L1.5 tail), general case.**

States that executing the transcribed bytecode from **PC 2** (stack `[mv]` after a singleton
`new_compressed_point_from_bytes` return, frame `registrationFrameAtPc2`) with remaining fuel
`fuel - 2` agrees—up to `ExecResult.dropMs`—with `verifyRegistrationBytecodeResult` for **any**
oracle satisfying only `hl`.

**Proved replacement on the Schnorr success bundle:** see
`registration_eval_equiv_singleton_tail_of_schnorr_hmac_bundle` (canonical EK/commitment bytes +
full oracle equalities + `fuel ≥ 200`). Regression evidence for the general statement lives in
`BytecodeDifftestEval.lean` (`native_decide`).

**Why this is the last general axiom.** Early-error paths (`registration_eval_early_error_matches_func`)
and the full Schnorr success bundle are already separated into proved theorems; what remains for
a *single* unconditional statement is the arbitrary-oracle singleton tail where `run` still threads
a deep `MachineState` until `ret` while `verifyRegistrationBytecodeResult` is `MachineState`-free.
Eliminating the axiom is expected to follow a `dropMs`-nativeRef refactor or `ContainerStore`/`@[irreducible]`
re-layering (see the elaboration-cost note above this axiom), not a further cryptographic lemma. -/
axiom registration_eval_equiv_singleton_tail
    (o : RegistrationNativeOracle)
    (chainId : UInt8) (sender contract token ekBa commitBa respBa : ByteArray)
    (mv : MoveValue) (fuel : Nat)
    (hfuel : fuel ≥ 200)
    (hl : o.newCompressedPointFromBytes [.vector .u8 (commitBa.toList.map .u8)] = some [mv]) :
    (run (registrationModuleEnv o)
        (registrationFrameAtPc2 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
          (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa))
        [] [mv] MachineState.empty (fuel - 2)).dropMs =
      verifyRegistrationBytecodeResult o
        (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)

/-- Singleton compressed-point path: `eval.dropMs` vs functional sim (uses `registration_eval_equiv_singleton_tail`). -/
theorem registration_eval_equiv_functional_sim_core
    (o : RegistrationNativeOracle)
    (chainId : UInt8) (sender contract token ekBa commitBa respBa : ByteArray)
    (fuel : Nat) (_hfuel : fuel ≥ 200)
    (l : List MoveValue)
    (hl : o.newCompressedPointFromBytes [.vector .u8 (commitBa.toList.map .u8)] = some l)
    (hlen : l.length = 1) :
    (eval (registrationModuleEnv o) verifyRegistrationProofIdx
        (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
        fuel MachineState.empty).dropMs =
    verifyRegistrationBytecodeResult o
        (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa) := by
  obtain ⟨mv, rfl⟩ : ∃ mv, l = [mv] := by
    cases l with
    | nil => simp at hlen
    | cons a as =>
      cases as with
      | nil => exact ⟨a, rfl⟩
      | cons b t =>
        exfalso
        rw [List.length_cons, List.length_cons, show (1 : Nat) = Nat.succ 0 by rfl] at hlen
        exact Nat.succ_ne_zero _ (Nat.succ_injective hlen)
  let args := registrationVerifyArgs chainId sender contract token ekBa commitBa respBa
  have hargs : args.length = 7 := registrationVerifyArgs_len _ _ _ _ _ _ _
  have hf2 : 2 ≤ fuel := by omega
  rw [eval_registration_eq_run o args fuel MachineState.empty hargs]
  rw [registration_run_eq_from_pc2_singleton o chainId sender contract token ekBa commitBa respBa mv fuel hf2
    (by simpa [args] using hl)]
  exact registration_eval_equiv_singleton_tail o chainId sender contract token ekBa commitBa respBa mv fuel _hfuel
    (by simpa [args] using hl)

theorem registration_eval_equiv_functional_sim
    (o : RegistrationNativeOracle)
    (chainId : UInt8) (sender contract token ekBa commitBa respBa : ByteArray)
    (fuel : Nat) (hfuel : fuel ≥ 200) :
    (eval (registrationModuleEnv o) verifyRegistrationProofIdx
        (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
        fuel MachineState.empty).dropMs =
    verifyRegistrationBytecodeResult o
        (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa) := by
  have hf2 : 2 ≤ fuel := by omega
  cases hnp : o.newCompressedPointFromBytes [.vector .u8 (commitBa.toList.map .u8)] with
  | none =>
    have hf := verifyRegistration_func_error_of_compressed_none o chainId sender contract token ekBa commitBa respBa hnp
    have he := registration_eval_early_error_matches_func o chainId sender contract token ekBa commitBa respBa fuel hf2
        (Or.inl hnp)
    simp [hf, he, ExecResult.dropMs]
  | some l =>
    by_cases hsing : l.length = 1
    · obtain ⟨mv, rfl⟩ : ∃ mv, l = [mv] := by
        cases l with
        | nil => simp at hsing
        | cons a as =>
          cases as with
          | nil => exact ⟨a, rfl⟩
          | cons b t =>
            exfalso
            rw [List.length_cons, List.length_cons, show (1 : Nat) = Nat.succ 0 by rfl] at hsing
            have hs := Nat.succ_injective hsing
            exact absurd hs (Nat.succ_ne_zero _)
      exact registration_eval_equiv_functional_sim_core o chainId sender contract token ekBa commitBa respBa fuel hfuel
          [mv] (by simpa using hnp) (by rfl)
    · have hne : l.length ≠ 1 := by simpa using hsing
      have hf := verifyRegistration_func_error_of_compressed_not_singleton o chainId sender contract token ekBa commitBa respBa l hnp hne
      have he := registration_eval_early_error_matches_func o chainId sender contract token ekBa commitBa respBa fuel hf2
          (Or.inr ⟨l, hnp, hne⟩)
      simp [hf, he, ExecResult.dropMs]

theorem eval_eq_func_200
    (o : RegistrationNativeOracle)
    (chainId : UInt8) (sender contract token ekBa commitBa respBa : ByteArray) :
    (eval (registrationModuleEnv o) verifyRegistrationProofIdx
        (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
        200 MachineState.empty).dropMs =
    verifyRegistrationBytecodeResult o
        (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa) :=
  registration_eval_equiv_functional_sim o chainId sender contract token ekBa commitBa respBa 200 (by omega)

end MovementFormal.Experimental.ConfidentialAsset.Registration.EvalEquiv
