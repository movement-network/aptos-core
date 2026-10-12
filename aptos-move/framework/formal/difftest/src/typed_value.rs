use anyhow::{Context, Result};
use move_core_types::{
    account_address::AccountAddress,
    u256::U256,
    value::{MoveStruct, MoveStructLayout, MoveTypeLayout, MoveValue},
};
use std::str::FromStr;

use crate::schema::TypedValue;

fn bit_vector_typed_from_two_fields(fields: &[MoveValue]) -> Option<TypedValue> {
    match fields {
        [MoveValue::U64(len), MoveValue::Vector(elems)] => {
            let mut bits = Vec::new();
            for e in elems {
                match e {
                    MoveValue::Bool(b) => bits.push(*b),
                    _ => return None,
                }
            }
            if bits.len() != *len as usize {
                return None;
            }
            Some(TypedValue {
                ty: "bit_vector".into(),
                value: serde_json::json!({
                    "length": len,
                    "bits": bits,
                }),
            })
        },
        _ => None,
    }
}

fn acl_typed_from_vector(elems: &[MoveValue]) -> Option<TypedValue> {
    let mut addrs = Vec::new();
    for e in elems {
        match e {
            MoveValue::Address(a) => addrs.push(serde_json::Value::String(a.to_hex_literal())),
            _ => return None,
        }
    }
    Some(TypedValue {
        ty: "acl".into(),
        value: serde_json::Value::Array(addrs),
    })
}

fn option_u64_typed_from_vector(elems: &[MoveValue]) -> Option<TypedValue> {
    match elems {
        [] => Some(TypedValue {
            ty: "option_u64".into(),
            value: serde_json::Value::Null,
        }),
        [MoveValue::U64(n)] => Some(TypedValue {
            ty: "option_u64".into(),
            value: serde_json::json!(n),
        }),
        _ => None,
    }
}

pub fn move_value_to_typed(val: &MoveValue, layout: &MoveTypeLayout) -> TypedValue {
    match (val, layout) {
        (MoveValue::Bool(b), MoveTypeLayout::Bool) => TypedValue {
            ty: "bool".into(),
            value: serde_json::Value::Bool(*b),
        },
        (MoveValue::U8(n), MoveTypeLayout::U8) => TypedValue {
            ty: "u8".into(),
            value: serde_json::Value::Number((*n).into()),
        },
        (MoveValue::U16(n), MoveTypeLayout::U16) => TypedValue {
            ty: "u16".into(),
            value: serde_json::Value::Number((*n).into()),
        },
        (MoveValue::U32(n), MoveTypeLayout::U32) => TypedValue {
            ty: "u32".into(),
            value: serde_json::Value::Number((*n).into()),
        },
        (MoveValue::U64(n), MoveTypeLayout::U64) => TypedValue {
            ty: "u64".into(),
            value: serde_json::Value::Number((*n).into()),
        },
        (MoveValue::U128(n), MoveTypeLayout::U128) => TypedValue {
            ty: "u128".into(),
            value: serde_json::Value::String(n.to_string()),
        },
        (MoveValue::U256(n), MoveTypeLayout::U256) => TypedValue {
            ty: "u256".into(),
            value: serde_json::Value::String(n.to_string()),
        },
        (MoveValue::Address(a), MoveTypeLayout::Address) => TypedValue {
            ty: "address".into(),
            value: serde_json::Value::String(a.to_hex_literal()),
        },
        (MoveValue::Signer(a), MoveTypeLayout::Signer) => TypedValue {
            ty: "signer".into(),
            value: serde_json::Value::String(a.to_hex_literal()),
        },
        (MoveValue::Vector(elems), MoveTypeLayout::Vector(inner_layout)) => {
            let inner_type = layout_to_type_str(inner_layout);
            let json_elems: Vec<serde_json::Value> = elems
                .iter()
                .map(|e| move_value_to_typed(e, inner_layout).value)
                .collect();
            TypedValue {
                ty: format!("vector<{}>", inner_type),
                value: serde_json::Value::Array(json_elems),
            }
        },
        (MoveValue::Struct(ms), layout) => {
            if let MoveStruct::Runtime(fields) = ms {
                if let MoveTypeLayout::Struct(MoveStructLayout::Runtime(field_layouts)) = layout {
                    if fields.len() == field_layouts.len() {
                        if fields.len() == 1 {
                            if let (MoveValue::Vector(elems), MoveTypeLayout::Vector(inner)) =
                                (&fields[0], &field_layouts[0])
                            {
                                match inner.as_ref() {
                                    MoveTypeLayout::Address => {
                                        if let Some(tv) = acl_typed_from_vector(elems) {
                                            return tv;
                                        }
                                    },
                                    MoveTypeLayout::U64 => {
                                        if let Some(tv) = option_u64_typed_from_vector(elems) {
                                            return tv;
                                        }
                                    },
                                    _ => {}
                                }
                            }
                        }
                        if fields.len() == 2 {
                            if let Some(tv) = bit_vector_typed_from_two_fields(fields) {
                                return tv;
                            }
                        }
                    }
                }
                if fields.len() == 2 {
                    if let Some(tv) = bit_vector_typed_from_two_fields(fields) {
                        return tv;
                    }
                }
                if fields.len() == 1 {
                    if let MoveValue::Vector(elems) = &fields[0] {
                        if !elems.is_empty() {
                            if let Some(tv) = option_u64_typed_from_vector(elems) {
                                return tv;
                            }
                            if let Some(tv) = acl_typed_from_vector(elems) {
                                return tv;
                            }
                        }
                    }
                }
            }
            TypedValue {
                ty: "unknown".into(),
                value: serde_json::Value::String(format!("{:?}", val)),
            }
        },
        _ => TypedValue {
            ty: "unknown".into(),
            value: serde_json::Value::String(format!("{:?}", val)),
        },
    }
}

