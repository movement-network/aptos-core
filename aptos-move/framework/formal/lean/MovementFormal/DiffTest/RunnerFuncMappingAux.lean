import MovementFormal.MoveModel.Step

/-!
## Function name → `FuncMapping` (split for Lean elaboration)

**Source:** JSON `function` strings from `move-lean-difftest` (`aptos-move/framework/formal/difftest/`); catalogs in `MovementFormal.MoveModel.*Catalog` and `MovementFormal.MoveModel.Programs.Confidential`.

Large monolithic `match` in `Runner.lean` hit `maxHeartbeats` / WHNF limits; this module splits the
oracle name table into catalog prefixes plus five tries (`<|>`). **Do not reorder** arms relative to the original single
`match` unless intentionally changing first-match-wins behavior (today each `String` appears at most once).
-/

namespace MovementFormal.DiffTest

open MovementFormal.MoveModel

/-- See `Runner.lean` — duplicated here so this module can elaborate independently. -/
structure FuncMapping where
  funcIdx : FuncIndex
  useRealEnv : Bool := true
  /-- When true, use `confidentialModuleEnv` (indices 0–181; see `Programs/Confidential.lean`). -/
  useConfidentialEnv : Bool := false
  /-- When true, use `bcsCatalogModuleEnv` (indices 0–26; see `MoveModel/BcsCatalog.lean`). -/
  useBcsCatalogEnv : Bool := false
  /-- When true, use `errorCatalogModuleEnv` (indices 0–12; see `MoveModel/ErrorCatalog.lean`). -/
  useErrorCatalogEnv : Bool := false
  /-- When true, use `hashCatalogModuleEnv` (indices 0–1; see `MoveModel/HashCatalog.lean`). -/
  useHashCatalogEnv : Bool := false
  /-- When true, use `signerCatalogModuleEnv` (indices 0–1; see `MoveModel/SignerCatalog.lean`). -/
  useSignerCatalogEnv : Bool := false
  /-- When true, use `fixedPoint32CatalogModuleEnv` (indices 0–11; see `MoveModel/FixedPoint32Catalog.lean`). -/
  useFixedPoint32CatalogEnv : Bool := false
  /-- When true, use `optionCatalogModuleEnv` (indices 0–16; see `MoveModel/OptionCatalog.lean`). -/
  useOptionCatalogEnv : Bool := false
  /-- When true, use `bitVectorCatalogModuleEnv` (indices 0–4; see `MoveModel/BitVectorCatalog.lean`). -/
  useBitVectorCatalogEnv : Bool := false
  /-- When true, use `aclCatalogModuleEnv` (indices 0–4; see `MoveModel/AclCatalog.lean`). -/
  useAclCatalogEnv : Bool := false
  /-- When true, use `stringCatalogModuleEnv` (indices 0–3; see `MoveModel/StringCatalog.lean`). -/
  useStringCatalogEnv : Bool := false
  /-- When true, use `cmpCatalogModuleEnv` (indices 0–47; see `MoveModel/CmpCatalog.lean`). -/
  useCmpCatalogEnv : Bool := false

/-- `std::hash` difftest catalog — must stay in sync with `MoveModel/HashCatalog.lean`. -/
private def funcNameToMappingHashCatalog (base : String) : Option FuncMapping :=
  match base with
  | "test_sha2_256" => some { funcIdx := 0, useRealEnv := false, useHashCatalogEnv := true }
  | "test_sha3_256" => some { funcIdx := 1, useRealEnv := false, useHashCatalogEnv := true }
  | _ => none

/-- `std::signer` difftest catalog — must stay in sync with `MoveModel/SignerCatalog.lean`. -/
private def funcNameToMappingSignerCatalog (base : String) : Option FuncMapping :=
  match base with
  | "test_signer_borrow_address" => some { funcIdx := 0, useRealEnv := false, useSignerCatalogEnv := true }
  | "test_signer_address_of" => some { funcIdx := 1, useRealEnv := false, useSignerCatalogEnv := true }
  | _ => none

/-- `std::fixed_point32` difftest catalog — must stay in sync with `MoveModel/FixedPoint32Catalog.lean`. -/
private def funcNameToMappingFixedPoint32Catalog (base : String) : Option FuncMapping :=
  match base with
  | "test_fp32_create_from_rational" => some { funcIdx := 0, useRealEnv := false, useFixedPoint32CatalogEnv := true }
  | "test_fp32_create_from_u64" => some { funcIdx := 1, useRealEnv := false, useFixedPoint32CatalogEnv := true }
  | "test_fp32_create_from_raw_value" => some { funcIdx := 2, useRealEnv := false, useFixedPoint32CatalogEnv := true }
  | "test_fp32_multiply_u64" => some { funcIdx := 3, useRealEnv := false, useFixedPoint32CatalogEnv := true }
  | "test_fp32_divide_u64" => some { funcIdx := 4, useRealEnv := false, useFixedPoint32CatalogEnv := true }
  | "test_fp32_get_raw_value" => some { funcIdx := 5, useRealEnv := false, useFixedPoint32CatalogEnv := true }
  | "test_fp32_is_zero" => some { funcIdx := 6, useRealEnv := false, useFixedPoint32CatalogEnv := true }
  | "test_fp32_floor" => some { funcIdx := 7, useRealEnv := false, useFixedPoint32CatalogEnv := true }
  | "test_fp32_ceil" => some { funcIdx := 8, useRealEnv := false, useFixedPoint32CatalogEnv := true }
  | "test_fp32_round" => some { funcIdx := 9, useRealEnv := false, useFixedPoint32CatalogEnv := true }
  | "test_fp32_min" => some { funcIdx := 10, useRealEnv := false, useFixedPoint32CatalogEnv := true }
  | "test_fp32_max" => some { funcIdx := 11, useRealEnv := false, useFixedPoint32CatalogEnv := true }
  | _ => none

/-- `std::error` difftest catalog — must stay in sync with `MoveModel/ErrorCatalog.lean`. -/
private def funcNameToMappingErrorCatalog (base : String) : Option FuncMapping :=
  match base with
  | "test_error_canonical" => some { funcIdx := 0, useRealEnv := false, useErrorCatalogEnv := true }
  | "test_error_invalid_argument" => some { funcIdx := 1, useRealEnv := false, useErrorCatalogEnv := true }
  | "test_error_out_of_range" => some { funcIdx := 2, useRealEnv := false, useErrorCatalogEnv := true }
  | "test_error_invalid_state" => some { funcIdx := 3, useRealEnv := false, useErrorCatalogEnv := true }
  | "test_error_unauthenticated" => some { funcIdx := 4, useRealEnv := false, useErrorCatalogEnv := true }
  | "test_error_permission_denied" => some { funcIdx := 5, useRealEnv := false, useErrorCatalogEnv := true }
  | "test_error_not_found" => some { funcIdx := 6, useRealEnv := false, useErrorCatalogEnv := true }
  | "test_error_aborted" => some { funcIdx := 7, useRealEnv := false, useErrorCatalogEnv := true }
  | "test_error_already_exists" => some { funcIdx := 8, useRealEnv := false, useErrorCatalogEnv := true }
  | "test_error_resource_exhausted" => some { funcIdx := 9, useRealEnv := false, useErrorCatalogEnv := true }
  | "test_error_internal" => some { funcIdx := 10, useRealEnv := false, useErrorCatalogEnv := true }
  | "test_error_not_implemented" => some { funcIdx := 11, useRealEnv := false, useErrorCatalogEnv := true }
  | "test_error_unavailable" => some { funcIdx := 12, useRealEnv := false, useErrorCatalogEnv := true }
  | _ => none

/-- `std::bcs` difftest catalog — must stay in sync with `MoveModel/BcsCatalog.lean`. -/
private def funcNameToMappingBcsCatalog (base : String) : Option FuncMapping :=
  match base with
  | "test_bcs_u8" => some { funcIdx := 0, useRealEnv := false, useBcsCatalogEnv := true }
  | "test_bcs_u64" => some { funcIdx := 1, useRealEnv := false, useBcsCatalogEnv := true }
  | "test_bcs_u128" => some { funcIdx := 2, useRealEnv := false, useBcsCatalogEnv := true }
  | "test_bcs_bool" => some { funcIdx := 3, useRealEnv := false, useBcsCatalogEnv := true }
  | "test_bcs_vec_u8" => some { funcIdx := 4, useRealEnv := false, useBcsCatalogEnv := true }
  | "test_bcs_address" => some { funcIdx := 5, useRealEnv := false, useBcsCatalogEnv := true }
  | "test_serialized_size_u8" => some { funcIdx := 6, useRealEnv := false, useBcsCatalogEnv := true }
  | "test_serialized_size_u64" => some { funcIdx := 7, useRealEnv := false, useBcsCatalogEnv := true }
  | "test_serialized_size_u128" => some { funcIdx := 8, useRealEnv := false, useBcsCatalogEnv := true }
  | "test_serialized_size_bool" => some { funcIdx := 9, useRealEnv := false, useBcsCatalogEnv := true }
  | "test_serialized_size_vec_u8" => some { funcIdx := 10, useRealEnv := false, useBcsCatalogEnv := true }
  | "test_serialized_size_address" => some { funcIdx := 11, useRealEnv := false, useBcsCatalogEnv := true }
  | "test_constant_size_u8" => some { funcIdx := 12, useRealEnv := false, useBcsCatalogEnv := true }
  | "test_constant_size_u64" => some { funcIdx := 13, useRealEnv := false, useBcsCatalogEnv := true }
  | "test_constant_size_u128" => some { funcIdx := 14, useRealEnv := false, useBcsCatalogEnv := true }
  | "test_constant_size_bool" => some { funcIdx := 15, useRealEnv := false, useBcsCatalogEnv := true }
  | "test_constant_size_address" => some { funcIdx := 16, useRealEnv := false, useBcsCatalogEnv := true }
  | "test_constant_size_vec_u8_is_none" => some { funcIdx := 17, useRealEnv := false, useBcsCatalogEnv := true }
  | "test_bcs_u16" => some { funcIdx := 18, useRealEnv := false, useBcsCatalogEnv := true }
  | "test_serialized_size_u16" => some { funcIdx := 19, useRealEnv := false, useBcsCatalogEnv := true }
  | "test_constant_size_u16" => some { funcIdx := 20, useRealEnv := false, useBcsCatalogEnv := true }
  | "test_bcs_u32" => some { funcIdx := 21, useRealEnv := false, useBcsCatalogEnv := true }
  | "test_serialized_size_u32" => some { funcIdx := 22, useRealEnv := false, useBcsCatalogEnv := true }
  | "test_constant_size_u32" => some { funcIdx := 23, useRealEnv := false, useBcsCatalogEnv := true }
  | "test_bcs_u256" => some { funcIdx := 24, useRealEnv := false, useBcsCatalogEnv := true }
  | "test_serialized_size_u256" => some { funcIdx := 25, useRealEnv := false, useBcsCatalogEnv := true }
  | "test_constant_size_u256" => some { funcIdx := 26, useRealEnv := false, useBcsCatalogEnv := true }
  | _ => none

