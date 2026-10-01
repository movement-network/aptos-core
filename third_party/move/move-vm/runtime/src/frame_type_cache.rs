// Copyright © Aptos Foundation
// SPDX-License-Identifier: Apache-2.0

use crate::{frame::Frame, LoadedFunction};
use move_binary_format::{
    errors::*,
    file_format::{
        FieldInstantiationIndex, FunctionHandleIndex, FunctionInstantiationIndex, SignatureIndex,
        StructDefInstantiationIndex, StructVariantInstantiationIndex,
        VariantFieldInstantiationIndex,
    },
};
use move_core_types::gas_algebra::NumTypeNodes;
use move_vm_types::loaded_data::runtime_types::Type;
use std::{
    cell::RefCell,
    collections::{BTreeMap, HashMap},
    hash::{BuildHasherDefault, Hasher},
    rc::Rc,
};

/// Hasher for the per-instruction cache's `u16` program-counter keys. The keys
/// are small, dense, and non-adversarial (bytecode offsets), so the value is
/// used directly as the hash rather than paying for the default SipHash. This
/// keeps a lookup close to a direct index while still allowing the cache to be
/// a sparse map that only holds entries for instructions that actually ran.
#[derive(Default)]
pub(crate) struct PcHasher(u64);

impl Hasher for PcHasher {
    fn finish(&self) -> u64 {
        self.0
    }

    fn write_u16(&mut self, i: u16) {
        self.0 = i as u64;
    }

    fn write(&mut self, bytes: &[u8]) {
        // Keys are `u16`, so `write_u16` is what actually gets called. This
        // fallback only exists to satisfy the trait and is never on the hot
        // path.
        for &b in bytes {
            self.0 = (self.0 << 8) ^ u64::from(b);
        }
    }
}

type BuildPcHasher = BuildHasherDefault<PcHasher>;

#[allow(dead_code)]
pub(crate) trait RuntimeCacheTraits {
    fn caches_enabled() -> bool;
}

pub(crate) struct NoRuntimeCaches;
pub(crate) struct AllRuntimeCaches;

impl RuntimeCacheTraits for NoRuntimeCaches {
    fn caches_enabled() -> bool {
        false
    }
}

impl RuntimeCacheTraits for AllRuntimeCaches {
    fn caches_enabled() -> bool {
        true
    }
}

/// Variants for each individual instruction cache. Should make sure
/// that the memory footprint of each variant is small. This is an
/// enum that is expected to grow in the future.
#[derive(Clone)]
#[allow(dead_code)]
pub(crate) enum PerInstructionCache {
    Pack(u16),
    PackGeneric(u16),
    Call(Rc<LoadedFunction>, Rc<RefCell<FrameTypeCache>>),
    CallGeneric(Rc<LoadedFunction>, Rc<RefCell<FrameTypeCache>>),
}

#[derive(Default)]
pub(crate) struct FrameTypeCache {
    struct_field_type_instantiation:
        BTreeMap<StructDefInstantiationIndex, Vec<(Type, NumTypeNodes)>>,
    struct_variant_field_type_instantiation:
        BTreeMap<StructVariantInstantiationIndex, Vec<(Type, NumTypeNodes)>>,
    struct_def_instantiation_type: BTreeMap<StructDefInstantiationIndex, (Type, NumTypeNodes)>,
    struct_variant_instantiation_type:
        BTreeMap<StructVariantInstantiationIndex, (Type, NumTypeNodes)>,
    /// For a given field instantiation, the:
    ///    ((Type of the field, size of the field type) and (Type of its defining struct,
    ///    size of its defining struct)
    field_instantiation:
        BTreeMap<FieldInstantiationIndex, ((Type, NumTypeNodes), (Type, NumTypeNodes))>,
    /// Same as above, bot for variant field instantiations
    variant_field_instantiation:
        BTreeMap<VariantFieldInstantiationIndex, ((Type, NumTypeNodes), (Type, NumTypeNodes))>,
    single_sig_token_type: BTreeMap<SignatureIndex, (Type, NumTypeNodes)>,
    /// Recursive frame cache for a function that is called from the
    /// current frame. It is indexed by FunctionInstantiationindex or
    /// FunctionHandleIndex for non-generic functions. Note that
    /// whenever a function with the same `index` is called, the
    /// structures stored in that function's frame cache do not change.
    pub(crate) generic_sub_frame_cache:
        BTreeMap<FunctionInstantiationIndex, (Rc<LoadedFunction>, Rc<RefCell<FrameTypeCache>>)>,
    pub(crate) sub_frame_cache:
        BTreeMap<FunctionHandleIndex, (Rc<LoadedFunction>, Rc<RefCell<FrameTypeCache>>)>,
    /// Stores a variant for each individual instruction in the
    /// function's bytecode. We keep the size of the variant to be
    /// small. The caches are indexed by the index of the given
    /// bytecode instruction in the function body.
    ///
    /// Important! - If an entry is present for a given instruction, then
    /// we do NOT need to re-check for any errors that only depend on
    /// the argument of the bytecode instructions, for which it is
    /// guaranteed that everything will be exactly the same as when we
    /// did the insertion.
    pub(crate) per_instruction_cache: HashMap<u16, PerInstructionCache, BuildPcHasher>,
}

impl FrameTypeCache {
    #[inline(always)]
    fn get_or<K: Copy + Ord + Eq, V, F>(
        map: &mut BTreeMap<K, V>,
        idx: K,
        ty_func: F,
    ) -> PartialVMResult<&V>
    where
        F: FnOnce(K) -> PartialVMResult<V>,
    {
        match map.entry(idx) {
            std::collections::btree_map::Entry::Occupied(entry) => Ok(entry.into_mut()),
            std::collections::btree_map::Entry::Vacant(entry) => {
                let v = ty_func(idx)?;
                Ok(entry.insert(v))
            },
        }
    }

