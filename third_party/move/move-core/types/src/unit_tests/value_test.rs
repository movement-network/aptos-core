// Copyright (c) The Diem Core Contributors
// Copyright (c) The Move Contributors
// SPDX-License-Identifier: Apache-2.0

use crate::{
    account_address::AccountAddress,
    ident_str,
    identifier::Identifier,
    language_storage::{StructTag, TypeTag},
    value::{MoveFieldLayout, MoveStruct, MoveStructLayout, MoveTypeLayout, MoveValue, MoveVariantLayout},
};
use serde_json::json;

#[test]
fn struct_deserialization() {
    let struct_type = StructTag {
        address: AccountAddress::ZERO,
        name: ident_str!("MyStruct").to_owned(),
        module: ident_str!("MyModule").to_owned(),
        type_args: vec![],
    };
    let values = vec![MoveValue::U64(7), MoveValue::Bool(true)];
    let fields = vec![ident_str!("f").to_owned(), ident_str!("g").to_owned()];
    let field_values: Vec<(Identifier, MoveValue)> =
        fields.into_iter().zip(values.clone()).collect();

    // test each deserialization scheme
    let runtime_value = MoveStruct::Runtime(values);
    assert_eq!(
        serde_json::to_value(&runtime_value).unwrap(),
        json!([7, true])
    );

    let fielded_value = MoveStruct::WithFields(field_values.clone());
    assert_eq!(
        serde_json::to_value(&fielded_value).unwrap(),
        json!({ "f": 7, "g": true })
    );

    let typed_value = MoveStruct::with_types(struct_type, field_values);
    assert_eq!(
        serde_json::to_value(&typed_value).unwrap(),
        json!({
                "fields": { "f": 7, "g": true },
                "type": "0x0::MyModule::MyStruct"
            }
        )
    );
}

/// A test which verifies that the BCS representation of
/// a struct with a single field is equivalent to the BCS
/// of the value in this field. It also tests
/// that BCS serialization of utf8 strings is equivalent
/// to the BCS serialization of vector<u8> of the bytes of
/// the string.
#[test]
fn struct_one_field_equiv_value() {
    let val = MoveValue::Vector(vec![
        MoveValue::U8(1),
        MoveValue::U8(22),
        MoveValue::U8(13),
        MoveValue::U8(99),
    ]);
    let s1 = MoveValue::Struct(MoveStruct::Runtime(vec![val.clone()]))
        .simple_serialize()
        .unwrap();
    let s2 = val.simple_serialize().unwrap();
    assert_eq!(s1, s2);

    let utf8_str = "çå∞≠¢õß∂ƒ∫";
    let vec_u8 = MoveValue::Vector(
        utf8_str
            .as_bytes()
            .iter()
            .map(|c| MoveValue::U8(*c))
            .collect(),
    );
    assert_eq!(
        bcs::to_bytes(utf8_str).unwrap(),
        vec_u8.simple_serialize().unwrap()
    )
}

#[test]
fn nested_typed_struct_deserialization() {
    let struct_type = StructTag {
        address: AccountAddress::ZERO,
        name: ident_str!("MyStruct").to_owned(),
        module: ident_str!("MyModule").to_owned(),
        type_args: vec![],
    };
    let nested_struct_type = StructTag {
        address: AccountAddress::ZERO,
        name: ident_str!("NestedStruct").to_owned(),
        module: ident_str!("NestedModule").to_owned(),
        type_args: vec![TypeTag::U8],
    };

    // test each deserialization scheme
    let nested_runtime_struct = MoveValue::Struct(MoveStruct::Runtime(vec![MoveValue::U64(7)]));
    let runtime_value = MoveStruct::Runtime(vec![nested_runtime_struct]);
    assert_eq!(serde_json::to_value(&runtime_value).unwrap(), json!([[7]]));

    let nested_fielded_struct = MoveValue::Struct(MoveStruct::with_fields(vec![(
        ident_str!("f").to_owned(),
        MoveValue::U64(7),
    )]));
    let fielded_value = MoveStruct::with_fields(vec![(
        ident_str!("inner").to_owned(),
        nested_fielded_struct,
    )]);
    assert_eq!(
        serde_json::to_value(&fielded_value).unwrap(),
        json!({ "inner": { "f": 7 } })
    );

    let nested_typed_struct =
        MoveValue::Struct(MoveStruct::with_types(nested_struct_type, vec![(
            ident_str!("f").to_owned(),
            MoveValue::U64(7),
        )]));
    let typed_value = MoveStruct::with_types(struct_type, vec![(
        ident_str!("inner").to_owned(),
        nested_typed_struct,
    )]);
    assert_eq!(
        serde_json::to_value(&typed_value).unwrap(),
        json!({
            "fields": {
                "inner": {
                    "fields": { "f": 7},
                    "type": "0x0::NestedModule::NestedStruct<u8>",
                }
            },
            "type": "0x0::MyModule::MyStruct"
        })
    );
}

