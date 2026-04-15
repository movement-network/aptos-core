import AptosFormal.Move.Programs.Confidential
import AptosFormal.Refinement.Confidential

/-!
# Smoke tests for `confidentialModuleEnv` (CA difftest column)

Definitional links between `Refinement.Confidential.evalCA` and `eval` for selected rows (**40**, **42**, **102**, **176**, **177**, **178**, **179**, **180**, **181**, **182**, **183**, **184**, **185**, **186**, **187**, **188**, **189**, **190**, **191**, **192**, **193**, **169–173**),
plus machine-checked equality **`evalCA 171` = `evalCA 35`** (helpers vs production registration verify on the
same fixture — `native_decide` in this file). Index **40** is the merged CA e2e **`bool(true)`** stub used for many
VM-checked rows include many **`bool(true)`** pins at **40** (**`verify_pending_balance`** / **`verify_actual_balance`** success cases, including **two** **`deposit`**s then **`verify_pending_balance(sum)`** before rollover, **`verify_actual_balance(sum)`** after **two** **`deposit`**s + **`rollover`**, **`verify_actual_balance(pool)`** and **`verify_pending_balance(0)`** after **`deposit`** + **`rollover`** + **`withdraw`**, or matching **`verify_{actual,pending}_balance`** after **`deposit`** + **`rollover`** + **`normalize`**) and **`bool(false)`** at **102** (e.g. **non-zero** **`verify_{pending,actual}_balance`** right after **`register`**, wrong or **stale** **`verify_pending_balance`** after **`rollover`** (including **stale summed `u64`** or **off-by-one vs sum** after **two** **`deposit`**s + **`rollover`**), **`verify_actual_balance(0)`** after **`rollover`** when **actual** is non-zero, **`verify_actual_balance`** while funds are still **pending** only (**one** or **two** **`deposit`**s without rollover, including **non-zero** **`u128`** equal to the **pending sum**, or **off-by-one** vs that sum), **`verify_pending_balance(0)`** after **one** or **two** **`deposit`**s without rollover (pending non-zero), wrong **`verify_actual_balance`** after rollover, **off-by-one vs summed actual** after **two** **`deposit`**s + **`rollover`**, or **`verify_actual_balance(pool+1)`** after **`deposit`** + **`rollover`** + **`withdraw`**, wrong **`verify_actual_balance`** after **`normalize`**, **`verify_pending_balance(1)`** after **`normalize`** with zero **pending**, **`is_frozen`** **`bool(false)`** reads after **`rotate_encryption_key_and_unfreeze`**, or the same **failure-shape** class after **`deposit`** + **`rollover`** + **`rotate_encryption_key`**); see
`Refinement.Confidential.ca_e2e_merged_bool_true_witness_eval_eq_true`, **`ca_e2e_merged_bool_false_witness_eval_eq_false`**, and **`ca_e2e_merged_bool_pin_witnesses_eval_bundle`**.
-/

namespace AptosFormal.Tests.Confidential

open AptosFormal.Move
open AptosFormal.Move.Programs.Confidential
open AptosFormal.Refinement.Confidential

theorem evalCA_40_eq_eval :
    evalCA 40 [] 20 = eval confidentialModuleEnv 40 [] 20 := rfl

theorem evalCA_42_eq_eval :
    evalCA 42 [] 20 = eval confidentialModuleEnv 42 [] 20 := rfl

theorem evalCA_102_eq_eval :
    evalCA 102 [] 20 = eval confidentialModuleEnv 102 [] 20 := rfl

theorem evalCA_176_eq_eval :
    evalCA 176 [] 20 = eval confidentialModuleEnv 176 [] 20 := rfl

theorem evalCA_177_eq_eval :
    evalCA 177 [] 20 = eval confidentialModuleEnv 177 [] 20 := rfl

theorem evalCA_178_eq_eval :
    evalCA 178 [] 20 = eval confidentialModuleEnv 178 [] 20 := rfl

theorem evalCA_179_eq_eval :
    evalCA 179 [] 20 = eval confidentialModuleEnv 179 [] 20 := rfl

theorem evalCA_180_eq_eval :
    evalCA 180 [] 20 = eval confidentialModuleEnv 180 [] 20 := rfl

theorem evalCA_181_eq_eval :
    evalCA 181 [] 20 = eval confidentialModuleEnv 181 [] 20 := rfl

theorem evalCA_182_eq_eval :
    evalCA 182 [] 20 = eval confidentialModuleEnv 182 [] 20 := rfl

theorem evalCA_183_eq_eval :
    evalCA 183 [] 20 = eval confidentialModuleEnv 183 [] 20 := rfl

theorem evalCA_184_eq_eval :
    evalCA 184 [] 20 = eval confidentialModuleEnv 184 [] 20 := rfl

theorem evalCA_185_eq_eval :
    evalCA 185 [] 20 = eval confidentialModuleEnv 185 [] 20 := rfl

theorem evalCA_186_eq_eval :
    evalCA 186 [] 20 = eval confidentialModuleEnv 186 [] 20 := rfl

theorem evalCA_187_eq_eval :
    evalCA 187 [] 20 = eval confidentialModuleEnv 187 [] 20 := rfl

theorem evalCA_188_eq_eval :
    evalCA 188 [] 20 = eval confidentialModuleEnv 188 [] 20 := rfl

theorem evalCA_189_eq_eval :
    evalCA 189 [] 20 = eval confidentialModuleEnv 189 [] 20 := rfl

theorem evalCA_190_eq_eval :
    evalCA 190 [] 20 = eval confidentialModuleEnv 190 [] 20 := rfl

theorem evalCA_191_eq_eval :
    evalCA 191 [] 20 = eval confidentialModuleEnv 191 [] 20 := rfl

theorem evalCA_192_eq_eval :
    evalCA 192 [] 20 = eval confidentialModuleEnv 192 [] 20 := rfl

theorem evalCA_193_eq_eval :
    evalCA 193 [] 20 = eval confidentialModuleEnv 193 [] 20 := rfl

/-- `evalCA` is definitionally `eval` on `confidentialModuleEnv`. -/
theorem evalCA_169_eq_eval :
    evalCA 169 [] 50 = eval confidentialModuleEnv 169 [] 50 := rfl

theorem evalCA_170_eq_eval :
    evalCA 170 [] 20 = eval confidentialModuleEnv 170 [] 20 := rfl

theorem evalCA_171_eq_eval :
    evalCA 171 [] 50 = eval confidentialModuleEnv 171 [] 50 := rfl

theorem evalCA_172_eq_eval :
    evalCA 172 [] 15 = eval confidentialModuleEnv 172 [] 15 := rfl

theorem evalCA_173_eq_eval :
    evalCA 173 [] 20 = eval confidentialModuleEnv 173 [] 20 := rfl

theorem evalCA_171_eq_evalCA_35_fixture :
    evalCA 171 [] 50 == evalCA 35 [] 50 := by
  native_decide

end AptosFormal.Tests.Confidential