    #[inline(always)]
    pub(crate) fn get_field_type_and_struct_type(
        &mut self,
        idx: FieldInstantiationIndex,
        frame: &Frame,
    ) -> PartialVMResult<((&Type, NumTypeNodes), (&Type, NumTypeNodes))> {
        let ((field_ty, field_ty_count), (struct_ty, struct_ty_count)) =
            Self::get_or(&mut self.field_instantiation, idx, |idx| {
                let struct_type = frame.field_instantiation_to_struct(idx)?;
                let struct_ty_count = NumTypeNodes::new(struct_type.num_nodes() as u64);
                let field_ty = frame.get_generic_field_ty(idx)?;
                let field_ty_count = NumTypeNodes::new(field_ty.num_nodes() as u64);
                Ok(((field_ty, field_ty_count), (struct_type, struct_ty_count)))
            })?;
        Ok(((field_ty, *field_ty_count), (struct_ty, *struct_ty_count)))
    }

    pub(crate) fn get_variant_field_type_and_struct_type(
        &mut self,
        idx: VariantFieldInstantiationIndex,
        frame: &Frame,
    ) -> PartialVMResult<((&Type, NumTypeNodes), (&Type, NumTypeNodes))> {
        let ((field_ty, field_ty_count), (struct_ty, struct_ty_count)) =
            Self::get_or(&mut self.variant_field_instantiation, idx, |idx| {
                let info = frame.variant_field_instantiation_info_at(idx);
                let struct_type = frame.create_struct_instantiation_ty(
                    &info.definition_struct_type,
                    &info.instantiation,
                )?;
                let struct_ty_count = NumTypeNodes::new(struct_type.num_nodes() as u64);
                let field_ty =
                    frame.instantiate_ty(&info.uninstantiated_field_ty, &info.instantiation)?;
                let field_ty_count = NumTypeNodes::new(field_ty.num_nodes() as u64);
                Ok(((field_ty, field_ty_count), (struct_type, struct_ty_count)))
            })?;
        Ok(((field_ty, *field_ty_count), (struct_ty, *struct_ty_count)))
    }

    #[inline(always)]
    pub(crate) fn get_struct_type(
        &mut self,
        idx: StructDefInstantiationIndex,
        frame: &Frame,
    ) -> PartialVMResult<(&Type, NumTypeNodes)> {
        let (ty, ty_count) = Self::get_or(&mut self.struct_def_instantiation_type, idx, |idx| {
            let ty = frame.get_generic_struct_ty(idx)?;
            let ty_count = NumTypeNodes::new(ty.num_nodes() as u64);
            Ok((ty, ty_count))
        })?;
        Ok((ty, *ty_count))
    }

    #[inline(always)]
    pub(crate) fn get_struct_variant_type(
        &mut self,
        idx: StructVariantInstantiationIndex,
        frame: &Frame,
    ) -> PartialVMResult<(&Type, NumTypeNodes)> {
        let (ty, ty_count) =
            Self::get_or(&mut self.struct_variant_instantiation_type, idx, |idx| {
                let info = frame.get_struct_variant_instantiation_at(idx);
                let ty = frame.create_struct_instantiation_ty(
                    &info.definition_struct_type,
                    &info.instantiation,
                )?;
                let ty_count = NumTypeNodes::new(ty.num_nodes() as u64);
                Ok((ty, ty_count))
            })?;
        Ok((ty, *ty_count))
    }

    #[inline(always)]
    pub(crate) fn get_struct_fields_types(
        &mut self,
        idx: StructDefInstantiationIndex,
        frame: &Frame,
    ) -> PartialVMResult<&[(Type, NumTypeNodes)]> {
        Ok(Self::get_or(
            &mut self.struct_field_type_instantiation,
            idx,
            |idx| {
                Ok(frame
                    .instantiate_generic_struct_fields(idx)?
                    .into_iter()
                    .map(|ty| {
                        let num_nodes = NumTypeNodes::new(ty.num_nodes() as u64);
                        (ty, num_nodes)
                    })
                    .collect::<Vec<_>>())
            },
        )?)
    }

    #[inline(always)]
    pub(crate) fn get_struct_variant_fields_types(
        &mut self,
        idx: StructVariantInstantiationIndex,
        frame: &Frame,
    ) -> PartialVMResult<&[(Type, NumTypeNodes)]> {
        Ok(Self::get_or(
            &mut self.struct_variant_field_type_instantiation,
            idx,
            |idx| {
                Ok(frame
                    .instantiate_generic_struct_variant_fields(idx)?
                    .into_iter()
                    .map(|ty| {
                        let num_nodes = NumTypeNodes::new(ty.num_nodes() as u64);
                        (ty, num_nodes)
                    })
                    .collect::<Vec<_>>())
            },
        )?)
    }

    #[inline(always)]
    pub(crate) fn get_signature_index_type(
        &mut self,
        idx: SignatureIndex,
        frame: &Frame,
    ) -> PartialVMResult<(&Type, NumTypeNodes)> {
        let (ty, ty_count) = Self::get_or(&mut self.single_sig_token_type, idx, |idx| {
            let ty = frame.instantiate_single_type(idx)?;
            let ty_count = NumTypeNodes::new(ty.num_nodes() as u64);
            Ok((ty, ty_count))
        })?;
        Ok((ty, *ty_count))
    }

    pub(crate) fn make_rc() -> Rc<RefCell<Self>> {
        Rc::new(RefCell::<Self>::new(Default::default()))
    }

    /// Creates a frame cache for a callee frame.
    pub(crate) fn make_rc_for_function(_function: &LoadedFunction) -> Rc<RefCell<Self>> {
        Self::make_rc()
    }
}
