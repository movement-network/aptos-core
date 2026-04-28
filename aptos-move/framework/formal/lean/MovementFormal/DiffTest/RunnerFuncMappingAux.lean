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
  -- Phase A gap-fill (2026-04-17): public CA fns not previously in the harness.
  -- All return `bool(true)` on the VM; Lean uses the existing `funcIdx := 40` witness
  -- (same pattern as the ~65 merged CA e2e `bool(true)` success pins).
  --
  -- **Note on excluded Phase A candidates.** `ciphertext_clone`, `balance_to_points_c`,
  -- and `balance_to_points_d` all transitively call `ristretto255::point_clone`, which is
  -- **not registered** in the `move-vm-test-utils` harness VM (aborts with
  -- `E_NATIVE_FUN_NOT_AVAILABLE` / canonical `196613`). That is a harness-environment
  -- limitation (not real Move semantics): on the real Aptos framework runtime these
  -- functions work. Matching the harness-VM abort in Lean would add rows that exercise
  -- only the missing-native path, so those tests are intentionally not included here.
  -- See `aptos-move/framework/formal/difftest/inventory/confidential_assets.md` §
  -- "Harness-VM blocked natives" for the full list.
  | "test_elg_ciphertext_as_points_compress_equals_to_bytes" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_elg_ciphertext_from_compressed_points_roundtrip" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_layer_max_sender_auditor_hint_bytes_eq_256" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  -- Phase A strong rows (2026-04-17): NON-ZERO-input bug-catching tests.
  -- These pin `bool(true)` via the Lean `ldTrue` witness (funcIdx := 40). Each one
  -- exercises a distinguishing property (inequality, algebraic identity on non-zero
  -- scalars, byte-structure sensitivity) so a regression to a trivial implementation
  -- on the Move side produces a VM result ≠ `true` → mismatch with Lean → **FAIL**.
  --
  -- These rows are deliberately designed to catch real bugs. A latent copy-paste bug
  -- in `confidential_balance::sub_balances_mut` (using `ciphertext_add_assign` instead
  -- of `ciphertext_sub_assign`) was surfaced by the `test_bal_sub_u64_one_from_u64_one_is_zero`
  -- row below and fixed in the same changeset. See `inventory/confidential_assets.md`.
  | "test_elg_ciphertext_one_not_equal_zero" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_elg_ciphertext_one_bytes_differ_from_zero_bytes" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_elg_ciphertext_add_one_plus_zero_equals_one" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_elg_ciphertext_add_one_plus_two_equals_three" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_elg_ciphertext_sub_one_from_one_is_zero" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_elg_ciphertext_sub_three_minus_two_equals_one" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_elg_ciphertext_sub_assign_on_nonzero_matches_sub" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_elg_compress_decompress_nonzero_ciphertext_roundtrips" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_elg_get_value_component_nonzero_matches_basepoint_mul" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_elg_ciphertext_to_bytes_roundtrip_nonzero" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_bal_different_u64_pending_not_equal" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_bal_different_u64_pending_c_not_equal" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_bal_plain_zero_not_equal_u64_one" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_bal_u64_large_not_zero" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_bal_u64_high_chunk_not_zero" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_bal_u64_one_bytes_differ_from_u64_two_bytes" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_bal_add_u64_one_plus_u64_two_equals_u64_three" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_bal_sub_u64_one_from_u64_one_is_zero" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_bal_sub_u64_three_minus_two_equals_one" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_bal_compress_decompress_nonzero_pending_equals_self" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_bal_pending_u64_one_bytes_roundtrip_equals_self" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_bal_pending_u64_one_bytes_contains_nonzero" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_bal_get_pending_chunks_is_four" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_bal_get_actual_chunks_is_eight" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_bal_get_chunk_bits_is_sixteen" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_bal_split_u64_zero_all_chunks_zero" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_bal_split_u128_zero_all_chunks_zero" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_bal_split_u64_one_only_first_chunk_nonzero" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | _                  => none