/-- `std::option` (`Option<u64>`) difftest catalog — must stay in sync with `MoveModel/OptionCatalog.lean`. -/
private def funcNameToMappingOptionCatalog (base : String) : Option FuncMapping :=
  match base with
  | "test_option_is_none" => some { funcIdx := 0, useRealEnv := false, useOptionCatalogEnv := true }
  | "test_option_is_some" => some { funcIdx := 1, useRealEnv := false, useOptionCatalogEnv := true }
  | "test_option_contains" => some { funcIdx := 2, useRealEnv := false, useOptionCatalogEnv := true }
  | "test_option_get_with_default" => some { funcIdx := 3, useRealEnv := false, useOptionCatalogEnv := true }
  | "test_option_borrow" => some { funcIdx := 4, useRealEnv := false, useOptionCatalogEnv := true }
  | "test_option_fill" => some { funcIdx := 5, useRealEnv := false, useOptionCatalogEnv := true }
  | "test_option_extract" => some { funcIdx := 6, useRealEnv := false, useOptionCatalogEnv := true }
  | "test_option_swap" => some { funcIdx := 7, useRealEnv := false, useOptionCatalogEnv := true }
  | "test_option_swap_or_fill" => some { funcIdx := 8, useRealEnv := false, useOptionCatalogEnv := true }
  | "test_option_destroy_none" => some { funcIdx := 9, useRealEnv := false, useOptionCatalogEnv := true }
  | "test_option_destroy_some" => some { funcIdx := 10, useRealEnv := false, useOptionCatalogEnv := true }
  | "test_option_borrow_with_default" => some { funcIdx := 11, useRealEnv := false, useOptionCatalogEnv := true }
  | "test_option_destroy_with_default" => some { funcIdx := 12, useRealEnv := false, useOptionCatalogEnv := true }
  | "test_option_to_vec" => some { funcIdx := 13, useRealEnv := false, useOptionCatalogEnv := true }
  | "test_option_from_vec" => some { funcIdx := 14, useRealEnv := false, useOptionCatalogEnv := true }
  | "test_option_std_none" => some { funcIdx := 15, useRealEnv := false, useOptionCatalogEnv := true }
  | "test_option_std_some" => some { funcIdx := 16, useRealEnv := false, useOptionCatalogEnv := true }
  | _ => none

/-- `std::bit_vector` difftest catalog — must stay in sync with `MoveModel/BitVectorCatalog.lean`. -/
private def funcNameToMappingBitVectorCatalog (base : String) : Option FuncMapping :=
  match base with
  | "test_bit_vector_new" => some { funcIdx := 0, useRealEnv := false, useBitVectorCatalogEnv := true }
  | "test_bit_vector_set" => some { funcIdx := 1, useRealEnv := false, useBitVectorCatalogEnv := true }
  | "test_bit_vector_unset" => some { funcIdx := 2, useRealEnv := false, useBitVectorCatalogEnv := true }
  | "test_bit_vector_is_index_set" => some { funcIdx := 3, useRealEnv := false, useBitVectorCatalogEnv := true }
  | "test_bit_vector_shift_left" => some { funcIdx := 4, useRealEnv := false, useBitVectorCatalogEnv := true }
  | _ => none

/-- `std::acl` difftest catalog — must stay in sync with `MoveModel/AclCatalog.lean`. -/
private def funcNameToMappingAclCatalog (base : String) : Option FuncMapping :=
  match base with
  | "test_acl_empty" => some { funcIdx := 0, useRealEnv := false, useAclCatalogEnv := true }
  | "test_acl_contains" => some { funcIdx := 1, useRealEnv := false, useAclCatalogEnv := true }
  | "test_acl_add" => some { funcIdx := 2, useRealEnv := false, useAclCatalogEnv := true }
  | "test_acl_remove" => some { funcIdx := 3, useRealEnv := false, useAclCatalogEnv := true }
  | "test_acl_assert_contains" => some { funcIdx := 4, useRealEnv := false, useAclCatalogEnv := true }
  | _ => none

/-- `std::string` UTF-8 difftest catalog — must stay in sync with `MoveModel/StringCatalog.lean`. -/
private def funcNameToMappingStringCatalog (base : String) : Option FuncMapping :=
  match base with
  | "test_string_internal_check_utf8" => some { funcIdx := 0, useRealEnv := false, useStringCatalogEnv := true }
  | "test_string_sub_string" => some { funcIdx := 1, useRealEnv := false, useStringCatalogEnv := true }
  | "test_string_index_of" => some { funcIdx := 2, useRealEnv := false, useStringCatalogEnv := true }
  | "test_string_internal_is_char_boundary" =>
      some { funcIdx := 3, useRealEnv := false, useStringCatalogEnv := true }
  | _ => none

/-- `std::cmp` (scalars incl. `u256`) — sync with `MoveModel/CmpCatalog.lean`. -/
private def funcNameToMappingCmpCatalog (base : String) : Option FuncMapping :=
  match base with
  | "test_cmp_is_eq" => some { funcIdx := 0, useRealEnv := false, useCmpCatalogEnv := true }
  | "test_cmp_is_ne" => some { funcIdx := 1, useRealEnv := false, useCmpCatalogEnv := true }
  | "test_cmp_is_lt" => some { funcIdx := 2, useRealEnv := false, useCmpCatalogEnv := true }
  | "test_cmp_is_le" => some { funcIdx := 3, useRealEnv := false, useCmpCatalogEnv := true }
  | "test_cmp_is_gt" => some { funcIdx := 4, useRealEnv := false, useCmpCatalogEnv := true }
  | "test_cmp_is_ge" => some { funcIdx := 5, useRealEnv := false, useCmpCatalogEnv := true }
  | "test_cmp_bool_is_eq" => some { funcIdx := 6, useRealEnv := false, useCmpCatalogEnv := true }
  | "test_cmp_bool_is_ne" => some { funcIdx := 7, useRealEnv := false, useCmpCatalogEnv := true }
  | "test_cmp_bool_is_lt" => some { funcIdx := 8, useRealEnv := false, useCmpCatalogEnv := true }
  | "test_cmp_bool_is_le" => some { funcIdx := 9, useRealEnv := false, useCmpCatalogEnv := true }
  | "test_cmp_bool_is_gt" => some { funcIdx := 10, useRealEnv := false, useCmpCatalogEnv := true }
  | "test_cmp_bool_is_ge" => some { funcIdx := 11, useRealEnv := false, useCmpCatalogEnv := true }
  | "test_cmp_u8_is_eq" => some { funcIdx := 12, useRealEnv := false, useCmpCatalogEnv := true }
  | "test_cmp_u8_is_ne" => some { funcIdx := 13, useRealEnv := false, useCmpCatalogEnv := true }
  | "test_cmp_u8_is_lt" => some { funcIdx := 14, useRealEnv := false, useCmpCatalogEnv := true }
  | "test_cmp_u8_is_le" => some { funcIdx := 15, useRealEnv := false, useCmpCatalogEnv := true }
  | "test_cmp_u8_is_gt" => some { funcIdx := 16, useRealEnv := false, useCmpCatalogEnv := true }
  | "test_cmp_u8_is_ge" => some { funcIdx := 17, useRealEnv := false, useCmpCatalogEnv := true }
  | "test_cmp_address_is_eq" => some { funcIdx := 18, useRealEnv := false, useCmpCatalogEnv := true }
  | "test_cmp_address_is_ne" => some { funcIdx := 19, useRealEnv := false, useCmpCatalogEnv := true }
  | "test_cmp_address_is_lt" => some { funcIdx := 20, useRealEnv := false, useCmpCatalogEnv := true }
  | "test_cmp_address_is_le" => some { funcIdx := 21, useRealEnv := false, useCmpCatalogEnv := true }
  | "test_cmp_address_is_gt" => some { funcIdx := 22, useRealEnv := false, useCmpCatalogEnv := true }
  | "test_cmp_address_is_ge" => some { funcIdx := 23, useRealEnv := false, useCmpCatalogEnv := true }
  | "test_cmp_u128_is_eq" => some { funcIdx := 24, useRealEnv := false, useCmpCatalogEnv := true }
  | "test_cmp_u128_is_ne" => some { funcIdx := 25, useRealEnv := false, useCmpCatalogEnv := true }
  | "test_cmp_u128_is_lt" => some { funcIdx := 26, useRealEnv := false, useCmpCatalogEnv := true }
  | "test_cmp_u128_is_le" => some { funcIdx := 27, useRealEnv := false, useCmpCatalogEnv := true }
  | "test_cmp_u128_is_gt" => some { funcIdx := 28, useRealEnv := false, useCmpCatalogEnv := true }
  | "test_cmp_u128_is_ge" => some { funcIdx := 29, useRealEnv := false, useCmpCatalogEnv := true }
  | "test_cmp_u16_is_eq" => some { funcIdx := 30, useRealEnv := false, useCmpCatalogEnv := true }
  | "test_cmp_u16_is_ne" => some { funcIdx := 31, useRealEnv := false, useCmpCatalogEnv := true }
  | "test_cmp_u16_is_lt" => some { funcIdx := 32, useRealEnv := false, useCmpCatalogEnv := true }
  | "test_cmp_u16_is_le" => some { funcIdx := 33, useRealEnv := false, useCmpCatalogEnv := true }
  | "test_cmp_u16_is_gt" => some { funcIdx := 34, useRealEnv := false, useCmpCatalogEnv := true }
  | "test_cmp_u16_is_ge" => some { funcIdx := 35, useRealEnv := false, useCmpCatalogEnv := true }
  | "test_cmp_u32_is_eq" => some { funcIdx := 36, useRealEnv := false, useCmpCatalogEnv := true }
  | "test_cmp_u32_is_ne" => some { funcIdx := 37, useRealEnv := false, useCmpCatalogEnv := true }
  | "test_cmp_u32_is_lt" => some { funcIdx := 38, useRealEnv := false, useCmpCatalogEnv := true }
  | "test_cmp_u32_is_le" => some { funcIdx := 39, useRealEnv := false, useCmpCatalogEnv := true }
  | "test_cmp_u32_is_gt" => some { funcIdx := 40, useRealEnv := false, useCmpCatalogEnv := true }
  | "test_cmp_u32_is_ge" => some { funcIdx := 41, useRealEnv := false, useCmpCatalogEnv := true }
  | "test_cmp_u256_is_eq" => some { funcIdx := 42, useRealEnv := false, useCmpCatalogEnv := true }
  | "test_cmp_u256_is_ne" => some { funcIdx := 43, useRealEnv := false, useCmpCatalogEnv := true }
  | "test_cmp_u256_is_lt" => some { funcIdx := 44, useRealEnv := false, useCmpCatalogEnv := true }
  | "test_cmp_u256_is_le" => some { funcIdx := 45, useRealEnv := false, useCmpCatalogEnv := true }
  | "test_cmp_u256_is_gt" => some { funcIdx := 46, useRealEnv := false, useCmpCatalogEnv := true }
  | "test_cmp_u256_is_ge" => some { funcIdx := 47, useRealEnv := false, useCmpCatalogEnv := true }
  | _ => none