pub fn layout_to_type_str(layout: &MoveTypeLayout) -> String {
    match layout {
        MoveTypeLayout::Bool => "bool".into(),
        MoveTypeLayout::U8 => "u8".into(),
        MoveTypeLayout::U16 => "u16".into(),
        MoveTypeLayout::U32 => "u32".into(),
        MoveTypeLayout::U64 => "u64".into(),
        MoveTypeLayout::U128 => "u128".into(),
        MoveTypeLayout::U256 => "u256".into(),
        MoveTypeLayout::Address => "address".into(),
        MoveTypeLayout::Signer => "signer".into(),
        MoveTypeLayout::Vector(inner) => format!("vector<{}>", layout_to_type_str(inner)),
        _ => "unknown".into(),
    }
}

pub fn typed_value_to_move(tv: &TypedValue) -> Result<(MoveValue, MoveTypeLayout)> {
    match tv.ty.as_str() {
        "bool" => {
            let b = tv.value.as_bool().context("expected bool")?;
            Ok((MoveValue::Bool(b), MoveTypeLayout::Bool))
        },
        "u8" => {
            let n = tv.value.as_u64().context("expected u8 number")? as u8;
            Ok((MoveValue::U8(n), MoveTypeLayout::U8))
        },
        "u16" => {
            let n = tv.value.as_u64().context("expected u16 number")? as u16;
            Ok((MoveValue::U16(n), MoveTypeLayout::U16))
        },
        "u32" => {
            let n = tv.value.as_u64().context("expected u32 number")? as u32;
            Ok((MoveValue::U32(n), MoveTypeLayout::U32))
        },
        "u64" => {
            let n = tv.value.as_u64().context("expected u64 number")?;
            Ok((MoveValue::U64(n), MoveTypeLayout::U64))
        },
        "u128" => {
            let s = tv.value.as_str().context("expected u128 string")?;
            let n: u128 = s.parse().context("invalid u128")?;
            Ok((MoveValue::U128(n), MoveTypeLayout::U128))
        },
        "u256" => {
            let s = tv.value.as_str().context("expected u256 string")?;
            let n = U256::from_str(s).map_err(|e| anyhow::anyhow!("invalid u256: {e}"))?;
            Ok((MoveValue::U256(n), MoveTypeLayout::U256))
        },
        "address" => {
            let s = tv.value.as_str().context("expected address hex string")?;
            let addr = AccountAddress::from_hex_literal(s)?;
            Ok((MoveValue::Address(addr), MoveTypeLayout::Address))
        },
        "signer" => {
            let s = tv.value.as_str().context("expected signer address hex string")?;
            let addr = AccountAddress::from_hex_literal(s)?;
            Ok((MoveValue::Signer(addr), MoveTypeLayout::Signer))
        },
        "acl" => {
            let arr = tv
                .value
                .as_array()
                .context("acl: expected JSON array of address hex literals")?;
            let mut vals = Vec::new();
            for v in arr {
                let s = v.as_str().context("acl: address string")?;
                let addr = AccountAddress::from_hex_literal(s)?;
                vals.push(MoveValue::Address(addr));
            }
            Ok((
                MoveValue::Struct(MoveStruct::Runtime(vec![MoveValue::Vector(vals)])),
                MoveTypeLayout::Struct(MoveStructLayout::Runtime(vec![
                    MoveTypeLayout::Vector(Box::new(MoveTypeLayout::Address)),
                ])),
            ))
        },
        "bit_vector" => {
            let obj = tv
                .value
                .as_object()
                .context("bit_vector: expected JSON object")?;
            let len = obj
                .get("length")
                .and_then(|v| v.as_u64())
                .context("bit_vector: length")?;
            let bits_json = obj
                .get("bits")
                .and_then(|v| v.as_array())
                .context("bit_vector: bits array")?;
            let mut bits = Vec::new();
            for b in bits_json {
                bits.push(b.as_bool().context("bit_vector: bool element")?);
            }
            if bits.len() != len as usize {
                anyhow::bail!("bit_vector: bits length must match length field");
            }
            let move_bits: Vec<MoveValue> = bits.iter().copied().map(MoveValue::Bool).collect();
            Ok((
                MoveValue::Struct(MoveStruct::Runtime(vec![
                    MoveValue::U64(len),
                    MoveValue::Vector(move_bits),
                ])),
                MoveTypeLayout::Struct(MoveStructLayout::Runtime(vec![
                    MoveTypeLayout::U64,
                    MoveTypeLayout::Vector(Box::new(MoveTypeLayout::Bool)),
                ])),
            ))
        },
        "option_u64" => {
            let inner_vals = match &tv.value {
                serde_json::Value::Null => vec![],
                serde_json::Value::Number(n) => {
                    let u = n.as_u64().context("option_u64: invalid number")?;
                    vec![MoveValue::U64(u)]
                },
                _ => anyhow::bail!("option_u64: value must be null or number"),
            };
            Ok((
                MoveValue::Struct(MoveStruct::Runtime(vec![MoveValue::Vector(inner_vals)])),
                MoveTypeLayout::Struct(MoveStructLayout::Runtime(vec![
                    MoveTypeLayout::Vector(Box::new(MoveTypeLayout::U64)),
                ])),
            ))
        },
        ty if ty.starts_with("vector<") && ty.ends_with('>') => {
            let inner_ty_str = &ty[7..ty.len() - 1];
            let arr = tv.value.as_array().context("expected array for vector")?;
            let elems: Result<Vec<(MoveValue, MoveTypeLayout)>> = arr
                .iter()
                .map(|v| {
                    typed_value_to_move(&TypedValue {
                        ty: inner_ty_str.to_string(),
                        value: v.clone(),
                    })
                })
                .collect();
            let elems = elems?;
            let layout = if let Some((_, l)) = elems.first() {
                l.clone()
            } else {
                type_str_to_layout(inner_ty_str)?
            };
            let vals: Vec<MoveValue> = elems.into_iter().map(|(v, _)| v).collect();
            Ok((
                MoveValue::Vector(vals),
                MoveTypeLayout::Vector(Box::new(layout)),
            ))
        },
        other => anyhow::bail!("unsupported type: {}", other),
    }
}