-- Phase B strong rows (2026-04-17): additional NON-TRIVIAL bug-catching rows.
-- All pin `bool(true)` via `ldTrue` (funcIdx := 40). Each exercises a
-- distinct regression class: operator-precedence in the splitter, chunk-
-- by-chunk scanning in `is_zero_balance`, the `C`-vs-full equality
-- discriminator, commutativity / associativity / identity / round-trip
-- of the homomorphic arithmetic, byte-order sensitivity of serialization,
-- domain-separation between Fiat-Shamir DSTs (pairwise inequality +
-- exact-byte literals), and auditor-serialization order preservation.
-- Split into its own `private def` to keep each match's `isDefEq` work
-- under the default Lean heartbeat limit (same pattern as Part1..Part5).
-- See `inventory/bug_fixes_found_by_difftests.md` for the methodology.
private def funcNameToMappingPart6 (base : String) : Option FuncMapping :=
  match base with
  | "test_bal_split_u64_65536_chunk0_is_zero" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_bal_split_u64_65537_chunk0_is_one" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_bal_split_u128_65536_chunk0_is_zero_chunk1_is_one" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_bal_split_u64_0xffff_chunk0_is_0xffff" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_bal_u64_chunk1_only_not_zero" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_bal_u64_chunk2_only_not_zero" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_bal_u64_chunk2_only_not_zero_strict" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_bal_c_equals_but_not_equals_when_only_d_differs" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_bal_add_commutes_nonzero" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_bal_add_associative_nonzero" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_bal_add_zero_rhs_preserves_nonzero_lhs" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_bal_sub_zero_rhs_preserves_nonzero_lhs" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_bal_add_then_sub_recovers_original" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_bal_bytes_chunk_order_matters" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_elg_ciphertext_add_associative_nonzero" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_elg_ciphertext_add_commutative_nonzero" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_elg_ciphertext_sub_assign_self_is_zero_nonzero" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_elg_ciphertext_add_assign_one_plus_two_equals_three" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_elg_ciphertext_add_then_sub_recovers_original_nonzero" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_elg_ciphertext_to_bytes_len_64_nonzero" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_elg_get_value_component_not_identity_when_v_nonzero" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_fs_dst_transfer_not_equal_rotation" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_fs_dst_withdrawal_not_equal_normalization" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_fs_dst_registration_not_equal_normalization" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_fs_dst_withdrawal_not_equal_transfer" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_fs_dst_withdrawal_not_equal_rotation" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_fs_dst_withdrawal_not_equal_registration" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_fs_dst_transfer_not_equal_normalization" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_fs_dst_transfer_not_equal_registration" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_fs_dst_rotation_not_equal_normalization" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_fs_dst_rotation_not_equal_registration" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_fs_dst_bulletproofs_not_equal_any_sigma_dst" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_fs_dst_transfer_bytes_exact" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_fs_dst_rotation_bytes_exact" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_fs_dst_withdrawal_bytes_exact" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_fs_dst_normalization_bytes_exact" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_fs_dst_registration_bytes_exact" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_fs_dst_bulletproofs_bytes_exact" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_bulletproofs_num_bits_is_16" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_ristretto_basepoint_bytes_equals_tier3_golden" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_hash_to_point_base_bytes_equals_tier3_golden" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_ristretto_basepoint_ne_hash_base" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_hash_to_point_base_deterministic" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_new_scalar_from_sha2_512_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_new_scalar_from_sha2_512_empty_input_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_new_scalar_from_sha2_512_abc_input_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_new_scalar_from_sha2_512_dst_input_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_new_scalar_from_sha2_512_deterministic" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_new_scalar_from_sha2_512_distinct_inputs" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_scalar_add_3_5_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_scalar_sub_5_3_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_scalar_sub_3_5_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_scalar_mul_7_11_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_scalar_neg_one_equals_l_minus_one_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_scalar_neg_zero_is_zero_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_scalar_invert_7_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_scalar_invert_2_times_2_is_one_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_scalar_invert_zero_is_none_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_sha2_512_empty_input_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_sha2_512_abc_input_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_sha2_512_movement_input_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_sha2_512_112_a_bytes_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_sha2_512_128_b_bytes_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_sha2_512_output_length_is_64" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_sha2_512_distinct_inputs_distinct_outputs" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_scalar_from_u64_0_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_scalar_from_u64_1_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_scalar_from_u64_42_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_scalar_from_u64_max_u32_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_scalar_from_u64_max_u64_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  -- Phase W.8 — msm_gamma + scalar-identity bindings.
  | "test_msm_gamma_1_42_0_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_msm_gamma_1_42_1_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_msm_gamma_1_1_3_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_msm_gamma_2_42_0_5_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_msm_gamma_2_100_7_11_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_scalar_add_sub_cancel_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_scalar_squared_difference_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_scalar_mul_assoc_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_scalar_distributivity_lhs_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_scalar_distributivity_rhs_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  -- Phase W.9 — scalar inversion identities + prepend_domain_context bindings.
  | "test_scalar_double_inverse_7_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_scalar_double_inverse_42_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_scalar_double_inverse_1001_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_scalar_inv_of_product_lhs_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_scalar_inv_of_product_rhs_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_scalar_inv_of_neg_lhs_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_scalar_inv_of_neg_rhs_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_scalar_cube_diff_direct_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_scalar_cube_diff_factored_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_scalar_mul_neg_identity_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_prepend_domain_context_empty_body_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_prepend_domain_context_with_suffix_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_prepend_domain_context_max_chain_id_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  -- Phase W.10 — Full FS-prefix cross-engine byte equality via SHA-512 digest.
  | "test_sha2_512_of_wd_fs_prefix_matches_golden_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_sha2_512_of_norm_fs_prefix_matches_golden_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_sha2_512_of_rot_fs_prefix_matches_golden_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_sha2_512_of_tr_fs_prefix_matches_golden_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  -- Phase W.11 — multi-fixture FS-prefix SHA-512 cross-engine byte equality.
  | "test_sha2_512_of_wd_v2_fs_prefix_matches_golden_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_sha2_512_of_wd_v3_fs_prefix_matches_golden_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_sha2_512_of_norm_v2_fs_prefix_matches_golden_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_sha2_512_of_rot_v2_fs_prefix_matches_golden_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  -- Phase W.12: FS CHALLENGE SCALAR cross-engine binding on all 8 FS-prefix fixtures.
  | "test_fs_challenge_scalar_wd_ref_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_fs_challenge_scalar_norm_ref_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_fs_challenge_scalar_rot_ref_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_fs_challenge_scalar_tr_ref_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_fs_challenge_scalar_wd_v2_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_fs_challenge_scalar_wd_v3_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_fs_challenge_scalar_norm_v2_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_fs_challenge_scalar_rot_v2_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  -- Phase W.13: transfer auditor-count FS-prefix + challenge-scalar bindings.
  | "test_sha2_512_of_tr_1_auditor_fs_prefix_matches_golden_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_sha2_512_of_tr_2_auditor_fs_prefix_matches_golden_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_sha2_512_of_tr_3_auditor_fs_prefix_matches_golden_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_sha2_512_of_tr_2_auditor_swapped_fs_prefix_matches_golden_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_fs_challenge_scalar_tr_1_auditor_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_fs_challenge_scalar_tr_2_auditor_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_fs_challenge_scalar_tr_3_auditor_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_fs_challenge_scalar_tr_2_auditor_swapped_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  -- Phase W.14: chain_id BOUNDARY axis coverage for all 4 sigma protocols.
  | "test_sha2_512_of_wd_cid0_fs_prefix_matches_golden_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_fs_challenge_scalar_wd_cid0_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_sha2_512_of_norm_cid0_fs_prefix_matches_golden_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_fs_challenge_scalar_norm_cid0_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_sha2_512_of_norm_cidff_fs_prefix_matches_golden_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_fs_challenge_scalar_norm_cidff_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_sha2_512_of_rot_cid0_fs_prefix_matches_golden_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_fs_challenge_scalar_rot_cid0_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_sha2_512_of_rot_cidff_fs_prefix_matches_golden_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_fs_challenge_scalar_rot_cidff_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_sha2_512_of_tr_cid0_fs_prefix_matches_golden_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_fs_challenge_scalar_tr_cid0_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_sha2_512_of_tr_cidff_fs_prefix_matches_golden_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_fs_challenge_scalar_tr_cidff_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  -- Phase W.15: amount-chunk BOUNDARY axis for withdrawal FS prefix.
  | "test_sha2_512_of_wd_amt_0_fs_prefix_matches_golden_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_fs_challenge_scalar_wd_amt_0_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_sha2_512_of_wd_amt_u32max_fs_prefix_matches_golden_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_fs_challenge_scalar_wd_amt_u32max_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_sha2_512_of_wd_amt_2p32_fs_prefix_matches_golden_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_fs_challenge_scalar_wd_amt_2p32_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_sha2_512_of_wd_amt_u64max_fs_prefix_matches_golden_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_fs_challenge_scalar_wd_amt_u64max_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_sha2_512_of_wd_amt_distinct_fs_prefix_matches_golden_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_fs_challenge_scalar_wd_amt_distinct_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  -- Phase W.16: address-BCS BOUNDARY axis for withdrawal FS prefix.
  | "test_sha2_512_of_wd_addr_swap_fs_prefix_matches_golden_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_fs_challenge_scalar_wd_addr_swap_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_sha2_512_of_wd_addr_zero_fs_prefix_matches_golden_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_fs_challenge_scalar_wd_addr_zero_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_sha2_512_of_wd_addr_max_fs_prefix_matches_golden_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_fs_challenge_scalar_wd_addr_max_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_sha2_512_of_wd_addr_same_fs_prefix_matches_golden_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_fs_challenge_scalar_wd_addr_same_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  -- Phase W.17: full FS-MESSAGE axis (prefix || X-point bytes).
  | "test_sha2_512_of_wd_msg_a_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_fs_challenge_scalar_wd_msg_a_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_sha2_512_of_wd_msg_b_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_fs_challenge_scalar_wd_msg_b_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_sha2_512_of_wd_msg_c_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_fs_challenge_scalar_wd_msg_c_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_sha2_512_of_wd_msg_d_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_fs_challenge_scalar_wd_msg_d_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_serialize_auditor_eks_order_matters" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_serialize_auditor_eks_single_a_point_bytes_are_a_point" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_serialize_auditor_amounts_u64_one_differs_from_zero" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_serialize_auditor_amounts_order_matters" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | _                  => none