private def funcNameToMappingPart1 (base : String) : Option FuncMapping :=
  match base with
  | "test_contains"    => some { funcIdx := 27 }
  | "test_index_of"    => some { funcIdx := 28 }
  | "test_reverse"     => some { funcIdx := 29 }
  | "test_remove"      => some { funcIdx := 30 }
  | "test_swap_remove" => some { funcIdx := 31 }
  | "test_append"      => some { funcIdx := 32 }
  | "test_singleton"   => some { funcIdx := 33 }
  | "test_is_empty"    => some { funcIdx := 5, useRealEnv := false }
  | "test_length"      => some { funcIdx := 4, useRealEnv := false }
  | "test_get_pending_balance_chunks"    => some { funcIdx := 0,  useConfidentialEnv := true, useRealEnv := false }
  | "test_get_actual_balance_chunks"     => some { funcIdx := 1,  useConfidentialEnv := true, useRealEnv := false }
  | "test_get_chunk_size_bits"           => some { funcIdx := 2,  useConfidentialEnv := true, useRealEnv := false }
  | "test_zero_pending_balance_to_bytes_len" => some { funcIdx := 3, useConfidentialEnv := true, useRealEnv := false }
  | "test_zero_actual_balance_to_bytes_len"  => some { funcIdx := 4, useConfidentialEnv := true, useRealEnv := false }
  | "test_is_zero_pending"               => some { funcIdx := 5,  useConfidentialEnv := true, useRealEnv := false }
  | "test_is_zero_actual"                => some { funcIdx := 6,  useConfidentialEnv := true, useRealEnv := false }
  | "test_compress_decompress_roundtrip_pending" => some { funcIdx := 7, useConfidentialEnv := true, useRealEnv := false }
  | "test_compress_decompress_roundtrip_actual"  => some { funcIdx := 8, useConfidentialEnv := true, useRealEnv := false }
  | "test_pending_from_wrong_len_is_none" => some { funcIdx := 9, useConfidentialEnv := true, useRealEnv := false }
  | "test_pending_from_257_zeros_is_none" => some { funcIdx := 9, useConfidentialEnv := true, useRealEnv := false }
  | "test_pending_from_short_len_is_none" => some { funcIdx := 10, useConfidentialEnv := true, useRealEnv := false }
  | "test_pending_roundtrip_bytes_ok"    => some { funcIdx := 11, useConfidentialEnv := true, useRealEnv := false }
  | "test_add_two_zero_pending_stays_zero" => some { funcIdx := 12, useConfidentialEnv := true, useRealEnv := false }
  | "test_add_zero_amount_chunks_equal"  => some { funcIdx := 13, useConfidentialEnv := true, useRealEnv := false }
  | "test_bulletproofs_dst"              => some { funcIdx := 14, useConfidentialEnv := true, useRealEnv := false }
  | "test_bulletproofs_num_bits"        => some { funcIdx := 15, useConfidentialEnv := true, useRealEnv := false }
  | "test_fiat_shamir_withdrawal_sigma_dst" => some { funcIdx := 43, useConfidentialEnv := true, useRealEnv := false }
  | "test_fiat_shamir_transfer_sigma_dst" => some { funcIdx := 44, useConfidentialEnv := true, useRealEnv := false }
  | "test_fiat_shamir_normalization_sigma_dst" => some { funcIdx := 45, useConfidentialEnv := true, useRealEnv := false }
  | "test_fiat_shamir_rotation_sigma_dst" => some { funcIdx := 46, useConfidentialEnv := true, useRealEnv := false }
  | "test_balance_equals_self_pending" => some { funcIdx := 47, useConfidentialEnv := true, useRealEnv := false }
  | "test_balance_c_equals_self_pending" => some { funcIdx := 48, useConfidentialEnv := true, useRealEnv := false }
  | "test_balance_equals_two_pending_zeros" => some { funcIdx := 49, useConfidentialEnv := true, useRealEnv := false }
  | "test_sub_zero_pending_from_zero_stays_zero" => some { funcIdx := 50, useConfidentialEnv := true, useRealEnv := false }
  | "test_fiat_shamir_registration_sigma_dst" => some { funcIdx := 51, useConfidentialEnv := true, useRealEnv := false }
  | "test_fa_stub_balance_answer" => some { funcIdx := 52, useConfidentialEnv := true, useRealEnv := false }
  | "test_fa_stub_write_then_read_balance" =>
      some { funcIdx := 169, useConfidentialEnv := true, useRealEnv := false }
  | "test_deserialize_withdrawal_empty_none" => some { funcIdx := 16, useConfidentialEnv := true, useRealEnv := false }
  | "test_deserialize_transfer_empty_none"   => some { funcIdx := 17, useConfidentialEnv := true, useRealEnv := false }
  | _ => none