pub fn type_str_to_layout(s: &str) -> Result<MoveTypeLayout> {
    match s {
        "bool" => Ok(MoveTypeLayout::Bool),
        "u8" => Ok(MoveTypeLayout::U8),
        "u16" => Ok(MoveTypeLayout::U16),
        "u32" => Ok(MoveTypeLayout::U32),
        "u64" => Ok(MoveTypeLayout::U64),
        "u128" => Ok(MoveTypeLayout::U128),
        "u256" => Ok(MoveTypeLayout::U256),
        "address" => Ok(MoveTypeLayout::Address),
        "signer" => Ok(MoveTypeLayout::Signer),
        other => anyhow::bail!("unsupported layout type: {}", other),
    }
}

pub fn make_u64_vec(vals: &[u64]) -> TypedValue {
    TypedValue {
        ty: "vector<u64>".into(),
        value: serde_json::Value::Array(vals.iter().map(|&v| serde_json::json!(v)).collect()),
    }
}

pub fn make_u64(val: u64) -> TypedValue {
    TypedValue {
        ty: "u64".into(),
        value: serde_json::json!(val),
    }
}

pub fn make_u8(val: u8) -> TypedValue {
    TypedValue {
        ty: "u8".into(),
        value: serde_json::json!(val),
    }
}

pub fn make_u16(val: u16) -> TypedValue {
    TypedValue {
        ty: "u16".into(),
        value: serde_json::json!(val),
    }
}

pub fn make_u32(val: u32) -> TypedValue {
    TypedValue {
        ty: "u32".into(),
        value: serde_json::json!(val),
    }
}

pub fn make_bool(b: bool) -> TypedValue {
    TypedValue {
        ty: "bool".into(),
        value: serde_json::json!(b),
    }
}

pub fn make_u128_str(s: &str) -> TypedValue {
    TypedValue {
        ty: "u128".into(),
        value: serde_json::Value::String(s.into()),
    }
}

pub fn make_u256_str(s: &str) -> TypedValue {
    TypedValue {
        ty: "u256".into(),
        value: serde_json::Value::String(s.into()),
    }
}

pub fn make_u8_vec(bytes: &[u8]) -> TypedValue {
    TypedValue {
        ty: "vector<u8>".into(),
        value: serde_json::Value::Array(bytes.iter().map(|&b| serde_json::json!(b)).collect()),
    }
}

pub fn make_address_hex(literal: &str) -> TypedValue {
    TypedValue {
        ty: "address".into(),
        value: serde_json::Value::String(literal.into()),
    }
}

/// `signer` transaction argument (same hex literal format as `address`).
pub fn make_signer_hex(literal: &str) -> TypedValue {
    TypedValue {
        ty: "signer".into(),
        value: serde_json::Value::String(literal.into()),
    }
}