/// RuntimeVariants layout used by the fail-closed field-accessor tests:
/// variant 0 has one field, variant 1 is a unit variant.
fn enum_layout() -> MoveStructLayout {
    MoveStructLayout::RuntimeVariants(vec![
        vec![MoveTypeLayout::U64],
        vec![],
    ])
}

#[test]
fn fields_returns_some_for_consistent_runtime_queries() {
    let runtime = MoveStructLayout::Runtime(vec![MoveTypeLayout::Bool, MoveTypeLayout::U8]);
    assert_eq!(
        runtime.fields(None),
        Some([MoveTypeLayout::Bool, MoveTypeLayout::U8].as_slice())
    );

    let variants = enum_layout();
    assert_eq!(
        variants.fields(Some(0)),
        Some([MoveTypeLayout::U64].as_slice())
    );
    // A genuine unit variant is Some(&[]), not None.
    assert_eq!(variants.fields(Some(1)), Some([].as_slice()));
}

#[test]
fn fields_returns_none_for_unknown_or_inconsistent_tags() {
    let runtime = MoveStructLayout::Runtime(vec![MoveTypeLayout::U64]);
    // Structs are not enums: asking for a variant is inconsistent.
    assert_eq!(runtime.fields(Some(0)), None);

    let variants = enum_layout();
    assert_eq!(variants.fields(None), None);
    for bad in [2usize, 3, 100, usize::MAX] {
        assert_eq!(
            variants.fields(Some(bad)),
            None,
            "out-of-range tag {bad} must not collapse to an empty unit variant"
        );
    }

    let decorated = MoveStructLayout::WithFields(vec![MoveFieldLayout::new(
        ident_str!("x").to_owned(),
        MoveTypeLayout::U8,
    )]);
    assert_eq!(decorated.fields(None), None);
}

#[test]
fn into_fields_is_fail_closed_like_fields() {
    let runtime = MoveStructLayout::Runtime(vec![MoveTypeLayout::U32]);
    assert_eq!(
        runtime.clone().into_fields(None),
        Some(vec![MoveTypeLayout::U32])
    );
    assert_eq!(runtime.into_fields(Some(0)), None);

    let variants = enum_layout();
    assert_eq!(
        variants.clone().into_fields(Some(0)),
        Some(vec![MoveTypeLayout::U64])
    );
    assert_eq!(variants.clone().into_fields(Some(1)), Some(vec![]));
    assert_eq!(variants.clone().into_fields(None), None);
    assert_eq!(variants.into_fields(Some(2)), None);

    let with_fields = MoveStructLayout::WithFields(vec![MoveFieldLayout::new(
        ident_str!("f").to_owned(),
        MoveTypeLayout::Bool,
    )]);
    assert_eq!(
        with_fields.into_fields(None),
        Some(vec![MoveTypeLayout::Bool])
    );

    let with_variants = MoveStructLayout::WithVariants(vec![
        MoveVariantLayout {
            name: ident_str!("A").to_owned(),
            fields: vec![MoveFieldLayout::new(
                ident_str!("x").to_owned(),
                MoveTypeLayout::U8,
            )],
        },
        MoveVariantLayout {
            name: ident_str!("B").to_owned(),
            fields: vec![],
        },
    ]);
    assert_eq!(
        with_variants.clone().into_fields(Some(0)),
        Some(vec![MoveTypeLayout::U8])
    );
    assert_eq!(with_variants.clone().into_fields(Some(1)), Some(vec![]));
    assert_eq!(with_variants.into_fields(Some(2)), None);
}