private def funcNameToMappingPart2 (base : String) : Option FuncMapping :=
  match base with
  | "test_deserialize_normalization_empty_none" => some { funcIdx := 18, useConfidentialEnv := true, useRealEnv := false }
  | "test_deserialize_rotation_empty_none"    => some { funcIdx := 19, useConfidentialEnv := true, useRealEnv := false }
  | "test_deserialize_withdrawal_short_sigma_is_none" =>
      some { funcIdx := 16, useConfidentialEnv := true, useRealEnv := false }
  | "test_deserialize_transfer_short_sigma_is_none" =>
      some { funcIdx := 17, useConfidentialEnv := true, useRealEnv := false }
  | "test_deserialize_normalization_short_sigma_is_none" =>
      some { funcIdx := 18, useConfidentialEnv := true, useRealEnv := false }
  | "test_deserialize_rotation_short_sigma_is_none" =>
      some { funcIdx := 19, useConfidentialEnv := true, useRealEnv := false }
  | "test_deserialize_withdrawal_layout_ok_is_some" =>
      some { funcIdx := 110, useConfidentialEnv := true, useRealEnv := false }
  | "test_deserialize_normalization_layout_ok_is_some" =>
      some { funcIdx := 111, useConfidentialEnv := true, useRealEnv := false }
  | "test_deserialize_rotation_layout_ok_is_some" =>
      some { funcIdx := 112, useConfidentialEnv := true, useRealEnv := false }
  | "test_deserialize_transfer_layout_ok_is_some" =>
      some { funcIdx := 113, useConfidentialEnv := true, useRealEnv := false }
  | "test_layout_sigma_18_scalars_18_points_byte_length_is_1152" =>
      some { funcIdx := 128, useConfidentialEnv := true, useRealEnv := false }
  | "test_layout_sigma_19_scalars_19_points_byte_length_is_1216" =>
      some { funcIdx := 129, useConfidentialEnv := true, useRealEnv := false }
  | "test_layout_sigma_transfer_base_layout_byte_length_is_1792" =>
      some { funcIdx := 130, useConfidentialEnv := true, useRealEnv := false }
  | "test_layout_sigma_transfer_one_auditor_quad_extension_byte_length_is_1920" =>
      some { funcIdx := 131, useConfidentialEnv := true, useRealEnv := false }
  | "test_deserialize_transfer_layout_extended_one_auditor_ok_is_some" =>
      some { funcIdx := 132, useConfidentialEnv := true, useRealEnv := false }
  | "test_layout_sigma_transfer_two_auditor_quads_extension_byte_length_is_2048" =>
      some { funcIdx := 133, useConfidentialEnv := true, useRealEnv := false }
  | "test_deserialize_transfer_layout_extended_two_auditors_ok_is_some" =>
      some { funcIdx := 134, useConfidentialEnv := true, useRealEnv := false }
  | "test_layout_sigma_transfer_three_auditor_quads_extension_byte_length_is_2176" =>
      some { funcIdx := 135, useConfidentialEnv := true, useRealEnv := false }
  | "test_deserialize_transfer_layout_extended_three_auditors_ok_is_some" =>
      some { funcIdx := 136, useConfidentialEnv := true, useRealEnv := false }
  | "test_layout_sigma_transfer_four_auditor_quads_extension_byte_length_is_2304" =>
      some { funcIdx := 137, useConfidentialEnv := true, useRealEnv := false }
  | "test_deserialize_transfer_layout_extended_four_auditors_ok_is_some" =>
      some { funcIdx := 138, useConfidentialEnv := true, useRealEnv := false }
  | "test_layout_sigma_transfer_five_auditor_quads_extension_byte_length_is_2432" =>
      some { funcIdx := 139, useConfidentialEnv := true, useRealEnv := false }
  | "test_deserialize_transfer_layout_extended_five_auditors_ok_is_some" =>
      some { funcIdx := 140, useConfidentialEnv := true, useRealEnv := false }
  | "test_layout_sigma_transfer_six_auditor_quads_extension_byte_length_is_2560" =>
      some { funcIdx := 141, useConfidentialEnv := true, useRealEnv := false }
  | "test_deserialize_transfer_layout_extended_six_auditors_ok_is_some" =>
      some { funcIdx := 142, useConfidentialEnv := true, useRealEnv := false }
  | "test_layout_sigma_transfer_seven_auditor_quads_extension_byte_length_is_2688" =>
      some { funcIdx := 143, useConfidentialEnv := true, useRealEnv := false }
  | "test_deserialize_transfer_layout_extended_seven_auditors_ok_is_some" =>
      some { funcIdx := 144, useConfidentialEnv := true, useRealEnv := false }
  | "test_layout_sigma_transfer_eight_auditor_quads_extension_byte_length_is_2816" =>
      some { funcIdx := 145, useConfidentialEnv := true, useRealEnv := false }
  | "test_deserialize_transfer_layout_extended_eight_auditors_ok_is_some" =>
      some { funcIdx := 146, useConfidentialEnv := true, useRealEnv := false }
  | "test_layout_sigma_transfer_nine_auditor_quads_extension_byte_length_is_2944" =>
      some { funcIdx := 147, useConfidentialEnv := true, useRealEnv := false }
  | "test_deserialize_transfer_layout_extended_nine_auditors_ok_is_some" =>
      some { funcIdx := 148, useConfidentialEnv := true, useRealEnv := false }
  | "test_layout_sigma_transfer_ten_auditor_quads_extension_byte_length_is_3072" =>
      some { funcIdx := 149, useConfidentialEnv := true, useRealEnv := false }
  | "test_deserialize_transfer_layout_extended_ten_auditors_ok_is_some" =>
      some { funcIdx := 150, useConfidentialEnv := true, useRealEnv := false }
  | "test_layout_sigma_transfer_eleven_auditor_quads_extension_byte_length_is_3200" =>
      some { funcIdx := 151, useConfidentialEnv := true, useRealEnv := false }
  | "test_deserialize_transfer_layout_extended_eleven_auditors_ok_is_some" =>
      some { funcIdx := 152, useConfidentialEnv := true, useRealEnv := false }
  | "test_layout_sigma_transfer_twelve_auditor_quads_extension_byte_length_is_3328" =>
      some { funcIdx := 153, useConfidentialEnv := true, useRealEnv := false }
  | "test_deserialize_transfer_layout_extended_twelve_auditors_ok_is_some" =>
      some { funcIdx := 154, useConfidentialEnv := true, useRealEnv := false }
  | "test_layout_sigma_transfer_thirteen_auditor_quads_extension_byte_length_is_3456" =>
      some { funcIdx := 155, useConfidentialEnv := true, useRealEnv := false }
  | "test_deserialize_transfer_layout_extended_thirteen_auditors_ok_is_some" =>
      some { funcIdx := 156, useConfidentialEnv := true, useRealEnv := false }
  | "test_layout_sigma_transfer_fourteen_auditor_quads_extension_byte_length_is_3584" =>
      some { funcIdx := 157, useConfidentialEnv := true, useRealEnv := false }
  | "test_deserialize_transfer_layout_extended_fourteen_auditors_ok_is_some" =>
      some { funcIdx := 158, useConfidentialEnv := true, useRealEnv := false }
  | "test_layout_sigma_transfer_fifteen_auditor_quads_extension_byte_length_is_3712" =>
      some { funcIdx := 159, useConfidentialEnv := true, useRealEnv := false }
  | "test_deserialize_transfer_layout_extended_fifteen_auditors_ok_is_some" =>
      some { funcIdx := 160, useConfidentialEnv := true, useRealEnv := false }
  | "test_layout_sigma_transfer_sixteen_auditor_quads_extension_byte_length_is_3840" =>
      some { funcIdx := 161, useConfidentialEnv := true, useRealEnv := false }
  | _ => none

private def funcNameToMappingPart3 (base : String) : Option FuncMapping :=
  match base with
  | "test_deserialize_transfer_layout_extended_sixteen_auditors_ok_is_some" =>
      some { funcIdx := 162, useConfidentialEnv := true, useRealEnv := false }
  | "test_layout_sigma_transfer_seventeen_auditor_quads_extension_byte_length_is_3968" =>
      some { funcIdx := 163, useConfidentialEnv := true, useRealEnv := false }
  | "test_deserialize_transfer_layout_extended_seventeen_auditors_ok_is_some" =>
      some { funcIdx := 164, useConfidentialEnv := true, useRealEnv := false }
  | "test_layout_sigma_transfer_eighteen_auditor_quads_extension_byte_length_is_4096" =>
      some { funcIdx := 165, useConfidentialEnv := true, useRealEnv := false }
  | "test_deserialize_transfer_layout_extended_eighteen_auditors_ok_is_some" =>
      some { funcIdx := 166, useConfidentialEnv := true, useRealEnv := false }
  | "test_layout_sigma_transfer_nineteen_auditor_quads_extension_byte_length_is_4224" =>
      some { funcIdx := 167, useConfidentialEnv := true, useRealEnv := false }
  | "test_deserialize_transfer_layout_extended_nineteen_auditors_ok_is_some" =>
      some { funcIdx := 168, useConfidentialEnv := true, useRealEnv := false }
  | "test_layer_reexport_pending_chunks" => some { funcIdx := 0,  useConfidentialEnv := true, useRealEnv := false }
  | "test_layer_reexport_actual_chunks" => some { funcIdx := 1,  useConfidentialEnv := true, useRealEnv := false }
  | "test_layer_reexport_chunk_bits" => some { funcIdx := 2,  useConfidentialEnv := true, useRealEnv := false }
  | "test_elg_pubkey_from_empty_is_none" => some { funcIdx := 20, useConfidentialEnv := true, useRealEnv := false }
  | "test_elg_pubkey_basepoint_roundtrip" => some { funcIdx := 21, useConfidentialEnv := true, useRealEnv := false }
  | "test_elg_ciphertext_from_bytes_wrong_len" => some { funcIdx := 22, useConfidentialEnv := true, useRealEnv := false }
  | "test_elg_two_zero_plaintext_ciphertexts_equal" => some { funcIdx := 23, useConfidentialEnv := true, useRealEnv := false }
  | "test_elg_compress_decompress_ciphertext" => some { funcIdx := 24, useConfidentialEnv := true, useRealEnv := false }
  | "test_elg_ciphertext_add_sub" => some { funcIdx := 25, useConfidentialEnv := true, useRealEnv := false }
  | "test_elg_compress_ciphertext_twice_same" => some { funcIdx := 26, useConfidentialEnv := true, useRealEnv := false }
  | "test_elg_ciphertext_to_bytes_len_64" => some { funcIdx := 27, useConfidentialEnv := true, useRealEnv := false }
  | "test_elg_ciphertext_into_from_points" => some { funcIdx := 28, useConfidentialEnv := true, useRealEnv := false }
  | "test_elg_get_value_component_is_identity_for_zero_plaintext" => some { funcIdx := 29, useConfidentialEnv := true, useRealEnv := false }
  | "test_elg_pubkey_to_point_roundtrip" => some { funcIdx := 30, useConfidentialEnv := true, useRealEnv := false }
  | "test_elg_ciphertext_to_bytes_roundtrip" => some { funcIdx := 31, useConfidentialEnv := true, useRealEnv := false }
  | "test_elg_ciphertext_add_assign_matches_add" => some { funcIdx := 53, useConfidentialEnv := true, useRealEnv := false }
  | "test_elg_ciphertext_sub_assign_matches_sub" => some { funcIdx := 54, useConfidentialEnv := true, useRealEnv := false }
  | "test_actual_roundtrip_bytes_ok" => some { funcIdx := 55, useConfidentialEnv := true, useRealEnv := false }
  | "test_is_zero_pending_u64_zero" => some { funcIdx := 56, useConfidentialEnv := true, useRealEnv := false }
  | "test_actual_from_wrong_len_is_none" => some { funcIdx := 57, useConfidentialEnv := true, useRealEnv := false }
  | "test_actual_from_513_zeros_is_none" => some { funcIdx := 57, useConfidentialEnv := true, useRealEnv := false }
  | "test_elg_ciphertext_sub_self_is_zero" => some { funcIdx := 58, useConfidentialEnv := true, useRealEnv := false }
  | "test_balance_c_equals_two_pending_u64_zeros" =>
      some { funcIdx := 59, useConfidentialEnv := true, useRealEnv := false }
  | "test_add_two_zero_actual_stays_zero" => some { funcIdx := 60, useConfidentialEnv := true, useRealEnv := false }
  | "test_actual_from_short_len_is_none" => some { funcIdx := 61, useConfidentialEnv := true, useRealEnv := false }
  | "test_sub_zero_actual_from_zero_stays_zero" =>
      some { funcIdx := 62, useConfidentialEnv := true, useRealEnv := false }
  | "test_balance_equals_two_actual_zeros" =>
      some { funcIdx := 63, useConfidentialEnv := true, useRealEnv := false }
  | "test_balance_c_equals_self_actual" => some { funcIdx := 64, useConfidentialEnv := true, useRealEnv := false }
  | "test_decompress_compressed_pending_matches_plain_zero" =>
      some { funcIdx := 65, useConfidentialEnv := true, useRealEnv := false }
  | "test_elg_ciphertext_add_commutes_at_zero" =>
      some { funcIdx := 66, useConfidentialEnv := true, useRealEnv := false }
  | "test_balance_equals_self_actual" => some { funcIdx := 67, useConfidentialEnv := true, useRealEnv := false }
  | "test_is_zero_decompressed_compressed_pending" =>
      some { funcIdx := 68, useConfidentialEnv := true, useRealEnv := false }
  | "test_decompress_compressed_actual_matches_plain_zero" =>
      some { funcIdx := 69, useConfidentialEnv := true, useRealEnv := false }
  | "test_is_zero_decompressed_compressed_actual" =>
      some { funcIdx := 70, useConfidentialEnv := true, useRealEnv := false }
  | "test_balance_c_equals_two_actual_zeros" =>
      some { funcIdx := 71, useConfidentialEnv := true, useRealEnv := false }
  | "test_elg_ciphertext_add_associative_three_zeros" =>
      some { funcIdx := 72, useConfidentialEnv := true, useRealEnv := false }
  | "test_pending_roundtrip_bytes_balance_equals_self" =>
      some { funcIdx := 73, useConfidentialEnv := true, useRealEnv := false }
  | _ => none

