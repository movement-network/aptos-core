use anyhow::{Context, Result};
use move_core_types::value::{MoveTypeLayout, MoveValue};

use crate::schema::TypedValue;

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
        "u64" => {
            let n = tv.value.as_u64().context("expected u64 number")?;
            Ok((MoveValue::U64(n), MoveTypeLayout::U64))
        },
        "u128" => {
            let s = tv.value.as_str().context("expected u128 string")?;
            let n: u128 = s.parse().context("invalid u128")?;
            Ok((MoveValue::U128(n), MoveTypeLayout::U128))
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

pub fn make_u8_vec(bytes: &[u8]) -> TypedValue {
    TypedValue {
        ty: "vector<u8>".into(),
        value: serde_json::Value::Array(bytes.iter().map(|&b| serde_json::json!(b)).collect()),
    }
}
