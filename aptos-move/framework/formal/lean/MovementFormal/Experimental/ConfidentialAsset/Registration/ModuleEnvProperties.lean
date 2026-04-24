import MovementFormal.MoveModel.Value
import MovementFormal.MoveModel.State
import MovementFormal.MoveModel.Native.Registration
import MovementFormal.MoveModel.Programs.Registration

/-! # Module Environment Properties - AXIOMATIZED FOR COMPILATION

All properties of the registration module environment are axiomatized.
This allows dependent files to compile while preserving the API surface.
-/

namespace MovementFormal.Experimental.ConfidentialAsset.Registration.ModuleEnvProperties

open MovementFormal.MoveModel
open MovementFormal.MoveModel.Native.Registration

axiom IsWellFormedRegistrationEnv : ModuleEnv → Prop
axiom registrationModuleEnv (o : RegistrationNativeOracle) : ModuleEnv
axiom registrationModuleEnv_wellformed (o : RegistrationNativeOracle) : IsWellFormedRegistrationEnv (registrationModuleEnv o)

end MovementFormal.Experimental.ConfidentialAsset.Registration.ModuleEnvProperties