private def funcNameToMappingPart4 (base : String) : Option FuncMapping :=
  match base with
  | "test_balance_c_equals_two_pending_plain_zeros" =>
      some { funcIdx := 74, useConfidentialEnv := true, useRealEnv := false }
  | "test_actual_roundtrip_bytes_balance_equals_self" =>
      some { funcIdx := 75, useConfidentialEnv := true, useRealEnv := false }
  | "test_is_zero_pending_u64_one_is_false" =>
      some { funcIdx := 76, useConfidentialEnv := true, useRealEnv := false }
  | "test_elg_pubkey_from_short_bytes_is_none" =>
      some { funcIdx := 77, useConfidentialEnv := true, useRealEnv := false }
  | "test_elg_ciphertext_from_63_bytes_is_none" =>
      some { funcIdx := 78, useConfidentialEnv := true, useRealEnv := false }
  | "test_balance_equals_pending_plain_and_u64_zero" =>
      some { funcIdx := 79, useConfidentialEnv := true, useRealEnv := false }
  | "test_balance_c_equals_pending_plain_and_u64_zero" =>
      some { funcIdx := 80, useConfidentialEnv := true, useRealEnv := false }
  | "test_add_plain_zero_to_u64_zero_pending_stays_zero" =>
      some { funcIdx := 81, useConfidentialEnv := true, useRealEnv := false }
  | "test_add_u64_zero_to_plain_zero_pending_stays_zero" =>
      some { funcIdx := 82, useConfidentialEnv := true, useRealEnv := false }
  | "test_sub_u64_zero_from_plain_zero_pending_stays_zero" =>
      some { funcIdx := 83, useConfidentialEnv := true, useRealEnv := false }
  | "test_sub_u64_zero_from_u64_zero_pending_stays_zero" =>
      some { funcIdx := 84, useConfidentialEnv := true, useRealEnv := false }
  | "test_pending_u64_zero_roundtrip_bytes_balance_equals_self" =>
      some { funcIdx := 85, useConfidentialEnv := true, useRealEnv := false }
  | "test_compress_decompress_pending_u64_zero_eq_self" =>
      some { funcIdx := 86, useConfidentialEnv := true, useRealEnv := false }
  | "test_balance_equals_two_u64_zero_pending" =>
      some { funcIdx := 87, useConfidentialEnv := true, useRealEnv := false }
  | "test_split_into_chunks_u64_second_chunk" =>
      some { funcIdx := 88, useConfidentialEnv := true, useRealEnv := false }
  | "test_split_into_chunks_u128_second_chunk" =>
      some { funcIdx := 89, useConfidentialEnv := true, useRealEnv := false }
  | "test_elg_ciphertext_from_65_bytes_is_none" =>
      some { funcIdx := 90, useConfidentialEnv := true, useRealEnv := false }
  | "test_elg_pubkey_from_31_bytes_is_none" =>
      some { funcIdx := 91, useConfidentialEnv := true, useRealEnv := false }
  | "test_elg_ciphertext_sub_then_add_zero_restores" =>
      some { funcIdx := 92, useConfidentialEnv := true, useRealEnv := false }
  | "test_split_into_chunks_u64_third_chunk" =>
      some { funcIdx := 93, useConfidentialEnv := true, useRealEnv := false }
  | "test_split_into_chunks_u64_fourth_chunk" =>
      some { funcIdx := 94, useConfidentialEnv := true, useRealEnv := false }
  | "test_split_into_chunks_u128_third_chunk" =>
      some { funcIdx := 95, useConfidentialEnv := true, useRealEnv := false }
  | "test_split_into_chunks_u128_fourth_chunk" =>
      some { funcIdx := 96, useConfidentialEnv := true, useRealEnv := false }
  | "test_split_into_chunks_u128_fifth_chunk" =>
      some { funcIdx := 97, useConfidentialEnv := true, useRealEnv := false }
  | "test_split_into_chunks_u128_sixth_chunk" =>
      some { funcIdx := 98, useConfidentialEnv := true, useRealEnv := false }
  | "test_is_zero_actual_after_compress_decompress_no_randomness" =>
      some { funcIdx := 99, useConfidentialEnv := true, useRealEnv := false }
  | "test_split_into_chunks_u128_seventh_chunk" =>
      some { funcIdx := 100, useConfidentialEnv := true, useRealEnv := false }
  | "test_split_into_chunks_u128_eighth_chunk" =>
      some { funcIdx := 101, useConfidentialEnv := true, useRealEnv := false }
  | "test_split_into_chunks_u64_first_chunk" => some { funcIdx := 32, useConfidentialEnv := true, useRealEnv := false }
  | "test_split_into_chunks_u128_first_chunk" => some { funcIdx := 33, useConfidentialEnv := true, useRealEnv := false }
  | "test_bulletproofs_dst_sha3_512" => some { funcIdx := 34, useConfidentialEnv := true, useRealEnv := false }
  | "test_registration_helpers_roundtrip" => some { funcIdx := 35, useConfidentialEnv := true, useRealEnv := false }
  | "test_serialize_auditor_eks_empty_framework" => some { funcIdx := 36, useConfidentialEnv := true, useRealEnv := false }
  | "test_serialize_auditor_eks_empty_mirror" => some { funcIdx := 36, useConfidentialEnv := true, useRealEnv := false }
  | "test_serialize_auditor_amounts_empty_framework" => some { funcIdx := 37, useConfidentialEnv := true, useRealEnv := false }
  | "test_serialize_auditor_amounts_empty_mirror" => some { funcIdx := 37, useConfidentialEnv := true, useRealEnv := false }
  | "test_serialize_auditor_eks_single_a_point_framework" =>
      some { funcIdx := 114, useConfidentialEnv := true, useRealEnv := false }
  | "test_serialize_auditor_amounts_one_zero_pending_framework" =>
      some { funcIdx := 115, useConfidentialEnv := true, useRealEnv := false }
  | "test_serialize_auditor_eks_two_a_points_framework" =>
      some { funcIdx := 116, useConfidentialEnv := true, useRealEnv := false }
  | "test_serialize_auditor_eks_three_a_points_framework" =>
      some { funcIdx := 124, useConfidentialEnv := true, useRealEnv := false }
  | "test_serialize_auditor_eks_four_a_points_framework" =>
      some { funcIdx := 125, useConfidentialEnv := true, useRealEnv := false }
  | "test_serialize_auditor_eks_five_a_points_framework" =>
      some { funcIdx := 126, useConfidentialEnv := true, useRealEnv := false }
  | "test_serialize_auditor_eks_six_a_points_framework" =>
      some { funcIdx := 127, useConfidentialEnv := true, useRealEnv := false }
  | "test_serialize_auditor_amounts_two_zero_pending_framework" =>
      some { funcIdx := 117, useConfidentialEnv := true, useRealEnv := false }
  | _ => none