-- `funcNameToMappingPart7` covers the **Phase B+** difftests that target
-- operator-swap / operand-swap / algebraic-commutativity bugs in ElGamal
-- and ConfidentialBalance. Every entry pins `ldTrue` via `funcIdx := 40`;
-- if the Move VM disagrees with the expected `bool(true)` witness, the
-- diff-test fails. See `inventory/bug_fixes_found_by_difftests.md`.
private def funcNameToMappingPart7 (base : String) : Option FuncMapping :=
  match base with
  | "test_elg_ciphertext_sub_not_commutative_on_distinct_nonzero" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_elg_ciphertext_sub_five_minus_three_equals_two_nonzero" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_elg_ciphertext_add_assign_accumulates_three_nonzero" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_elg_ciphertext_sub_assign_chain_nonzero" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_elg_ciphertext_add_sub_distinct_nonzero" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_elg_compress_decompress_ciphertext_0xffff_and_len" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_bal_add_vs_sub_distinct_nonzero" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_bal_sub_not_commutative_on_distinct_nonzero" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_bal_split_u64_max_all_chunks_ffff" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_bal_split_u128_top_chunk_ffff_only" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_bal_add_balances_mut_accumulates_three" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_bal_sub_balances_mut_chain_nonzero" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_bal_pending_u64_three_bytes_roundtrip_byte_equals" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_elg_ciphertext_to_bytes_first_32_is_left_basepoint" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_elg_ciphertext_to_bytes_last_32_is_right_identity" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_elg_new_ciphertext_from_bytes_64_zero_is_identity_pair" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_elg_ciphertext_from_bytes_basepoint_left_identity_right_roundtrip_bytes" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_bal_zero_pending_bytes_all_zero" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_bal_zero_actual_bytes_all_zero" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_bal_pending_u64_one_byte_layout" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_bal_pending_from_bytes_invalid_chunk0_left_is_none" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_bal_pending_from_bytes_invalid_chunk3_right_is_none" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_bal_compressed_pending_no_rand_matches_plain" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_bal_compressed_actual_no_rand_matches_plain" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_bal_new_pending_from_256_zeros_equals_plain_zero" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_bal_new_actual_from_512_zeros_equals_plain_zero" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_bal_compress_decompress_bytes_roundtrip_u64_seven" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_bal_add_zero_plus_nonzero_equals_nonzero" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_bal_c_equals_on_distinct_u64_is_false" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_bal_equals_commutative_distinct" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_elg_ciphertext_from_points_distinguishes_left_right" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_elg_from_compressed_points_preserves_order" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_elg_get_value_component_matches_into_points_left_nonzero" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_elg_ciphertext_equals_reflexive_nonzero" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_elg_ciphertext_equals_commutative_on_distinct_nonzero" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_elg_pubkey_to_bytes_len_is_32" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | _                  => none

-- `funcNameToMappingPart8` covers the **Phase C** deserializer-reject pins
-- for the four confidential-asset proof types
-- (`deserialize_{withdrawal,transfer,normalization,rotation}_proof`).
--
-- The full prove→verify happy-path round-trip is NOT directly difftestable
-- because `ristretto255_bulletproofs::prove_batch_range_pedersen` is
-- `#[test_only]` in the core stdlib and is not callable from a
-- non-test-only harness module (harness compilation happens with
-- `testing: true` but a non-`#[test_only]` caller still cannot name a
-- `#[test_only]` callee). Happy-path coverage therefore remains BLOCKED
-- until either (a) the bulletproofs prover is promoted out of
-- `#[test_only]`, or (b) valid proof bytes are baked in as vector
-- literals. Both are documented in `inventory/confidential_assets.md`
-- §10 Phase C notes.
--
-- The rows wired here pin:
--   * length-reject paths: short or one-byte-short sigma bytes must
--     deserialize to `Option::none`.
--   * structural-accept path: an all-zero sigma of the correct length
--     (1152 B for normalization) must deserialize to `Option::some` —
--     any regression that tightens the decoder to reject zero points
--     would flip this row.
--
-- All rows pin `ldTrue` via `funcIdx := 40`.
private def funcNameToMappingPart8 (base : String) : Option FuncMapping :=
  match base with
  | "test_deserialize_withdrawal_proof_short_sigma_is_none" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_deserialize_normalization_proof_short_sigma_is_none" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_deserialize_rotation_proof_short_sigma_is_none" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_deserialize_transfer_proof_short_sigma_is_none" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_deserialize_withdrawal_proof_one_byte_short_is_none" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_deserialize_normalization_proof_one_byte_short_is_none" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_deserialize_rotation_proof_one_byte_short_is_none" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_deserialize_normalization_proof_all_zero_sigma_is_some" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | _                  => none

-- `funcNameToMappingPart9` covers the **Phase D.1** direct verify-reject pins
-- for the four confidential-asset `verify_*_proof` entry points
-- (withdrawal / normalization / rotation / transfer).
--
-- Each row constructs a well-formed-LENGTH, all-zero sigma proof (scalars
-- → zero, compressed points → identity) and empty ZKRP bytes, then calls
-- the production `verify_*_proof` on it. Because the algebra is trivially
-- wrong, `multi_scalar_mul(points_lhs, scalars_lhs)` disagrees with
-- `multi_scalar_mul(points_rhs, scalars_rhs)` inside
-- `verify_*_sigma_proof`, so the VM aborts with
-- `error::invalid_argument(ESIGMA_PROTOCOL_VERIFY_FAILED)` = **65537**.
--
-- This is the first direct difftest coverage of the four verifier entry
-- points. Previously they were only touched transitively by merged
-- end-to-end rows (Phase A/B) which go through the full txn pipeline and
-- don't isolate the verify code path. These new rows exercise the full
-- `verify_*_sigma_proof` → FS transcript → `msm_*_gammas` →
-- `multi_scalar_mul` → `point_equals` pipeline and fail at the final
-- equality check.
--
-- Implementation note: enabling these rows required setting the on-chain
-- `BULLETPROOFS_NATIVES` (id 24) feature bit in the difftest storage; see
-- `vm::ensure_sha512_move_stdlib_feature`. Without it, the verifier
-- aborts earlier inside `confidential_balance::balance_to_points_{c,d}`
-- → `ristretto255::point_clone` → `invalid_state(E_NATIVE_FUN_NOT_AVAILABLE)`
-- = **196613** (harness-level, not a real proof rejection).
--
-- All four rows pin the same Lean bytecode witness
-- `caSigmaVerifyFailedAbortDesc` at `funcIdx := 195` (defined in
-- `Programs/Confidential.lean`), which evaluates to
-- `ExecResult.aborted 65537`.
private def funcNameToMappingPart9 (base : String) : Option FuncMapping :=
  match base with
  | "test_verify_withdrawal_proof_zero_sigma_aborts" =>
      some { funcIdx := 195, useConfidentialEnv := true, useRealEnv := false }
  | "test_verify_normalization_proof_zero_sigma_aborts" =>
      some { funcIdx := 195, useConfidentialEnv := true, useRealEnv := false }
  | "test_verify_rotation_proof_zero_sigma_aborts" =>
      some { funcIdx := 195, useConfidentialEnv := true, useRealEnv := false }
  | "test_verify_transfer_proof_zero_sigma_aborts" =>
      some { funcIdx := 195, useConfidentialEnv := true, useRealEnv := false }
  -- Phase H — registration-proof NEGATIVE pins. Each test runs the production
  -- `prove_registration_deterministic_for_difftest` on a fresh fixture,
  -- mutates exactly ONE argument on the verifier side, and invokes
  -- `verify_registration_proof_for_difftest`. The mutation breaks the
  -- Fiat–Shamir challenge (for `chain_id`/`sender`/`contract_address`/
  -- `token_address`/`ek`/`commitment` mutations) or the final algebraic
  -- equation `s*H + e*ek == R` (for `response` mutation), causing the verifier
  -- to abort with `error::invalid_argument(ESIGMA_PROTOCOL_VERIFY_FAILED)` =
  -- **65537**. A regression that silently drops one of these inputs from the
  -- transcript would still pass positive roundtrip tests (both sides drop
  -- identically) but opens up cross-chain replay and other attacks — the
  -- exact class of "silent" security bug difftests can catch pre-production.
  | "test_verify_registration_rejects_sender_mutation" =>
      some { funcIdx := 195, useConfidentialEnv := true, useRealEnv := false }
  | "test_verify_registration_rejects_contract_mutation" =>
      some { funcIdx := 195, useConfidentialEnv := true, useRealEnv := false }
  | "test_verify_registration_rejects_token_mutation" =>
      some { funcIdx := 195, useConfidentialEnv := true, useRealEnv := false }
  | "test_verify_registration_rejects_chain_id_mutation" =>
      some { funcIdx := 195, useConfidentialEnv := true, useRealEnv := false }
  | "test_verify_registration_rejects_ek_mutation" =>
      some { funcIdx := 195, useConfidentialEnv := true, useRealEnv := false }
  | "test_verify_registration_rejects_commitment_mutation" =>
      some { funcIdx := 195, useConfidentialEnv := true, useRealEnv := false }
  | "test_verify_registration_rejects_response_mutation" =>
      some { funcIdx := 195, useConfidentialEnv := true, useRealEnv := false }
  | _                  => none