private def funcNameToMappingPart5 (base : String) : Option FuncMapping :=
  match base with
  | "test_serialize_auditor_amounts_one_u64_one_pending_framework" =>
      some { funcIdx := 118, useConfidentialEnv := true, useRealEnv := false }
  | "test_serialize_auditor_amounts_one_actual_zero_framework" =>
      some { funcIdx := 119, useConfidentialEnv := true, useRealEnv := false }
  | "test_serialize_auditor_amounts_zero_then_u64_one_framework" =>
      some { funcIdx := 120, useConfidentialEnv := true, useRealEnv := false }
  | "test_serialize_auditor_amounts_u64_one_then_zero_framework" =>
      some { funcIdx := 121, useConfidentialEnv := true, useRealEnv := false }
  | "test_serialize_auditor_amounts_actual_zero_then_u64_one_pending_framework" =>
      some { funcIdx := 122, useConfidentialEnv := true, useRealEnv := false }
  | "test_serialize_auditor_amounts_u64_one_pending_then_actual_zero_framework" =>
      some { funcIdx := 123, useConfidentialEnv := true, useRealEnv := false }
  | "test_registration_fs_message_golden_move" => some { funcIdx := 38, useConfidentialEnv := true, useRealEnv := false }
  | "test_read_std_counter" => some { funcIdx := 39, useConfidentialEnv := true, useRealEnv := false }
  | "confidential_asset_e2e::confidential_asset_register_deposit_rollover_and_gas" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "confidential_asset_e2e::confidential_asset_rollover_and_freeze_only" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "confidential_asset_e2e::confidential_asset_rotate_encryption_key_and_unfreeze_only" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "confidential_asset_e2e::confidential_asset_verify_actual_balance_matches_after_deposit_rollover_freeze_and_rotate_encryption_key_and_unfreeze_only" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "confidential_asset_e2e::confidential_asset_verify_pending_balance_zero_after_deposit_rollover_freeze_and_rotate_encryption_key_and_unfreeze_only" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "confidential_asset_e2e::confidential_asset_is_frozen_false_after_deposit_rollover_freeze_and_rotate_encryption_key_and_unfreeze_only" =>
      some { funcIdx := 102, useConfidentialEnv := true, useRealEnv := false }
  | "confidential_asset_e2e::confidential_asset_encryption_key_view_matches_new_ek_after_deposit_rollover_freeze_and_rotate_encryption_key_and_unfreeze_only" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "confidential_asset_e2e::confidential_asset_verify_actual_balance_rejects_stale_dk_after_deposit_rollover_freeze_and_rotate_encryption_key_and_unfreeze_only" =>
      some { funcIdx := 102, useConfidentialEnv := true, useRealEnv := false }
  | "confidential_asset_e2e::confidential_asset_verify_pending_balance_rejects_nonzero_with_new_dk_after_deposit_rollover_freeze_and_rotate_encryption_key_and_unfreeze_only" =>
      some { funcIdx := 102, useConfidentialEnv := true, useRealEnv := false }
  | "confidential_asset_e2e::confidential_asset_verify_actual_balance_rejects_wrong_amount_after_deposit_rollover_freeze_and_rotate_encryption_key_and_unfreeze_only" =>
      some { funcIdx := 102, useConfidentialEnv := true, useRealEnv := false }
  | "confidential_asset_e2e::confidential_asset_verify_actual_balance_rejects_amount_plus_one_after_deposit_rollover_freeze_and_rotate_encryption_key_and_unfreeze_only" =>
      some { funcIdx := 102, useConfidentialEnv := true, useRealEnv := false }
  | "confidential_asset_e2e::confidential_asset_is_normalized_true_after_deposit_rollover_freeze_and_rotate_encryption_key_and_unfreeze_only" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "confidential_asset_e2e::confidential_asset_verify_pending_balance_matches_second_deposit_after_rotate_encryption_key_and_unfreeze_only" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "confidential_asset_e2e::confidential_asset_verify_actual_balance_matches_first_deposit_after_second_deposit_post_rotate_encryption_key_and_unfreeze_only" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "confidential_asset_e2e::confidential_asset_verify_pending_balance_rejects_zero_after_second_deposit_post_rotate_encryption_key_and_unfreeze_only" =>
      some { funcIdx := 102, useConfidentialEnv := true, useRealEnv := false }
  | "confidential_asset_e2e::confidential_asset_verify_actual_balance_rejects_zero_after_rotate_encryption_key_and_unfreeze_when_actual_nonzero_only" =>
      some { funcIdx := 102, useConfidentialEnv := true, useRealEnv := false }
  | "confidential_asset_e2e::confidential_asset_balance_after_deposit_rollover_freeze_and_rotate_encryption_key_and_unfreeze_only" =>
      some { funcIdx := 177, useConfidentialEnv := true, useRealEnv := false }
  | "confidential_asset_e2e::confidential_asset_pending_balance_view_return_len_265_after_deposit_rollover_freeze_and_rotate_encryption_key_and_unfreeze_only" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "confidential_asset_e2e::confidential_asset_actual_balance_view_return_len_529_after_deposit_rollover_freeze_and_rotate_encryption_key_and_unfreeze_only" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "confidential_asset_e2e::confidential_asset_has_confidential_asset_store_true_after_deposit_rollover_freeze_and_rotate_encryption_key_and_unfreeze_only" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "confidential_asset_e2e::confidential_asset_verify_pending_balance_rejects_stale_first_deposit_after_second_deposit_post_rotate_encryption_key_and_unfreeze_only" =>
      some { funcIdx := 102, useConfidentialEnv := true, useRealEnv := false }
  | "confidential_asset_e2e::confidential_asset_balance_matches_10003_after_post_unfreeze_deposit_post_rotate_encryption_key_and_unfreeze_only" =>
      some { funcIdx := 178, useConfidentialEnv := true, useRealEnv := false }
  | "confidential_asset_e2e::confidential_asset_is_token_allowed_true_after_deposit_rollover_freeze_and_rotate_encryption_key_and_unfreeze_only" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "confidential_asset_e2e::confidential_asset_get_auditor_returns_none_after_deposit_rollover_freeze_and_rotate_encryption_key_and_unfreeze_only" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "confidential_asset_e2e::confidential_asset_verify_pending_balance_matches_sum_after_two_post_unfreeze_deposits_post_rotate_encryption_key_and_unfreeze_only" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "confidential_asset_e2e::confidential_asset_is_allow_list_enabled_false_after_deposit_rollover_freeze_and_rotate_encryption_key_and_unfreeze_only" =>
      some { funcIdx := 102, useConfidentialEnv := true, useRealEnv := false }
  | "confidential_asset_e2e::confidential_asset_verify_pending_balance_rejects_wrong_sum_after_two_post_unfreeze_deposits_post_rotate_encryption_key_and_unfreeze_only" =>
      some { funcIdx := 102, useConfidentialEnv := true, useRealEnv := false }
  | "confidential_asset_e2e::confidential_asset_verify_actual_balance_rejects_wrong_amount_after_two_post_unfreeze_deposits_post_rotate_encryption_key_and_unfreeze_only" =>
      some { funcIdx := 102, useConfidentialEnv := true, useRealEnv := false }
  | "confidential_asset_e2e::confidential_asset_balance_matches_8901_after_two_post_unfreeze_deposits_post_rotate_encryption_key_and_unfreeze_only" =>
      some { funcIdx := 179, useConfidentialEnv := true, useRealEnv := false }
  | "confidential_asset_e2e::confidential_asset_verify_pending_balance_rejects_sum_plus_one_after_two_post_unfreeze_deposits_post_rotate_encryption_key_and_unfreeze_only" =>
      some { funcIdx := 102, useConfidentialEnv := true, useRealEnv := false }
  | "confidential_asset_e2e::confidential_asset_verify_actual_balance_rejects_amount_plus_one_after_two_post_unfreeze_deposits_post_rotate_encryption_key_and_unfreeze_only" =>
      some { funcIdx := 102, useConfidentialEnv := true, useRealEnv := false }
  | "confidential_asset_e2e::confidential_asset_encryption_key_view_matches_new_ek_after_two_post_unfreeze_deposits_post_rotate_encryption_key_and_unfreeze_only" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "confidential_asset_e2e::confidential_asset_is_frozen_false_after_two_post_unfreeze_deposits_post_rotate_encryption_key_and_unfreeze_only" =>
      some { funcIdx := 102, useConfidentialEnv := true, useRealEnv := false }
  | "confidential_asset_e2e::confidential_asset_balance_matches_6601_after_three_post_unfreeze_deposits_post_rotate_encryption_key_and_unfreeze_only" =>
      some { funcIdx := 180, useConfidentialEnv := true, useRealEnv := false }
  | "confidential_asset_e2e::confidential_asset_is_normalized_true_after_three_post_unfreeze_deposits_post_rotate_encryption_key_and_unfreeze_only" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "confidential_asset_e2e::confidential_asset_has_confidential_asset_store_true_after_three_post_unfreeze_deposits_post_rotate_encryption_key_and_unfreeze_only" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "confidential_asset_e2e::confidential_asset_verify_pending_balance_matches_sum_after_three_post_unfreeze_deposits_post_rotate_encryption_key_and_unfreeze_only" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "confidential_asset_e2e::confidential_asset_verify_pending_balance_rejects_zero_after_three_post_unfreeze_deposits_post_rotate_encryption_key_and_unfreeze_only" =>
      some { funcIdx := 102, useConfidentialEnv := true, useRealEnv := false }
  | "confidential_asset_e2e::confidential_asset_verify_actual_balance_rejects_zero_after_three_post_unfreeze_deposits_post_rotate_encryption_key_and_unfreeze_when_actual_nonzero_only" =>
      some { funcIdx := 102, useConfidentialEnv := true, useRealEnv := false }
  | "confidential_asset_e2e::confidential_asset_balance_matches_7111_after_four_post_unfreeze_deposits_post_rotate_encryption_key_and_unfreeze_only" =>
      some { funcIdx := 181, useConfidentialEnv := true, useRealEnv := false }
  | "confidential_asset_e2e::confidential_asset_rotate_encryption_key_aborts_when_pending_nonzero_after_deposit_rollover_and_second_deposit_only" =>
      some { funcIdx := 176, useConfidentialEnv := true, useRealEnv := false }
  | "confidential_asset_e2e::confidential_asset_rotate_encryption_key_after_freeze_only" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "confidential_asset_e2e::confidential_asset_is_normalized_false_after_rollover_only" =>
      some { funcIdx := 102, useConfidentialEnv := true, useRealEnv := false }
  | "confidential_asset_e2e::confidential_asset_is_frozen_true_after_freeze_token_only" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "confidential_asset_e2e::confidential_asset_has_confidential_asset_store_false_before_register_only" =>
      some { funcIdx := 102, useConfidentialEnv := true, useRealEnv := false }
  | "confidential_asset_e2e::confidential_asset_encryption_key_view_matches_registered_ek_only" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "confidential_asset_e2e::confidential_asset_encryption_key_view_matches_new_ek_after_deposit_rollover_and_rotate_only" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "confidential_asset_e2e::confidential_asset_verify_actual_balance_matches_after_deposit_rollover_and_rotate_only" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "confidential_asset_e2e::confidential_asset_verify_actual_balance_rejects_stale_dk_after_deposit_rollover_and_rotate_only" =>
      some { funcIdx := 102, useConfidentialEnv := true, useRealEnv := false }
  | "confidential_asset_e2e::confidential_asset_verify_pending_balance_zero_after_deposit_rollover_and_rotate_only" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "confidential_asset_e2e::confidential_asset_verify_pending_balance_rejects_nonzero_with_stale_dk_after_deposit_rollover_and_rotate_only" =>
      some { funcIdx := 102, useConfidentialEnv := true, useRealEnv := false }
  | "confidential_asset_e2e::confidential_asset_verify_pending_balance_rejects_nonzero_with_new_dk_after_deposit_rollover_and_rotate_only" =>
      some { funcIdx := 102, useConfidentialEnv := true, useRealEnv := false }
  | "confidential_asset_e2e::confidential_asset_verify_actual_balance_rejects_wrong_amount_after_deposit_rollover_and_rotate_only" =>
      some { funcIdx := 102, useConfidentialEnv := true, useRealEnv := false }
  | "confidential_asset_e2e::confidential_asset_verify_pending_balance_rejects_stale_deposit_amount_after_deposit_rollover_and_rotate_only" =>
      some { funcIdx := 102, useConfidentialEnv := true, useRealEnv := false }
  | "confidential_asset_e2e::confidential_asset_verify_actual_balance_rejects_zero_after_deposit_rollover_and_rotate_when_actual_nonzero_only" =>
      some { funcIdx := 102, useConfidentialEnv := true, useRealEnv := false }
  | "confidential_asset_e2e::confidential_asset_verify_pending_balance_rejects_wrong_amount_after_deposit_rollover_and_rotate_only" =>
      some { funcIdx := 102, useConfidentialEnv := true, useRealEnv := false }
  | "confidential_asset_e2e::confidential_asset_verify_actual_balance_rejects_amount_plus_one_after_deposit_rollover_and_rotate_only" =>
      some { funcIdx := 102, useConfidentialEnv := true, useRealEnv := false }
  | "confidential_asset_e2e::confidential_asset_verify_actual_balance_matches_after_deposit_rollover_withdraw_and_rotate_only" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "confidential_asset_e2e::confidential_asset_verify_actual_balance_rejects_stale_dk_after_deposit_rollover_withdraw_and_rotate_only" =>
      some { funcIdx := 102, useConfidentialEnv := true, useRealEnv := false }
  | "confidential_asset_e2e::confidential_asset_verify_actual_balance_matches_sum_after_two_deposits_rollover_and_rotate_only" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "confidential_asset_e2e::confidential_asset_verify_pending_balance_rejects_stale_sum_after_two_deposits_rollover_and_rotate_only" =>
      some { funcIdx := 102, useConfidentialEnv := true, useRealEnv := false }
  | "confidential_asset_e2e::confidential_asset_verify_pending_balance_zero_after_deposit_rollover_withdraw_and_rotate_only" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "confidential_asset_e2e::confidential_asset_verify_actual_balance_rejects_wrong_amount_after_deposit_rollover_withdraw_and_rotate_only" =>
      some { funcIdx := 102, useConfidentialEnv := true, useRealEnv := false }
  | "confidential_asset_e2e::confidential_asset_verify_actual_balance_rejects_stale_dk_after_deposit_rollover_normalize_and_rotate_only" =>
      some { funcIdx := 102, useConfidentialEnv := true, useRealEnv := false }
  | "confidential_asset_e2e::confidential_asset_verify_pending_balance_rejects_nonzero_with_new_dk_after_deposit_rollover_normalize_and_rotate_only" =>
      some { funcIdx := 102, useConfidentialEnv := true, useRealEnv := false }
  | "confidential_asset_e2e::confidential_asset_verify_actual_balance_rejects_wrong_amount_after_deposit_rollover_normalize_and_rotate_only" =>
      some { funcIdx := 102, useConfidentialEnv := true, useRealEnv := false }
  | "confidential_asset_e2e::confidential_asset_verify_actual_balance_matches_after_deposit_rollover_normalize_and_rotate_only" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "confidential_asset_e2e::confidential_asset_encryption_key_view_matches_new_ek_after_deposit_rollover_normalize_and_rotate_only" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "confidential_asset_e2e::confidential_asset_verify_pending_balance_zero_after_deposit_rollover_normalize_and_rotate_only" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "confidential_asset_e2e::confidential_asset_verify_actual_balance_rejects_stale_dk_after_deposit_rollover_and_freeze_and_rotate_only" =>
      some { funcIdx := 102, useConfidentialEnv := true, useRealEnv := false }
  | "confidential_asset_e2e::confidential_asset_verify_pending_balance_rejects_nonzero_with_new_dk_after_deposit_rollover_and_freeze_and_rotate_only" =>
      some { funcIdx := 102, useConfidentialEnv := true, useRealEnv := false }
  | "confidential_asset_e2e::confidential_asset_verify_actual_balance_rejects_wrong_amount_after_deposit_rollover_and_freeze_and_rotate_only" =>
      some { funcIdx := 102, useConfidentialEnv := true, useRealEnv := false }
  | "confidential_asset_e2e::confidential_asset_is_frozen_true_after_deposit_rollover_and_freeze_and_rotate_only" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "confidential_asset_e2e::confidential_asset_verify_actual_balance_matches_after_deposit_rollover_and_freeze_and_rotate_only" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "confidential_asset_e2e::confidential_asset_encryption_key_view_matches_new_ek_after_deposit_rollover_and_freeze_and_rotate_only" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "confidential_asset_e2e::confidential_asset_verify_pending_balance_zero_after_deposit_rollover_and_freeze_and_rotate_only" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "confidential_asset_e2e::confidential_asset_has_confidential_asset_store_true_after_register_only" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "confidential_asset_e2e::confidential_asset_is_token_allowed_true_for_metadata_only" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "confidential_asset_e2e::confidential_asset_is_allow_list_enabled_false_in_tests_only" =>
      some { funcIdx := 102, useConfidentialEnv := true, useRealEnv := false }
  | "confidential_asset_e2e::confidential_asset_get_auditor_returns_none_for_move_metadata_no_fa_config_only" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "confidential_asset_e2e::confidential_asset_is_normalized_true_after_register_only" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "confidential_asset_e2e::confidential_asset_is_frozen_false_after_unfreeze_only" =>
      some { funcIdx := 102, useConfidentialEnv := true, useRealEnv := false }
  | "confidential_asset_e2e::confidential_asset_is_frozen_false_after_register_only" =>
      some { funcIdx := 102, useConfidentialEnv := true, useRealEnv := false }
  | "confidential_asset_e2e::confidential_asset_has_confidential_asset_store_false_for_peer_not_registered" =>
      some { funcIdx := 102, useConfidentialEnv := true, useRealEnv := false }
  | "confidential_asset_e2e::confidential_asset_is_frozen_true_after_rollover_and_freeze_only" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "confidential_asset_e2e::confidential_asset_is_normalized_true_after_normalize_only" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "confidential_asset_e2e::confidential_asset_verify_actual_balance_matches_after_deposit_rollover_and_normalize_only" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "confidential_asset_e2e::confidential_asset_verify_pending_balance_zero_after_deposit_rollover_and_normalize_only" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "confidential_asset_e2e::confidential_asset_verify_actual_balance_rejects_wrong_amount_after_deposit_rollover_and_normalize_only" =>
      some { funcIdx := 102, useConfidentialEnv := true, useRealEnv := false }
  | "confidential_asset_e2e::confidential_asset_verify_actual_balance_rejects_amount_plus_one_after_deposit_rollover_and_normalize_only" =>
      some { funcIdx := 102, useConfidentialEnv := true, useRealEnv := false }
  | "confidential_asset_e2e::confidential_asset_verify_actual_balance_rejects_zero_after_deposit_rollover_and_normalize_when_actual_nonzero" =>
      some { funcIdx := 102, useConfidentialEnv := true, useRealEnv := false }
  | "confidential_asset_e2e::confidential_asset_verify_pending_balance_rejects_nonzero_after_deposit_rollover_and_normalize_only" =>
      some { funcIdx := 102, useConfidentialEnv := true, useRealEnv := false }
  | "confidential_asset_e2e::confidential_asset_verify_pending_balance_rejects_stale_deposit_amount_after_deposit_rollover_and_normalize_only" =>
      some { funcIdx := 102, useConfidentialEnv := true, useRealEnv := false }
  | "confidential_asset_e2e::confidential_asset_balance_matches_single_deposit_only" =>
      some { funcIdx := 103, useConfidentialEnv := true, useRealEnv := false }
  | "confidential_asset_e2e::confidential_asset_balance_after_two_deposits_only" =>
      some { funcIdx := 104, useConfidentialEnv := true, useRealEnv := false }
  | "confidential_asset_e2e::confidential_asset_balance_after_deposit_and_withdraw_only" =>
      some { funcIdx := 105, useConfidentialEnv := true, useRealEnv := false }
  | "confidential_asset_e2e::confidential_asset_balance_after_deposit_to_only" =>
      some { funcIdx := 106, useConfidentialEnv := true, useRealEnv := false }
  | "confidential_asset_e2e::confidential_asset_balance_after_confidential_transfer_only" =>
      some { funcIdx := 107, useConfidentialEnv := true, useRealEnv := false }
  | "confidential_asset_e2e::confidential_asset_balance_after_transfer_and_second_deposit_only" =>
      some { funcIdx := 108, useConfidentialEnv := true, useRealEnv := false }
  | "confidential_asset_e2e::confidential_asset_balance_after_two_deposit_to_only" =>
      some { funcIdx := 109, useConfidentialEnv := true, useRealEnv := false }
  | "confidential_asset_e2e::confidential_asset_freeze_then_unfreeze_only" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "confidential_asset_e2e::confidential_asset_rollover_then_normalize_only" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "confidential_asset_e2e::confidential_asset_deposit_to_cross_party_only" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "confidential_asset_e2e::confidential_asset_withdraw_entry_self_only" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "confidential_asset_e2e::confidential_asset_transfer_withdraw_rotate_and_auditor" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "confidential_asset_e2e::confidential_asset_pending_balance_view_return_len_265_after_register_only" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "confidential_asset_e2e::confidential_asset_actual_balance_view_return_len_529_after_register_only" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "confidential_asset_e2e::confidential_asset_pending_balance_view_matches_deposit" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "confidential_asset_e2e::confidential_asset_verify_pending_balance_zero_after_register_only" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "confidential_asset_e2e::confidential_asset_verify_pending_balance_rejects_nonzero_after_register_only" =>
      some { funcIdx := 102, useConfidentialEnv := true, useRealEnv := false }
  | "confidential_asset_e2e::confidential_asset_verify_actual_balance_zero_after_register_only" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "confidential_asset_e2e::confidential_asset_verify_actual_balance_rejects_nonzero_after_register_only" =>
      some { funcIdx := 102, useConfidentialEnv := true, useRealEnv := false }
  | "confidential_asset_e2e::confidential_asset_verify_actual_balance_matches_after_deposit_and_rollover_only" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "confidential_asset_e2e::confidential_asset_verify_actual_balance_matches_sum_after_two_deposits_and_rollover_only" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "confidential_asset_e2e::confidential_asset_verify_actual_balance_matches_after_deposit_rollover_and_withdraw_only" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "confidential_asset_e2e::confidential_asset_verify_actual_balance_rejects_wrong_amount_after_deposit_rollover_and_withdraw_only" =>
      some { funcIdx := 102, useConfidentialEnv := true, useRealEnv := false }
  | "confidential_asset_e2e::confidential_asset_verify_pending_balance_zero_after_deposit_rollover_and_withdraw_only" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "confidential_asset_e2e::confidential_asset_verify_actual_balance_rejects_wrong_sum_after_two_deposits_and_rollover_only" =>
      some { funcIdx := 102, useConfidentialEnv := true, useRealEnv := false }
  | "confidential_asset_e2e::confidential_asset_verify_pending_balance_zero_after_deposit_and_rollover_only" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "confidential_asset_e2e::confidential_asset_verify_pending_balance_matches_after_deposit_only_no_rollover" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "confidential_asset_e2e::confidential_asset_verify_pending_balance_matches_sum_after_two_deposits_no_rollover" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "confidential_asset_e2e::confidential_asset_verify_pending_balance_rejects_wrong_sum_after_two_deposits_no_rollover" =>
      some { funcIdx := 102, useConfidentialEnv := true, useRealEnv := false }
  | "confidential_asset_e2e::confidential_asset_verify_pending_balance_rejects_zero_after_two_deposits_no_rollover" =>
      some { funcIdx := 102, useConfidentialEnv := true, useRealEnv := false }
  | "confidential_asset_e2e::confidential_asset_verify_pending_balance_rejects_zero_after_deposit_only_no_rollover" =>
      some { funcIdx := 102, useConfidentialEnv := true, useRealEnv := false }
  | "confidential_asset_e2e::confidential_asset_verify_pending_balance_rejects_wrong_amount_after_deposit_only_no_rollover" =>
      some { funcIdx := 102, useConfidentialEnv := true, useRealEnv := false }
  | "confidential_asset_e2e::confidential_asset_verify_actual_balance_zero_after_deposit_only_no_rollover" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "confidential_asset_e2e::confidential_asset_verify_actual_balance_rejects_nonzero_after_deposit_only_no_rollover" =>
      some { funcIdx := 102, useConfidentialEnv := true, useRealEnv := false }
  | "confidential_asset_e2e::confidential_asset_verify_actual_balance_rejects_nonzero_sum_after_two_deposits_no_rollover" =>
      some { funcIdx := 102, useConfidentialEnv := true, useRealEnv := false }
  | "confidential_asset_e2e::confidential_asset_verify_actual_balance_rejects_wrong_sum_after_two_deposits_no_rollover" =>
      some { funcIdx := 102, useConfidentialEnv := true, useRealEnv := false }
  | "confidential_asset_e2e::confidential_asset_verify_actual_balance_rejects_sum_plus_one_after_two_deposits_no_rollover" =>
      some { funcIdx := 102, useConfidentialEnv := true, useRealEnv := false }
  | "confidential_asset_e2e::confidential_asset_verify_actual_balance_rejects_wrong_amount_after_deposit_and_rollover_only" =>
      some { funcIdx := 102, useConfidentialEnv := true, useRealEnv := false }
  | "confidential_asset_e2e::confidential_asset_verify_actual_balance_rejects_zero_after_deposit_and_rollover_when_actual_nonzero" =>
      some { funcIdx := 102, useConfidentialEnv := true, useRealEnv := false }
  | "confidential_asset_e2e::confidential_asset_verify_pending_balance_rejects_nonzero_after_deposit_and_rollover_only" =>
      some { funcIdx := 102, useConfidentialEnv := true, useRealEnv := false }
  | "confidential_asset_e2e::confidential_asset_verify_pending_balance_rejects_stale_deposit_amount_after_deposit_and_rollover_only" =>
      some { funcIdx := 102, useConfidentialEnv := true, useRealEnv := false }
  | "confidential_asset_e2e::confidential_asset_verify_pending_balance_rejects_stale_sum_after_two_deposits_and_rollover_only" =>
      some { funcIdx := 102, useConfidentialEnv := true, useRealEnv := false }
  | "confidential_asset_e2e::confidential_asset_verify_pending_balance_rejects_wrong_amount_after_two_deposits_and_rollover_only" =>
      some { funcIdx := 102, useConfidentialEnv := true, useRealEnv := false }
  | "confidential_asset_e2e::confidential_asset_compare_plain_fa_transfer_gas" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "confidential_asset_e2e::confidential_withdraw_without_asset_auditor" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "confidential_asset_e2e::confidential_withdraw_after_asset_auditor_enabled" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "confidential_asset_e2e::confidential_transfer_with_voluntary_auditors_only" =>
      some { funcIdx := 41, useConfidentialEnv := true, useRealEnv := false }
  | "confidential_asset_e2e::confidential_transfer_asset_auditor_plus_voluntary_auditors" =>
      some { funcIdx := 41, useConfidentialEnv := true, useRealEnv := false }
  | "confidential_asset_e2e::confidential_transfer_rejects_empty_auditors_when_asset_auditor_set" =>
      some { funcIdx := 42, useConfidentialEnv := true, useRealEnv := false }
  | "confidential_asset_e2e::confidential_transfer_rejects_non_matching_asset_auditor_pubkey" =>
      some { funcIdx := 42, useConfidentialEnv := true, useRealEnv := false }
  | "confidential_asset_e2e::confidential_transfer_rejects_mismatched_sender_recipient_amount_ciphertexts" =>
      some { funcIdx := 182, useConfidentialEnv := true, useRealEnv := false }
  | "confidential_asset_e2e::confidential_transfer_rejects_when_recipient_frozen" =>
      some { funcIdx := 183, useConfidentialEnv := true, useRealEnv := false }
  | "confidential_asset_e2e::normalize_aborts_when_already_normalized_only" =>
      some { funcIdx := 184, useConfidentialEnv := true, useRealEnv := false }
  | "confidential_asset_e2e::deposit_to_rejects_when_recipient_frozen" =>
      some { funcIdx := 183, useConfidentialEnv := true, useRealEnv := false }
  | "confidential_asset_e2e::deposit_rejects_when_account_frozen_self_deposit_only" =>
      some { funcIdx := 183, useConfidentialEnv := true, useRealEnv := false }
  | "confidential_asset_e2e::freeze_token_aborts_when_already_frozen_only" =>
      some { funcIdx := 183, useConfidentialEnv := true, useRealEnv := false }
  | "confidential_asset_e2e::unfreeze_token_aborts_when_not_frozen_only" =>
      some { funcIdx := 185, useConfidentialEnv := true, useRealEnv := false }
  | "confidential_asset_e2e::register_aborts_when_store_already_published_only" =>
      some { funcIdx := 186, useConfidentialEnv := true, useRealEnv := false }
  | "confidential_asset_e2e::rollover_pending_balance_aborts_when_denormalized_only" =>
      some { funcIdx := 187, useConfidentialEnv := true, useRealEnv := false }
  | "confidential_asset_e2e::enable_token_aborts_when_already_enabled_only" =>
      some { funcIdx := 188, useConfidentialEnv := true, useRealEnv := false }
  | "confidential_asset_e2e::deposit_rejects_when_token_not_allowlisted_after_allow_list_enabled_only" =>
      some { funcIdx := 189, useConfidentialEnv := true, useRealEnv := false }
  | "confidential_asset_e2e::enable_allow_list_aborts_when_already_enabled_only" =>
      some { funcIdx := 190, useConfidentialEnv := true, useRealEnv := false }
  | "confidential_asset_e2e::disable_allow_list_aborts_when_already_disabled_only" =>
      some { funcIdx := 191, useConfidentialEnv := true, useRealEnv := false }
  | "confidential_asset_e2e::register_rejects_when_token_not_allowlisted_after_allow_list_enabled_first_only" =>
      some { funcIdx := 189, useConfidentialEnv := true, useRealEnv := false }
  | "confidential_asset_e2e::deposit_rejects_after_disable_token_with_allow_list_on_only" =>
      some { funcIdx := 189, useConfidentialEnv := true, useRealEnv := false }
  | "confidential_asset_e2e::freeze_token_aborts_when_store_not_published_only" =>
      some { funcIdx := 192, useConfidentialEnv := true, useRealEnv := false }
  | "confidential_asset_e2e::unfreeze_token_aborts_when_store_not_published_only" =>
      some { funcIdx := 192, useConfidentialEnv := true, useRealEnv := false }
  | "confidential_asset_e2e::rollover_pending_balance_aborts_when_store_not_published_only" =>
      some { funcIdx := 192, useConfidentialEnv := true, useRealEnv := false }
  | "confidential_asset_e2e::rollover_pending_balance_and_freeze_aborts_when_store_not_published_only" =>
      some { funcIdx := 192, useConfidentialEnv := true, useRealEnv := false }
  | "confidential_asset_e2e::disable_token_aborts_when_already_disabled_only" =>
      some { funcIdx := 193, useConfidentialEnv := true, useRealEnv := false }
  | "test_registration_fs_message_framework_matches_helpers_golden" =>
      some { funcIdx := 170, useConfidentialEnv := true, useRealEnv := false }
  | "test_registration_proof_framework_deterministic_verify_roundtrip" =>
      some { funcIdx := 171, useConfidentialEnv := true, useRealEnv := false }
  | "test_registration_fs_message_golden_move_second" =>
      some { funcIdx := 172, useConfidentialEnv := true, useRealEnv := false }
  | "test_registration_fs_message_framework_second_scenario_matches_helpers_golden" =>
      some { funcIdx := 173, useConfidentialEnv := true, useRealEnv := false }
  | "test_registration_bytecode_eval_roundtrip" =>
      some { funcIdx := 194, useConfidentialEnv := true, useRealEnv := false }
  | _                  => none

def funcNameToMappingFromBase (base : String) : Option FuncMapping :=
  funcNameToMappingErrorCatalog base <|>
  funcNameToMappingStringCatalog base <|>
  funcNameToMappingCmpCatalog base <|>
  funcNameToMappingBcsCatalog base <|>
  funcNameToMappingHashCatalog base <|>
  funcNameToMappingSignerCatalog base <|>
  funcNameToMappingFixedPoint32Catalog base <|>
  funcNameToMappingOptionCatalog base <|>
  funcNameToMappingBitVectorCatalog base <|>
  funcNameToMappingAclCatalog base <|>
  funcNameToMappingPart1 base <|>
  funcNameToMappingPart2 base <|>
  funcNameToMappingPart3 base <|>
  funcNameToMappingPart4 base <|>
  funcNameToMappingPart5 base

end MovementFormal.DiffTest