-- `funcNameToMappingPart10` covers the **Phase E** rows that pin the
-- semantics of `ristretto255_twisted_elgamal::ciphertext_clone`,
-- `confidential_balance::balance_to_points_c`, and
-- `confidential_balance::balance_to_points_d` — all three were flagged
-- `BLOCKED(harness)` in the `§8.1` coverage matrix in
-- `inventory/confidential_assets.md` because they transitively call
-- `ristretto255::point_clone`, which the difftest harness previously
-- rejected with `invalid_state(E_NATIVE_FUN_NOT_AVAILABLE)` = **196613**.
-- Phase D.1 enabled the on-chain `BULLETPROOFS_NATIVES` (24) and
-- `BULLETPROOFS_BATCH_NATIVES` (87) bits in
-- `vm::ensure_sha512_move_stdlib_feature`, which unblocks these rows
-- without any further Lean work.
--
-- Each row uses the plain `funcIdx := 40` (`ldTrue`) witness — the VM
-- column is the substantive side: any semantic regression in
-- `ciphertext_clone` / `balance_to_points_{c,d}` / their transitive
-- `point_clone` / `ciphertext_as_points` helpers will flip the VM
-- result from `bool(true)` to `bool(false)` and mismatch Lean.
-- Specifically:
--
-- * `test_elg_ciphertext_clone_equals_original_nonzero` — clone on a
--   NON-ZERO plaintext must equal the original (a zero-clone would
--   flip `ciphertext_equals` under non-zero input).
-- * `test_elg_ciphertext_clone_bytes_identical_nonzero` — byte-for-byte
--   serializer match, catches a clone that silently re-encodes.
-- * `test_elg_ciphertext_clone_is_structurally_independent` — mutating
--   the source after cloning must NOT leak into the clone; this is the
--   whole point of `point_clone` as a deep-copy primitive.
-- * `test_elg_ciphertext_clone_zero_encodes_all_zero` — boundary case
--   for the identity point.
-- * `balance_to_points_c` / `balance_to_points_d` length-, all-identity-,
--   and chunk-placement pins — these are the accessors every
--   `verify_*_sigma_proof` actually uses at the innermost MSM, so a
--   regression here would silently break every sigma verify.
private def funcNameToMappingPart10 (base : String) : Option FuncMapping :=
  match base with
  | "test_elg_ciphertext_clone_equals_original_nonzero" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_elg_ciphertext_clone_bytes_identical_nonzero" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_elg_ciphertext_clone_is_structurally_independent" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_elg_ciphertext_clone_zero_encodes_all_zero" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_bal_balance_to_points_c_pending_zero_len_is_4" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_bal_balance_to_points_d_pending_zero_len_is_4" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_bal_balance_to_points_c_actual_zero_len_is_8" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_bal_balance_to_points_d_actual_zero_len_is_8" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_bal_balance_to_points_c_zero_pending_all_identity" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_bal_balance_to_points_d_zero_pending_all_identity" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_bal_balance_to_points_c_zero_actual_all_identity" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_bal_balance_to_points_c_u64_one_chunk0_is_basepoint" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_bal_balance_to_points_d_u64_one_all_identity" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_bal_balance_to_points_c_neq_d_on_u64_one" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_bal_balance_to_points_c_u64_high_chunk_is_basepoint" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  -- Phase F: `verify_{pending,actual}_balance_for_test` consistency.
  -- Return-bool rows → `ldTrue` witness at funcIdx 40; the two length-
  -- assertion abort rows → funcIdx 196 (`aborted 393217`).
  | "test_bal_verify_pending_zero_with_any_dk_is_true" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_bal_verify_actual_zero_with_any_dk_is_true" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_bal_verify_pending_u64_one_matches" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_bal_verify_pending_u64_one_vs_two_is_false" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_bal_verify_pending_u64_max_chunk0_matches" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_bal_verify_pending_u64_high_chunk_matches" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_bal_verify_actual_u128_cross_u64_chunk4_matches" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_bal_verify_actual_rejects_pending_length_aborts" =>
      some { funcIdx := 196, useConfidentialEnv := true, useRealEnv := false }
  | "test_bal_verify_pending_rejects_actual_length_aborts" =>
      some { funcIdx := 196, useConfidentialEnv := true, useRealEnv := false }
  -- Phase F.2: `is_zero_balance` direct rows.
  | "test_bal_is_zero_balance_pending_zero_is_true" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_bal_is_zero_balance_actual_zero_is_true" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_bal_is_zero_balance_u64_one_is_false" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_bal_is_zero_balance_u64_high_chunk_is_false" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_bal_is_zero_balance_u64_chunk2_is_false" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_bal_is_zero_balance_after_add_sub_roundtrip" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  -- Phase G: Fiat-Shamir transcript PREFIX pins for the 4 sigma protocols.
  -- The real VM column builds a byte vector via
  -- `confidential_proof::{withdrawal,transfer,normalization,rotation}_fs_prefix_for_test`,
  -- then compares either with the protocol's DST literal (starts_with pin),
  -- another call's bytes (determinism / chain_id / sender / contract /
  -- cross-protocol pin), or a related protocol's prefix. Every row returns
  -- `bool(true)` on pass, so the Lean column is the trivial `ldTrue` stub.
  -- Lean is intentionally not modelling the transcript byte layout here;
  -- the VM side is the substantive oracle, and the Lean `ldTrue` ensures a
  -- regression that flips the transcript pin to `bool(false)` mismatches.
  | "test_fs_prefix_wd_starts_with_dst" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_fs_prefix_wd_deterministic" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_fs_prefix_wd_chain_id_matters" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_fs_prefix_wd_sender_matters" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_fs_prefix_wd_contract_matters" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_fs_prefix_wd_vs_norm_distinct" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_fs_prefix_norm_starts_with_dst" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_fs_prefix_norm_deterministic" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_fs_prefix_norm_chain_id_matters" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_fs_prefix_norm_sender_matters" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_fs_prefix_norm_contract_matters" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_fs_prefix_rot_starts_with_dst" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_fs_prefix_rot_deterministic" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_fs_prefix_rot_chain_id_matters" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_fs_prefix_rot_sender_matters" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_fs_prefix_rot_contract_matters" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_fs_prefix_rot_vs_norm_distinct" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_fs_prefix_tr_starts_with_dst" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_fs_prefix_tr_deterministic" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_fs_prefix_tr_chain_id_matters" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_fs_prefix_tr_sender_matters" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_fs_prefix_tr_contract_matters" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_fs_prefix_tr_auditor_count_matters" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_fs_prefix_tr_vs_wd_distinct" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  -- Phase G.2: FS transcript position-SWAP pins. These catch a class of bug
  -- that positive prove/verify roundtrip tests cannot catch — a swap at the
  -- call site of two symmetric arguments (e.g. sender_ek ↔ recipient_ek). In
  -- production the off-chain prover (without the swap bug) and the on-chain
  -- verifier (with the swap bug) would compute different challenges and every
  -- transfer would fail — a bug that bricks the whole protocol but passes
  -- every in-process roundtrip. Each row here picks two DISTINCT inputs and
  -- pins that their transcripts differ; a regression flips the pin to
  -- `bool(false)` and mismatches Lean `ldTrue`.
  | "test_fs_prefix_two_test_eks_are_distinct" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_fs_prefix_wd_sender_vs_contract_swap_matters" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_fs_prefix_wd_amount_chunks_matter" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_fs_prefix_norm_cur_vs_new_balance_swap_matters" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_fs_prefix_rot_cur_vs_new_ek_swap_matters" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_fs_prefix_rot_cur_vs_new_balance_swap_matters" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_fs_prefix_tr_sender_vs_recipient_ek_swap_matters" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_fs_prefix_tr_current_vs_new_balance_swap_matters" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_fs_prefix_tr_sender_vs_recipient_amount_swap_matters" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_fs_prefix_tr_auditor_eks_order_matters" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  -- Phase N — individual-field coverage for FS prefixes. Each row pins that
  -- changing exactly ONE field of one of the four FS prefix helpers yields
  -- a byte-distinct output, so returns `true`. Same `funcIdx 40` (`ldTrue`)
  -- model as the swap-matters rows above.
  | "test_fs_prefix_wd_ek_matters" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_fs_prefix_wd_current_balance_matters" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_fs_prefix_norm_ek_matters" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_fs_prefix_norm_current_balance_matters" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_fs_prefix_norm_new_balance_matters" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_fs_prefix_rot_current_ek_matters" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_fs_prefix_rot_new_ek_matters" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_fs_prefix_rot_current_balance_matters" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_fs_prefix_rot_new_balance_matters" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_fs_prefix_tr_sender_ek_matters" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_fs_prefix_tr_recipient_ek_matters" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_fs_prefix_tr_current_balance_matters" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_fs_prefix_tr_new_balance_matters" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_fs_prefix_tr_sender_amount_matters" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_fs_prefix_tr_recipient_amount_matters" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_fs_prefix_tr_auditor_ek_content_matters" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_fs_prefix_tr_auditor_amount_content_matters" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  -- Phase O — prover-side field-coverage pins for
  -- `prove_registration_deterministic_for_difftest`. Each row pins an
  -- invariance (commitment MUST NOT depend on non-k inputs) or a
  -- variance (commitment MUST change with k; response MUST change with
  -- every FS-transcript input and with dk) of the deterministic
  -- registration prover. All return `true` under correct algebra, so
  -- the Lean descriptor is `ldTrue` (funcIdx 40).
  | "test_prove_reg_det_commitment_length_is_32" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_prove_reg_det_response_length_is_32" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_prove_reg_det_deterministic_same_inputs" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_prove_reg_det_commitment_invariant_under_chain_id" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_prove_reg_det_commitment_invariant_under_sender" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_prove_reg_det_commitment_invariant_under_contract" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_prove_reg_det_commitment_invariant_under_token" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_prove_reg_det_commitment_invariant_under_ek" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_prove_reg_det_commitment_invariant_under_dk" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_prove_reg_det_commitment_changes_with_k" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_prove_reg_det_response_changes_with_chain_id" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_prove_reg_det_response_changes_with_sender" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_prove_reg_det_response_changes_with_contract" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_prove_reg_det_response_changes_with_token" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_prove_reg_det_response_changes_with_ek" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_prove_reg_det_response_changes_with_dk" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_prove_reg_det_response_changes_with_k" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  -- Phase Q — golden-vector byte pins for
  -- `prove_registration_deterministic_for_difftest` on the standard fixture
  -- (chain_id=9, sender=@0xA, contract=@0xB, token=@0xC, dk=scalar(42),
  -- ek=pk_from_scalar(42), k=scalar(9999)). These rows assert bit-for-bit
  -- byte equality against known-good goldens baked into the harness.
  -- Strictly stronger than Phase O — a symmetric algebraic drift that
  -- preserves every Phase O (in)equality can still flip these bytes.
  | "test_prove_reg_det_commitment_matches_golden" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_prove_reg_det_response_matches_golden" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  -- Phase R — golden-vector byte pins for the four sigma FS prefix helpers
  -- (`withdrawal_fs_prefix_for_test`, `normalization_fs_prefix_for_test`,
  -- `rotation_fs_prefix_for_test`, `transfer_fs_prefix_for_test`). Each row
  -- returns `true` iff the concatenated prefix bytes match a bit-for-bit
  -- golden extracted from the Move VM oracle on a fixed, simple fixture
  -- (zero-balance, basepoint/hash-base eks, chain_id = 9, sender = @0xA,
  -- contract = @0xB, amount = 42 for withdrawal, 0 auditors for transfer).
  -- Single-bit drift in any transitively-called primitive
  -- (`compressed_point_to_bytes`, `pubkey_to_bytes`, `scalar_to_bytes`,
  -- `balance_to_bytes`, `prepend_domain_context`, DST bytes, `bcs::to_bytes`)
  -- flips the prefix and fails the row.
  | "test_fs_reg_msg_matches_golden" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_fs_prefix_wd_matches_golden" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_fs_prefix_norm_matches_golden" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_fs_prefix_rot_matches_golden" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_fs_prefix_tr_matches_golden" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  -- Phase S — second transfer FS prefix golden on a 1-auditor fixture. Phase
  -- R's transfer golden uses 0 auditors, so the `auditor_eks` /
  -- `auditor_amounts` loops never execute a body and are only pinned at
  -- "length 0". Phase S pins the auditor-iteration path byte-for-byte on a
  -- 1-auditor fixture, catching refactors that silently skip or truncate the
  -- loop (e.g. `.for_each` that returns early on len==0 or an off-by-one
  -- that hashes only `auditor_eks[0..len-1]`).
  | "test_fs_prefix_tr_1aud_matches_golden" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  -- Phase T — boundary / multi-auditor / non-zero-balance FS prefix goldens
  -- that exercise code paths Phase R/S don't hit:
  --   * withdrawal with amount = u64::MAX (all 4 amount chunks = 0xffff);
  --     catches bugs in split_into_chunks_u64 or scalar_to_bytes that only
  --     manifest on high chunks.
  --   * transfer with 2 auditors; catches off-by-one / "only hash
  --     auditor[0]" bugs that pass Phase S's 1-auditor row.
  --   * normalization with non-zero current balance; catches chunk-concat
  --     / C-vs-D component swap bugs that pass Phase R's all-zero row.
  | "test_fs_prefix_wd_u64max_matches_golden" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_fs_prefix_tr_2aud_matches_golden" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_fs_prefix_norm_nonzero_matches_golden" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  -- Phase U — pairwise-swap / reorder FS prefix goldens:
  --   * withdrawal with 4 pairwise-distinct amount chunks (catches any
  --     chunk-to-chunk swap; Phase R/T's fixtures are symmetric under swap).
  --   * rotation with two distinct non-zero balances (catches current↔new
  --     concat-order and reversal bugs; Phase R's zero-zero and Phase T's
  --     current-zero-vs-zero-new fixtures cannot observe these).
  | "test_fs_prefix_wd_distinct_chunks_matches_golden" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_fs_prefix_rot_nonzero_both_matches_golden" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  -- Phase P — `verify_registration_proof_for_difftest` input-byte rejection
  -- pins. Each row feeds wrong-length or non-canonical commitment/response
  -- bytes into the verifier; the Move VM aborts with
  -- `ESIGMA_PROTOCOL_VERIFY_FAILED` (65537), which is modeled in Lean as
  -- `caSigmaVerifyFailedAbortDesc` (funcIdx := 195). If a regression weakens
  -- these checks (e.g. accepts 31/33-byte inputs, or skips canonicality
  -- verification), the Move VM would return `bool(true)` instead of aborting,
  -- producing a mismatch against the Lean abort stub — the bug alarm.
  | "test_verify_registration_rejects_commitment_len_31" =>
      some { funcIdx := 195, useConfidentialEnv := true, useRealEnv := false }
  | "test_verify_registration_rejects_commitment_len_33" =>
      some { funcIdx := 195, useConfidentialEnv := true, useRealEnv := false }
  | "test_verify_registration_rejects_commitment_noncanonical_ff32" =>
      some { funcIdx := 195, useConfidentialEnv := true, useRealEnv := false }
  | "test_verify_registration_rejects_response_len_31" =>
      some { funcIdx := 195, useConfidentialEnv := true, useRealEnv := false }
  | "test_verify_registration_rejects_response_len_33" =>
      some { funcIdx := 195, useConfidentialEnv := true, useRealEnv := false }
  | "test_verify_registration_rejects_response_noncanonical_ff32" =>
      some { funcIdx := 195, useConfidentialEnv := true, useRealEnv := false }
  -- Phase J — deserializer length-check regression pins. Every row checks
  -- that `deserialize_*_proof` returns `None` for a specific invalid length
  -- — catches regressions that weaken `!=` to `<` (letting longer inputs
  -- through) or drop the `% 128 != 0` auditor-alignment check. All pins
  -- return `bool(true)` via `option::is_none(...)`, so Lean stub is `ldTrue`.
  | "test_deserialize_withdrawal_proof_one_byte_too_long_is_none" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_deserialize_normalization_proof_one_byte_too_long_is_none" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_deserialize_rotation_proof_one_byte_too_long_is_none" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_deserialize_transfer_proof_base_plus_32_is_none" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_deserialize_transfer_proof_base_plus_64_is_none" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_deserialize_transfer_proof_base_plus_96_is_none" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_deserialize_transfer_proof_base_plus_1_is_none" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_deserialize_transfer_proof_base_minus_1_is_none" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  -- Phase I — `balance_equals` vs `balance_c_equals` distinction. Pins that
  -- `balance_equals` compares BOTH C and D components. A regression
  -- collapsing `balance_equals` to a C-only check (e.g. dropping the D loop
  -- as a mistaken "optimization") would break decryption-consistency in
  -- `verify_{pending,actual}_balance` — silent acceptance of any D. All rows
  -- return `bool(true)` on pass; Lean stub is `ldTrue` (funcIdx 40).
  | "test_bal_c_equals_true_when_d_differs" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_bal_full_equals_false_when_d_differs" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_bal_full_equals_false_when_d_differs_swapped" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_bal_c_equals_false_when_c_differs" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_bal_full_equals_false_when_c_differs" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  -- Phase K — non-canonical scalar / point rejection pins for every sigma
  -- proof deserializer. Each test builds a zero-filled sigma byte vector of
  -- correct length, overwrites a single 32-byte window with `0xff` (which
  -- is canonical-rejected for both a ristretto255 Scalar — value
  -- `2^256 - 1 > L` — and a CompressedRistretto point — high bit set
  -- violates ristretto255 canonicity), and asserts `is_none`. All rows
  -- return `bool(true)` on pass; Lean stub is `ldTrue` (funcIdx 40).
  | "test_deserialize_withdrawal_sigma_bad_first_scalar_is_none" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_deserialize_withdrawal_sigma_bad_last_scalar_is_none" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_deserialize_withdrawal_sigma_bad_first_point_is_none" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_deserialize_withdrawal_sigma_bad_last_point_is_none" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_deserialize_normalization_sigma_bad_first_scalar_is_none" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_deserialize_normalization_sigma_bad_last_scalar_is_none" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_deserialize_normalization_sigma_bad_first_point_is_none" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_deserialize_normalization_sigma_bad_last_point_is_none" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_deserialize_rotation_sigma_bad_first_scalar_is_none" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_deserialize_rotation_sigma_bad_last_scalar_is_none" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_deserialize_rotation_sigma_bad_first_point_is_none" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_deserialize_rotation_sigma_bad_last_point_is_none" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_deserialize_transfer_sigma_bad_first_scalar_is_none" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_deserialize_transfer_sigma_bad_last_scalar_is_none" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_deserialize_transfer_sigma_bad_first_point_is_none" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_deserialize_transfer_sigma_bad_last_point_is_none" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_deserialize_transfer_sigma_bad_last_auditor_point_is_none" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  -- Phase K (continued) — `ristretto255_twisted_elgamal` non-canonical
  -- rejection pins for `new_ciphertext_from_bytes` / `new_pubkey_from_bytes`.
  -- Each returns `bool(true)` on pass via `option::is_none(&...)`. Lean stub
  -- is `ldTrue` (funcIdx 40).
  | "test_elg_ciphertext_from_64_bytes_noncanonical_left_is_none" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_elg_ciphertext_from_64_bytes_noncanonical_right_is_none" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_elg_ciphertext_from_64_bytes_both_noncanonical_is_none" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_elg_pubkey_from_32_bytes_noncanonical_is_none" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  -- Phase L — length-mismatch hard-abort pins for `confidential_balance`'s
  -- chunk-sensitive helpers. Every row aborts with canonical
  -- `error::internal(1) = 0x0B_0001 = 720897`. `funcIdx 196` is the Lean
  -- `FuncDesc` that produces `aborted 720897`, exactly matching the VM.
  | "test_bal_balance_equals_mismatched_chunks_pending_actual_aborts" =>
      some { funcIdx := 196, useConfidentialEnv := true, useRealEnv := false }
  | "test_bal_balance_equals_mismatched_chunks_actual_pending_aborts" =>
      some { funcIdx := 196, useConfidentialEnv := true, useRealEnv := false }
  | "test_bal_balance_c_equals_mismatched_chunks_pending_actual_aborts" =>
      some { funcIdx := 196, useConfidentialEnv := true, useRealEnv := false }
  | "test_bal_balance_c_equals_mismatched_chunks_actual_pending_aborts" =>
      some { funcIdx := 196, useConfidentialEnv := true, useRealEnv := false }
  | "test_bal_add_balances_mut_pending_plus_actual_aborts" =>
      some { funcIdx := 196, useConfidentialEnv := true, useRealEnv := false }
  | "test_bal_sub_balances_mut_pending_minus_actual_aborts" =>
      some { funcIdx := 196, useConfidentialEnv := true, useRealEnv := false }
  -- Phase M — cross-type byte-length rejection pins for
  -- `new_{pending,actual}_balance_from_bytes`. Each row feeds the *other*
  -- balance-type's canonical serialized length (or direct output of
  -- `balance_to_bytes`) into the parser and expects `None` — which the
  -- outer Move test wraps via `std::option::is_none(...)`, so the
  -- observable return value is `true`. `funcIdx 40` is the Lean
  -- `FuncDesc` that produces `ldTrue`, matching the VM.
  | "test_pending_from_actual_size_zeros_is_none" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_actual_from_pending_size_zeros_is_none" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_pending_from_actual_roundtrip_is_none" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_actual_from_pending_roundtrip_is_none" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | _                  => none

-- `funcNameToMappingPart11` covers the **Phase W.18–W.22** Tier-3 rows
-- (full FS-MESSAGE parity, transfer auditor-count × FS-MESSAGE,
-- and Ristretto / scalar algebraic identities). Split out of Part6 to
-- keep each `match` within Lean's elaborator heartbeat budget.
private def funcNameToMappingPart11 (base : String) : Option FuncMapping :=
  match base with
  -- Phase W.18: full FS-MESSAGE axis for norm / rot / tr.
  | "test_sha2_512_of_norm_msg_a_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_fs_challenge_scalar_norm_msg_a_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_sha2_512_of_norm_msg_b_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_fs_challenge_scalar_norm_msg_b_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_sha2_512_of_rot_msg_a_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_fs_challenge_scalar_rot_msg_a_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_sha2_512_of_rot_msg_b_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_fs_challenge_scalar_rot_msg_b_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_sha2_512_of_tr_msg_a_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_fs_challenge_scalar_tr_msg_a_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_sha2_512_of_tr_msg_b_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_fs_challenge_scalar_tr_msg_b_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  -- Phase W.19: 4-shape parity for full FS-MESSAGE axis across
  -- norm / rot / tr (adds C = G||H, D = 3×G||3×H).
  | "test_sha2_512_of_norm_msg_c_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_fs_challenge_scalar_norm_msg_c_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_sha2_512_of_norm_msg_d_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_fs_challenge_scalar_norm_msg_d_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_sha2_512_of_rot_msg_c_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_fs_challenge_scalar_rot_msg_c_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_sha2_512_of_rot_msg_d_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_fs_challenge_scalar_rot_msg_d_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_sha2_512_of_tr_msg_c_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_fs_challenge_scalar_tr_msg_c_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_sha2_512_of_tr_msg_d_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_fs_challenge_scalar_tr_msg_d_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  -- Phase W.20: transfer auditor-count × full FS-MESSAGE.
  | "test_sha2_512_of_tr_1a_msg_a_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_fs_challenge_scalar_tr_1a_msg_a_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_sha2_512_of_tr_1a_msg_b_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_fs_challenge_scalar_tr_1a_msg_b_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_sha2_512_of_tr_2a_msg_a_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_fs_challenge_scalar_tr_2a_msg_a_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_sha2_512_of_tr_2a_msg_b_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_fs_challenge_scalar_tr_2a_msg_b_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_sha2_512_of_tr_3a_msg_a_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_fs_challenge_scalar_tr_3a_msg_a_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_sha2_512_of_tr_3a_msg_b_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_fs_challenge_scalar_tr_3a_msg_b_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_sha2_512_of_tr_2aswap_msg_a_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_fs_challenge_scalar_tr_2aswap_msg_a_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_sha2_512_of_tr_2aswap_msg_b_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_fs_challenge_scalar_tr_2aswap_msg_b_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  -- Phase W.21: Ristretto point-arithmetic algebraic identities.
  | "test_ristretto_identity_is_zero_bytes_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_ristretto_basepoint_mul_by_one_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_ristretto_basepoint_mul_by_zero_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_ristretto_point_add_zero_left_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_ristretto_point_add_zero_right_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_ristretto_msm_single_element_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_ristretto_msm_zero_scalars_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_ristretto_point_mul_vs_basepoint_mul_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_ristretto_scalar_distributivity_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_ristretto_msm_distributive_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_ristretto_basepoint_double_mul_equivalence_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_ristretto_point_add_commutes_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  -- Phase W.22: advanced Ristretto + scalar algebraic identities.
  | "test_ristretto_h_mul_by_one_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_ristretto_h_mul_by_zero_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_ristretto_h_doubling_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_ristretto_msm_mixed_basis_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_ristretto_msm_additive_inverse_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_ristretto_msm_regrouping_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_ristretto_identity_absorbs_mul_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_scalar_add_neg_is_zero_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_scalar_double_neg_identity_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_scalar_zero_absorbs_mul_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_scalar_mul_commutes_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_scalar_mul_associative_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_scalar_one_mul_identity_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  -- Phase W.23: additional core Ristretto natives (point_neg,
  -- point_sub, point_clone, double_scalar_mul,
  -- new_point_from_sha2_512, scalar-bytes roundtrip).
  | "test_ristretto_point_neg_additive_inverse_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_ristretto_point_neg_involution_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_ristretto_point_sub_self_is_identity_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_ristretto_point_sub_scalar_consistency_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_ristretto_point_sub_equals_add_neg_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_ristretto_point_clone_equals_source_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_ristretto_point_clone_h_equals_h_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_ristretto_double_scalar_mul_basic_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_ristretto_double_scalar_mul_zero_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_ristretto_new_point_from_sha2_512_deterministic_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_ristretto_new_point_from_sha2_512_distinct_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_scalar_bytes_roundtrip_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  -- Phase W.24: *_assign vs pure-variant parity.
  | "test_ristretto_point_add_assign_matches_pure_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_ristretto_point_sub_assign_matches_pure_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_ristretto_point_mul_assign_matches_pure_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_ristretto_point_neg_assign_matches_pure_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_scalar_add_assign_matches_pure_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_scalar_sub_assign_matches_pure_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_scalar_mul_assign_matches_pure_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_scalar_neg_assign_matches_pure_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  -- Phase W.25: scalar constructors (u8/u32/u128) + predicates +
  -- point_equals + compress/decompress roundtrip + decoding.
  | "test_scalar_from_u8_matches_u64_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_scalar_from_u8_zero_matches_scalar_zero_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_scalar_from_u32_matches_u64_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_scalar_from_u128_matches_u64_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_scalar_is_zero_on_zero_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_scalar_is_zero_on_one_is_false_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_scalar_is_one_on_one_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_scalar_is_one_on_zero_is_false_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_scalar_equals_refl_and_distinct_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_point_equals_refl_and_distinct_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_point_equals_semantic_equivalence_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_point_compress_decompress_roundtrip_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_new_point_from_bytes_basepoint_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_new_compressed_point_from_zero_is_identity_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  -- Phase W.26: twisted ElGamal ciphertext algebra identities.
  | "test_ciphertext_add_identity_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_ciphertext_add_commutative_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_ciphertext_sub_self_is_zero_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_ciphertext_add_sub_cancels_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_ciphertext_add_assign_matches_pure_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_ciphertext_sub_assign_matches_pure_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_ciphertext_clone_matches_original_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_ciphertext_equals_refl_and_order_sensitive_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_ciphertext_compress_decompress_roundtrip_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_ciphertext_bytes_roundtrip_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_ciphertext_no_randomness_zero_is_identity_ct_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_ciphertext_no_randomness_one_is_G_identity_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  -- Phase W.27: confidential_balance module bindings.
  | "test_pending_balance_no_randomness_is_zero_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_actual_balance_no_randomness_is_zero_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_balance_compress_decompress_roundtrip_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_pending_balance_bytes_roundtrip_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_pending_balance_to_points_c_zero_is_identities_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_actual_balance_to_points_d_zero_is_identities_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_balance_add_then_sub_is_noop_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_balance_c_equals_is_weaker_than_balance_equals_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_split_into_chunks_u64_zero_is_zeros_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_split_into_chunks_u64_0xffff_boundary_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_split_into_chunks_u128_mixed_le_ordering_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  -- Phase W.28: hash-to-scalar / hash-to-point / reduced / uniform constructors.
  | "test_new_scalar_from_sha512_alias_matches_canonical_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_new_scalar_from_sha2_512_deterministic_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_new_scalar_from_sha2_512_distinct_inputs_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_new_scalar_uniform_from_64_bytes_zero_is_scalar_zero_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_new_scalar_reduced_from_32_bytes_zero_is_scalar_zero_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_new_point_from_64_uniform_bytes_zero_determinism_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_new_point_from_64_uniform_bytes_distinct_inputs_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_new_scalar_uniform_from_64_bytes_distinct_inputs_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  -- Phase W.29: SHA2-512 -> scalar composition + aptos_hash::sha2_512 pins.
  | "test_new_scalar_from_sha2_512_eq_uniform_of_sha2_512_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_new_scalar_from_sha2_512_eq_uniform_of_sha2_512_alt_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_aptos_hash_sha2_512_output_len_is_64_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_aptos_hash_sha2_512_deterministic_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_aptos_hash_sha2_512_distinct_inputs_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  -- Phase W.30: Bulletproofs + Pedersen commitment public surface.
  | "test_bp_get_max_range_bits_is_64_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_bp_range_proof_empty_bytes_roundtrip_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_bp_range_proof_nontrivial_bytes_roundtrip_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_pedersen_zero_commitment_is_identity_point_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_pedersen_one_zero_commitment_is_basepoint_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_pedersen_commitment_add_commutative_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_pedersen_commitment_sub_self_is_zero_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_pedersen_commitment_add_matches_scalar_add_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_pedersen_commitment_add_assign_matches_pure_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_pedersen_commitment_sub_assign_matches_pure_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_pedersen_commitment_clone_matches_original_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_pedersen_commitment_equals_reflexive_and_sensitive_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_pedersen_commitment_as_point_vs_compressed_coherent_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_pedersen_randomness_base_matches_hash_to_point_base_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  -- Phase W.31: remaining Pedersen commitment constructors / byte surface.
  | "test_pedersen_new_commitment_matches_double_scalar_mul_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_pedersen_bulletproof_commitment_matches_explicit_bases_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_pedersen_commitment_with_basepoint_matches_bulletproof_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_pedersen_commitment_from_point_roundtrip_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_pedersen_commitment_from_compressed_basepoint_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_pedersen_commitment_bytes_roundtrip_nontrivial_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_pedersen_commitment_from_zero_bytes_is_identity_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_pedersen_zero_commitment_to_bytes_is_zeros_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_pedersen_commitment_into_point_matches_as_compressed_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_pedersen_commitment_into_compressed_matches_as_compressed_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  -- Phase W.32: Bulletproofs verifier reject-branch direct bindings —
  -- all map to `funcIdx := 195` (`caSigmaVerifyFailedAbortDesc`,
  -- abort code 65537 = NFE_DESERIALIZE_RANGE_PROOF, numerically
  -- identical to the Phase D.1 ESIGMA_PROTOCOL_VERIFY_FAILED code
  -- so the same Lean witness accepts both).
  | "test_bp_verify_range_proof_pedersen_empty_proof_aborts_tier3_binding" =>
      some { funcIdx := 195, useConfidentialEnv := true, useRealEnv := false }
  | "test_bp_verify_range_proof_pedersen_empty_proof_16bit_pc_one_aborts_tier3_binding" =>
      some { funcIdx := 195, useConfidentialEnv := true, useRealEnv := false }
  | "test_bp_verify_range_proof_explicit_bases_empty_proof_aborts_tier3_binding" =>
      some { funcIdx := 195, useConfidentialEnv := true, useRealEnv := false }
  | "test_bp_verify_range_proof_pedersen_junk_32_bytes_aborts_tier3_binding" =>
      some { funcIdx := 195, useConfidentialEnv := true, useRealEnv := false }
  | "test_bp_verify_range_proof_pedersen_zero_31_bytes_aborts_tier3_binding" =>
      some { funcIdx := 195, useConfidentialEnv := true, useRealEnv := false }
  | "test_bp_verify_batch_range_proof_pedersen_size1_empty_aborts_tier3_binding" =>
      some { funcIdx := 195, useConfidentialEnv := true, useRealEnv := false }
  | "test_bp_verify_batch_range_proof_pedersen_size2_empty_aborts_tier3_binding" =>
      some { funcIdx := 195, useConfidentialEnv := true, useRealEnv := false }
  | "test_bp_verify_batch_range_proof_explicit_bases_empty_aborts_tier3_binding" =>
      some { funcIdx := 195, useConfidentialEnv := true, useRealEnv := false }
  -- Phase W.33: `aptos_hash` module closure (sha3_512, keccak256,
  -- ripemd160, blake2b_256) — all map to `ldTrue` (`funcIdx := 40`).
  | "test_aptos_hash_sha3_512_length_is_64_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_aptos_hash_sha3_512_deterministic_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_aptos_hash_sha3_512_distinct_inputs_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_aptos_hash_sha3_512_vs_sha2_512_differ_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_aptos_hash_keccak256_length_is_32_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_aptos_hash_keccak256_deterministic_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_aptos_hash_keccak256_distinct_inputs_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_aptos_hash_keccak256_vs_sha3_512_prefix_differ_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_aptos_hash_ripemd160_length_is_20_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_aptos_hash_ripemd160_det_and_sensitive_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_aptos_hash_blake2b_256_length_is_32_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_aptos_hash_blake2b_256_distinct_from_keccak_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  -- Phase W.34: `aptos_hash` SipHash — `ldTrue` (`funcIdx := 40`).
  | "test_aptos_hash_sip_hash_deterministic_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_aptos_hash_sip_hash_distinct_inputs_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
  | "test_aptos_hash_sip_hash_from_value_matches_bcs_u64_tier3_binding" =>
      some { funcIdx := 40, useConfidentialEnv := true, useRealEnv := false }
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
  funcNameToMappingPart5 base <|>
  funcNameToMappingPart6 base <|>
  funcNameToMappingPart7 base <|>
  funcNameToMappingPart8 base <|>
  funcNameToMappingPart9 base <|>
  funcNameToMappingPart10 base <|>
  funcNameToMappingPart11 base

end MovementFormal.DiffTest
