// Copyright (c) Aptos Labs
// Copyright (c) The Diem Core Contributors
// Copyright (c) The Move Contributors
// SPDX-License-Identifier: Apache-2.0

//! Build a vector of module test plans for a Move program compiled with V2.
//!
//! This reimplements the legacy move compiler functionality.
//!
//! Each module containing any labeled `#[test]` functions gets an item in the output list, which
//! includes info about each '#[test]' function: name, arguments to provide, and expected failure or
//! success.

use crate::{
    fuzz::{
        ArgOrigin, Domain, FuzzPlanMetadata, FuzzValueSource, NoFuzzSource, ParamSpec, RangeSpec,
    },
    options::Options,
};
use codespan_reporting::diagnostic::Severity;
use legacy_move_compiler::{
    shared::known_attributes::{AttributeKind, TestingAttribute},
    unit_test::{ExpectedFailure, ExpectedMoveError, ModuleTestPlan, TestCase},
};
use move_command_line_common::{address::NumericalAddress, parser::NumberFormat};
use move_core_types::{
    identifier::Identifier, language_storage::ModuleId, u256, value::MoveValue,
    vm_status::StatusCode,
};
use move_model::{
    ast::{Address, Attribute, AttributeValue, ConstraintOp, ModuleName, Value},
    model::{FunctionEnv, GlobalEnv, Loc, ModuleEnv, Parameter},
    symbol::Symbol,
    ty::{PrimitiveType, Type},
};
use num::{bigint::Sign, BigInt, ToPrimitive};
use std::collections::BTreeMap;

/// Sentinel run count handed to `FuzzValueSource::sample`: `0` means "use the
/// source's own configured `runs`" (e.g. `FuzzConfig::runs`, driven by
/// `--fuzz-runs`). The planner is generic over the source and has no config of
/// its own, so it defers the count to the source rather than hardcoding it.
const FUZZ_RUNS_FROM_SOURCE: usize = 0;
/// Cap on Cartesian-product expansion to guard against accidental explosion.
const MAX_FUZZ_CASES: usize = 1024;

//***************************************************************************
// Test Plan Building
//***************************************************************************

/// Output of plan-building: the test plans plus a sidecar map of fuzz
/// metadata keyed by `(ModuleId, expanded_test_name)`. The metadata is what
/// lets the runner shrink failing fuzz cases and mutate corpus entries.
#[derive(Debug, Clone)]
pub struct TestPlanBuild {
    pub plans: Vec<ModuleTestPlan>,
    pub fuzz_metadata: FuzzPlanMetadata,
}

// Constructs a test plan for each module in `env.target`. This also validates the structure of the
// attributes as the test plan is constructed.
pub fn construct_test_plan(
    env: &GlobalEnv,
    package_filter: Option<Symbol>,
) -> Option<Vec<ModuleTestPlan>> {
    construct_test_plan_with_fuzz_source(env, package_filter, &NoFuzzSource)
        .map(|build| build.plans)
}

/// Like [`construct_test_plan`], but the caller can supply a [`FuzzValueSource`] to materialize
/// values for implicit-fuzz or `in`/`!=` constrained parameters. Returns a [`TestPlanBuild`]
/// carrying both the per-module test plans and the [`FuzzPlanMetadata`] sidecar.
pub fn construct_test_plan_with_fuzz_source(
    env: &GlobalEnv,
    package_filter: Option<Symbol>,
    fuzz_source: &dyn FuzzValueSource,
) -> Option<TestPlanBuild> {
    let options = env.get_extension::<Options>().expect("options");
    if !options.compile_test_code {
        return None;
    }

    let mut metadata = FuzzPlanMetadata::default();
    let plans: Vec<ModuleTestPlan> = env
        .get_modules()
        .filter_map(|module| {
            if module.is_primary_target() {
                construct_module_test_plan(env, package_filter, fuzz_source, &mut metadata, module)
            } else {
                None
            }
        })
        .collect();
    Some(TestPlanBuild {
        plans,
        fuzz_metadata: metadata,
    })
}

fn construct_module_test_plan(
    env: &GlobalEnv,
    _package_filter: Option<Symbol>,
    fuzz_source: &dyn FuzzValueSource,
    metadata: &mut FuzzPlanMetadata,
    module: ModuleEnv,
) -> Option<ModuleTestPlan> {
    // TODO (#12885): what is a package?  Do we need this code?
    // if package_filter.is_some() && module.package_name != package_filter {
    // return None;
    // }

    let current_module = module.get_name();
    let module_id_for_meta = module.get_identifier().map(|name| {
        let addr_bytes = match current_module.addr() {
            Address::Numerical(num_addr) => Some(*num_addr),
            Address::Symbolic(sym) => env.resolve_address_alias(*sym),
        };
        (addr_bytes, name)
    });

    let expanded: Vec<ExpandedCase> = module
        .get_functions()
        .flat_map(|func| build_test_info(env, current_module, fuzz_source, func))
        .collect();
    let mut tests: BTreeMap<String, TestCase> = BTreeMap::new();
    for ex in expanded {
        if let Some((Some(addr), name)) = module_id_for_meta.as_ref() {
            metadata.insert(
                ModuleId::new(*addr, name.clone()),
                ex.case.test_name.clone(),
                ex.origins,
            );
        }
        tests.insert(ex.case.test_name.clone(), ex.case);
    }

    let module_id = module.get_identifier();
    if tests.is_empty() {
        None
    } else {
        let module_name = module.get_name();
        let addr = module_name.addr();
        let name_sym = module_name.name();
        let name_str = env.symbol_pool().string(name_sym).to_string();
        if let Some(module_identifier) = module_id {
            let name_id = Identifier::new(name_str.clone()).expect("name is valid for identifier");
            assert!(name_id == module_identifier);
        }
        let optional_num_addr: Option<move_core_types::account_address::AccountAddress> = match addr
        {
            Address::Numerical(num_addr) => Some(*num_addr),
            Address::Symbolic(sym) => env.resolve_address_alias(*sym),
        };
        optional_num_addr.map(|addr_bytes| {
            ModuleTestPlan::new(
                &NumericalAddress::new(*addr_bytes, NumberFormat::Hex),
                &name_str,
                tests,
            )
        })
    }
}

/// One expanded `#[test]` case: a `TestCase` ready for the runner plus the
/// per-argument origin that lets the runner shrink/mutate when appropriate.
pub struct ExpandedCase {
    pub case: TestCase,
    pub origins: Vec<ArgOrigin>,
}

fn build_test_info(
    env: &GlobalEnv,
    current_module: &ModuleName,
    fuzz_source: &dyn FuzzValueSource,
    function: FunctionEnv,
) -> Vec<ExpandedCase> {
    let fn_name_str = function.get_name_str();
    let fn_id_loc = function.get_id_loc();

    let attrs = function.get_attributes();
    let expected_failure_name = env.symbol_pool().make(TestingAttribute::EXPECTED_FAILURE);
    let test_name = env.symbol_pool().make(TestingAttribute::TEST);
    let test_only_name = env.symbol_pool().make(TestingAttribute::TEST_ONLY);

    let test_attribute_opt = attrs.iter().find(|a| a.name() == test_name);
    let abort_attribute_opt = attrs.iter().find(|a| a.name() == expected_failure_name);

    let test_attribute = match test_attribute_opt {
        None => {
            // expected failures cannot be annotated on non-#[test] functions
            if let Some(abort_attribute) = abort_attribute_opt {
                let fn_msg = "Only functions defined as a test with #[test] can also have an \
                              #[expected_failure] attribute";
                let abort_msg = "Attributed as #[expected_failure] here";
                let abort_id = abort_attribute.node_id();
                let abort_loc = env.get_node_loc(abort_id);
                env.error_with_labels(&fn_id_loc, fn_msg, vec![(abort_loc, abort_msg.to_string())]);
            }
            return Vec::new();
        },
        Some(test_attribute) => test_attribute,
    };

    let test_attribute_id = test_attribute.node_id();
    let test_attribute_loc = env.get_node_loc(test_attribute_id);

    let test_only_attribute_opt = attrs.iter().find(|a| a.name() == test_only_name);

    // A #[test] function cannot also be annotated #[test_only]
    if let Some(test_only_attribute) = test_only_attribute_opt {
        let msg = "Function annotated as both #[test(...)] and #[test_only]. You need to declare \
                   it as either one or the other";
        let test_only_id = test_only_attribute.node_id();
        let test_only_loc = env.get_node_loc(test_only_id);
        env.error_with_labels(&fn_id_loc, "invalid usage of known attribute", vec![
            (test_only_loc, msg.to_string()),
            (
                test_attribute_loc.clone(),
                "Previously annotated here".to_string(),
            ),
        ]);
    }

    let specs = match parse_test_attribute(env, test_attribute, 0) {
        Some(specs) => specs,
        None => return Vec::new(),
    };

    let parameters: Vec<_> = function.get_parameters_ref().iter().cloned().collect();

    // We separate deterministic dimensions (Concrete/Matrix) from fuzz dimensions so that
    // explicit matrices Cartesian-multiply but independent fuzz draws *zip* together: with
    // `#[test(a, b)]` the user expects N runs total, each binding `a[i]` and `b[i]`, not
    // N² combinations. Matches Foundry's `[fuzz] runs = N` semantics.
    let mut had_error = false;
    let mut had_fuzz = false;
    enum Dim {
        Det(Vec<MoveValue>),
        Fuzz {
            values: Vec<MoveValue>,
            param_name: String,
            ty: Type,
            domain: Domain,
            exclude: Domain,
        },
    }
    let mut dims: Vec<(Symbol, Dim)> = Vec::with_capacity(parameters.len());
    for (param_index, param) in parameters.iter().enumerate() {
        let Parameter(var, ty, var_loc) = param;
        let owned_default;
        let spec_ref = match specs.get(var) {
            Some(s) => s,
            None => {
                // A parameter with no explicit `#[test(...)]` assignment is
                // treated as an *implicit fuzz* input over an unrestricted
                // domain. This intentionally replaces the legacy compiler's
                // hard "Missing test parameter assignment" error: a bare
                // `#[test] fun f(a: u64)` now expands into fuzz cases when a
                // `FuzzValueSource` is registered (the move-unit-test runner
                // installs `DefaultFuzzSource`), and reports a clear "no fuzz
                // value source" diagnostic when one is not. This is a
                // deliberate behavior change — see the runner-facing docs in
                // `tests/unit_test/test/fuzz_implicit.move`.
                owned_default = ParamSpec::Fuzz {
                    domain: Domain::default(),
                    exclude: Domain::default(),
                };
                &owned_default
            },
        };
        let is_fuzz = matches!(spec_ref, ParamSpec::Fuzz { .. });
        let param_name = env.symbol_pool().string(*var);
        match materialize_param_values(
            env,
            fuzz_source,
            &fn_id_loc,
            &test_attribute_loc,
            var_loc,
            ty,
            param_name.as_str(),
            // Per-parameter salt: derived from the parameter position so two
            // fuzz parameters of the same type draw distinct value streams
            // rather than identical ones. The source mixes this with its own
            // base seed (`--fuzz-seed`).
            param_index as u64,
            spec_ref,
        ) {
            Some(values) => {
                if is_fuzz {
                    had_fuzz = true;
                    let (domain, exclude) = match spec_ref {
                        ParamSpec::Fuzz { domain, exclude } => (domain.clone(), exclude.clone()),
                        _ => unreachable!(),
                    };
                    dims.push((*var, Dim::Fuzz {
                        values,
                        param_name: param_name.to_string(),
                        ty: ty.clone(),
                        domain,
                        exclude,
                    }));
                } else {
                    dims.push((*var, Dim::Det(values)));
                }
            },
            None => had_error = true,
        }
    }

    if had_error {
        return Vec::new();
    }

    let expected_failure = match abort_attribute_opt {
        None => None,
        Some(abort_attribute) => parse_failure_attribute(env, current_module, abort_attribute),
    };

    // Cartesian over deterministic dimensions; zip across fuzz dimensions.
    let det_product: usize = dims
        .iter()
        .filter_map(|(_, d)| if let Dim::Det(vs) = d { Some(vs.len()) } else { None })
        .product::<usize>()
        .max(1);
    let fuzz_runs: usize = dims
        .iter()
        .filter_map(|(_, d)| {
            if let Dim::Fuzz { values, .. } = d {
                Some(values.len())
            } else {
                None
            }
        })
        .min()
        .unwrap_or(1);
    let total = det_product.saturating_mul(fuzz_runs);
    if total > MAX_FUZZ_CASES {
        env.error(
            &fn_id_loc,
            &format!(
                "#[test] expansion would produce {} cases (cap: {}). Narrow the matrix, fuzz \
                 domain, or `--fuzz-runs`.",
                total, MAX_FUZZ_CASES
            ),
        );
        return Vec::new();
    }

    if had_fuzz {
        env.diag(
            Severity::Note,
            &fn_id_loc,
            &format!(
                "fuzz: expanded `{}` to {} case{}",
                fn_name_str,
                total,
                if total == 1 { "" } else { "s" }
            ),
        );
    }

    if dims.is_empty() {
        // Zero-arg function: a single case with no arguments and the bare function name.
        return vec![ExpandedCase {
            case: TestCase {
                test_name: fn_name_str.to_string(),
                function_name: fn_name_str.to_string(),
                arguments: Vec::new(),
                expected_failure,
            },
            origins: Vec::new(),
        }];
    }

    let is_single = total == 1;

    // Iterate: for each Cartesian point of the deterministic dims, run `fuzz_runs` zipped
    // draws over the fuzz dims. When `had_fuzz` is false this collapses to plain Cartesian.
    let det_lens: Vec<usize> = dims
        .iter()
        .map(|(_, d)| match d {
            Dim::Det(vs) => vs.len(),
            Dim::Fuzz { .. } => 1, // placeholder; we drive fuzz with `fuzz_iter`
        })
        .collect();

    let mut cases = Vec::with_capacity(total);
    let mut det_indices = vec![0usize; dims.len()];
    loop {
        for fuzz_iter in 0..fuzz_runs {
            let mut arguments = Vec::with_capacity(dims.len());
            let mut suffix_parts = Vec::with_capacity(dims.len());
            let mut origins = Vec::with_capacity(dims.len());
            for (i, (var, d)) in dims.iter().enumerate() {
                let v = match d {
                    Dim::Det(vs) => &vs[det_indices[i]],
                    Dim::Fuzz { values, .. } => &values[fuzz_iter % values.len()],
                };
                arguments.push(v.clone());
                suffix_parts.push(format!(
                    "{}={}",
                    var.display(env.symbol_pool()),
                    format_move_value(v)
                ));
                origins.push(match d {
                    Dim::Det(_) => ArgOrigin::Fixed,
                    Dim::Fuzz {
                        param_name,
                        ty,
                        domain,
                        exclude,
                        ..
                    } => ArgOrigin::Fuzz {
                        param_name: param_name.clone(),
                        ty: ty.clone(),
                        domain: domain.clone(),
                        exclude: exclude.clone(),
                    },
                });
            }
            // The display name embeds the case ordinal so it is unique even when
            // two expansions draw the same argument values (e.g. a `bool` fuzz
            // param, or a narrow domain). Without the ordinal these collide in
            // the per-module `BTreeMap<TestName, _>` and cases are silently
            // dropped. The ordinal is the case's position in `cases`.
            let test_name = if is_single {
                fn_name_str.to_string()
            } else {
                format!(
                    "{}#{}[{}]",
                    fn_name_str,
                    cases.len(),
                    suffix_parts.join(",")
                )
            };
            cases.push(ExpandedCase {
                case: TestCase {
                    test_name,
                    function_name: fn_name_str.to_string(),
                    arguments,
                    expected_failure: expected_failure.clone(),
                },
                origins,
            });
        }
        // Advance odometer across deterministic dims only — fuzz dims are zipped
        // by `fuzz_iter` above.
        let mut idx = dims.len();
        loop {
            if idx == 0 {
                return cases;
            }
            idx -= 1;
            if matches!(dims[idx].1, Dim::Fuzz { .. }) {
                continue;
            }
            det_indices[idx] += 1;
            if det_indices[idx] < det_lens[idx] {
                break;
            }
            det_indices[idx] = 0;
        }
    }
}

/// Compact human-readable rendering for a `MoveValue`, used in expanded
/// test-case suffixes like `foo[a=@0x1,b=42]`. Also reused by the unit-test
/// runner to render shrink counterexamples, so the two stay in lock-step.
pub fn format_move_value(v: &MoveValue) -> String {
    match v {
        MoveValue::Address(a) | MoveValue::Signer(a) => format!("@{}", a.short_str_lossless()),
        MoveValue::U8(x) => x.to_string(),
        MoveValue::U16(x) => x.to_string(),
        MoveValue::U32(x) => x.to_string(),
        MoveValue::U64(x) => x.to_string(),
        MoveValue::U128(x) => x.to_string(),
        MoveValue::U256(x) => x.to_string(),
        MoveValue::Bool(b) => b.to_string(),
        other => format!("{:?}", other),
    }
}

/// Turn a [`ParamSpec`] into the concrete list of `MoveValue`s for that parameter.
/// Returns `None` and reports an error on type mismatch or fuzz-source failure.
fn materialize_param_values(
    env: &GlobalEnv,
    fuzz_source: &dyn FuzzValueSource,
    fn_id_loc: &Loc,
    test_attribute_loc: &Loc,
    var_loc: &Loc,
    ty: &Type,
    param_name: &str,
    seed: u64,
    spec: &ParamSpec,
) -> Option<Vec<MoveValue>> {
    match spec {
        ParamSpec::Concrete(v) => coerce_to_param_type(env, fn_id_loc, test_attribute_loc, var_loc, ty, v.clone())
            .map(|v| vec![v]),
        ParamSpec::Matrix(vs) => {
            if vs.is_empty() {
                // `_a = []` would produce zero test cases for this dim, which
                // collapses Cartesian expansion to zero total cases and trips
                // the dimension-indexing loop in `build_test_info`.
                env.error_with_labels(fn_id_loc, "unable to generate test", vec![
                    (
                        test_attribute_loc.clone(),
                        "Empty matrix `[]` produces no test cases".to_string(),
                    ),
                    (
                        var_loc.clone(),
                        "Corresponding to this parameter".to_string(),
                    ),
                ]);
                return None;
            }
            let mut out = Vec::with_capacity(vs.len());
            for v in vs {
                let coerced = coerce_to_param_type(
                    env,
                    fn_id_loc,
                    test_attribute_loc,
                    var_loc,
                    ty,
                    v.clone(),
                )?;
                out.push(coerced);
            }
            Some(out)
        },
        ParamSpec::Fuzz { domain, exclude } => {
            match fuzz_source.sample(
                ty,
                param_name,
                domain,
                exclude,
                // `0` => let the source use its configured `runs` (`--fuzz-runs`).
                FUZZ_RUNS_FROM_SOURCE,
                seed,
            )
            {
                Ok(vs) if vs.is_empty() => {
                    env.error_with_labels(fn_id_loc, "unable to generate test", vec![
                        (
                            test_attribute_loc.clone(),
                            "Fuzz source returned no values for this parameter".to_string(),
                        ),
                        (
                            var_loc.clone(),
                            "Corresponding to this parameter".to_string(),
                        ),
                    ]);
                    None
                },
                Ok(vs) => Some(vs),
                Err(msg) => {
                    env.error_with_labels(fn_id_loc, "unable to generate test", vec![
                        (test_attribute_loc.clone(), msg),
                        (
                            var_loc.clone(),
                            "Corresponding to this parameter".to_string(),
                        ),
                    ]);
                    None
                },
            }
        },
    }
}

/// Apply the same signer/address coercion logic the legacy `#[test(a = @0x..)]`
/// code used. Returns `None` and reports an error on type mismatch.
fn coerce_to_param_type(
    env: &GlobalEnv,
    fn_id_loc: &Loc,
    test_attribute_loc: &Loc,
    var_loc: &Loc,
    ty: &Type,
    value: MoveValue,
) -> Option<MoveValue> {
    match (&value, ty) {
        (MoveValue::Address(addr), Type::Primitive(PrimitiveType::Signer)) => {
            Some(MoveValue::Signer(*addr))
        },
        (MoveValue::Address(addr), Type::Reference(_, inner))
            if **inner == Type::Primitive(PrimitiveType::Signer) =>
        {
            Some(MoveValue::Signer(*addr))
        },
        (MoveValue::Address(_), Type::Primitive(PrimitiveType::Address)) => Some(value),
        (MoveValue::Bool(_), Type::Primitive(PrimitiveType::Bool)) => Some(value),
        // Integer carrier -> the parameter's actual width, with a range check.
        (_, Type::Primitive(prim)) if is_uint_prim(prim) => match move_value_as_bigint(&value) {
            Some(n) => {
                coerce_numeric_to_width(env, fn_id_loc, test_attribute_loc, var_loc, prim, &n)
            },
            None => {
                coerce_type_error(env, fn_id_loc, test_attribute_loc, var_loc);
                None
            },
        },
        _ => {
            coerce_type_error(env, fn_id_loc, test_attribute_loc, var_loc);
            None
        },
    }
}

fn is_uint_prim(p: &PrimitiveType) -> bool {
    matches!(
        p,
        PrimitiveType::U8
            | PrimitiveType::U16
            | PrimitiveType::U32
            | PrimitiveType::U64
            | PrimitiveType::U128
            | PrimitiveType::U256
    )
}

/// Extract a `BigInt` from any integer `MoveValue`. Used to reinterpret a
/// `u256` literal carrier into the parameter's declared width.
fn move_value_as_bigint(v: &MoveValue) -> Option<BigInt> {
    match v {
        MoveValue::U8(x) => Some(BigInt::from(*x)),
        MoveValue::U16(x) => Some(BigInt::from(*x)),
        MoveValue::U32(x) => Some(BigInt::from(*x)),
        MoveValue::U64(x) => Some(BigInt::from(*x)),
        MoveValue::U128(x) => Some(BigInt::from(*x)),
        MoveValue::U256(x) => {
            let mut be = x.to_le_bytes();
            be.reverse();
            Some(BigInt::from_bytes_be(Sign::Plus, &be))
        },
        _ => None,
    }
}

/// Convert `n` to a `MoveValue` of the given uint width, reporting a range
/// error (and returning `None`) when it does not fit.
fn coerce_numeric_to_width(
    env: &GlobalEnv,
    fn_id_loc: &Loc,
    test_attribute_loc: &Loc,
    var_loc: &Loc,
    prim: &PrimitiveType,
    n: &BigInt,
) -> Option<MoveValue> {
    let max: BigInt = match prim {
        PrimitiveType::U8 => BigInt::from(u8::MAX),
        PrimitiveType::U16 => BigInt::from(u16::MAX),
        PrimitiveType::U32 => BigInt::from(u32::MAX),
        PrimitiveType::U64 => BigInt::from(u64::MAX),
        PrimitiveType::U128 => BigInt::from(u128::MAX),
        PrimitiveType::U256 => (BigInt::from(1) << 256) - BigInt::from(1),
        _ => return None,
    };
    if n.sign() == Sign::Minus || n > &max {
        env.error_with_labels(fn_id_loc, "unable to generate test", vec![
            (
                test_attribute_loc.clone(),
                format!("value {} is out of range for `{:?}`", n, prim),
            ),
            (
                var_loc.clone(),
                "Corresponding to this parameter".to_string(),
            ),
        ]);
        return None;
    }
    Some(match prim {
        PrimitiveType::U8 => MoveValue::U8(n.to_u64().unwrap() as u8),
        PrimitiveType::U16 => MoveValue::U16(n.to_u64().unwrap() as u16),
        PrimitiveType::U32 => MoveValue::U32(n.to_u64().unwrap() as u32),
        PrimitiveType::U64 => MoveValue::U64(n.to_u64().unwrap()),
        PrimitiveType::U128 => MoveValue::U128(n.to_u128().unwrap()),
        PrimitiveType::U256 => {
            let (_sign, be) = n.to_bytes_be();
            let mut buf = [0u8; 32];
            buf[32 - be.len()..].copy_from_slice(&be);
            buf.reverse();
            MoveValue::U256(u256::U256::from_le_bytes(&buf))
        },
        _ => return None,
    })
}

fn coerce_type_error(env: &GlobalEnv, fn_id_loc: &Loc, test_attribute_loc: &Loc, var_loc: &Loc) {
    env.error_with_labels(fn_id_loc, "unable to generate test", vec![
        (
            test_attribute_loc.clone(),
            "Unexpected argument type: expected an address, signer, bool, or integer".to_string(),
        ),
        (
            var_loc.clone(),
            "Corresponding to this parameter".to_string(),
        ),
    ]);
}

//***************************************************************************
// Attribute parsers
//***************************************************************************

/// Parse the contents of `#[test(...)]` into one [`ParamSpec`] per named
/// parameter. Returns `None` if a fatal structural error was encountered (and
/// the caller should abandon test-case generation for this function).
fn parse_test_attribute(
    env: &GlobalEnv,
    test_attribute: &Attribute,
    depth: usize,
) -> Option<BTreeMap<Symbol, ParamSpec>> {
    match test_attribute {
        Attribute::Apply(id, _, _) if depth > 0 => {
            let aloc = env.get_node_loc(*id);
            env.error(&aloc, "Unexpected nested attribute in test declaration");
            None
        },
        Attribute::Apply(_id, sym, inner) => {
            assert!(
                *TestingAttribute::TEST == env.symbol_pool().string(*sym).to_string(),
                "ICE: We should only be parsing a raw test attribute"
            );
            let mut specs: BTreeMap<Symbol, ParamSpec> = BTreeMap::new();
            for attr in inner {
                if !merge_test_param_entry(env, &mut specs, attr) {
                    // entry-level errors have already been reported; keep processing the rest
                }
            }
            Some(specs)
        },
        Attribute::Assign(id, _, _) | Attribute::Constrained(id, _, _, _) => {
            let aloc = env.get_node_loc(*id);
            env.error(
                &aloc,
                "Unexpected top-level form for #[test]; expected `#[test(...)]`",
            );
            None
        },
    }
}

/// Process one entry within `#[test(...)]` (e.g. `a = @0x1`, `a in 1..=10`,
/// `a != [..]`) and merge it into `specs`. Returns `true` on success.
fn merge_test_param_entry(
    env: &GlobalEnv,
    specs: &mut BTreeMap<Symbol, ParamSpec>,
    attr: &Attribute,
) -> bool {
    match attr {
        Attribute::Assign(id, sym, val) => {
            let entry_loc = env.get_node_loc(*id);
            // List literal on the RHS expands to a Matrix; anything else is a single value.
            let new_spec = match val {
                AttributeValue::List(_, items) => {
                    let mut values = Vec::with_capacity(items.len());
                    for item in items {
                        match convert_attribute_value_to_move_value(env, item) {
                            Some(v) => values.push(v),
                            None => {
                                let iloc = attribute_value_loc(env, item);
                                env.error(&iloc, "Unsupported value in test matrix");
                                return false;
                            },
                        }
                    }
                    ParamSpec::Matrix(values)
                },
                _ => match convert_attribute_value_to_move_value(env, val) {
                    Some(v) => ParamSpec::Concrete(v),
                    None => {
                        env.error_with_labels(&entry_loc, "Unsupported attribute value", vec![(
                            entry_loc.clone(),
                            "Assigned in this attribute".to_string(),
                        )]);
                        return false;
                    },
                },
            };
            insert_or_reject(env, specs, *sym, new_spec, &entry_loc)
        },
        Attribute::Constrained(id, sym, op, val) => {
            let entry_loc = env.get_node_loc(*id);
            // Build/extend a Fuzz spec for this parameter. If `_a = ...` was already
            // seen, restore the existing spec after reporting the mix error so the
            // function's other parameters can still be analyzed coherently.
            let existing = specs.remove(sym);
            let (mut domain, mut exclude) = match existing {
                None => (Domain::default(), Domain::default()),
                Some(ParamSpec::Fuzz { domain, exclude }) => (domain, exclude),
                Some(other) => {
                    env.error(
                        &entry_loc,
                        "Cannot mix `=` with `!=` / `in` for the same parameter",
                    );
                    specs.insert(*sym, other);
                    return false;
                },
            };
            let target = match op {
                ConstraintOp::In => &mut domain,
                ConstraintOp::Ne => &mut exclude,
            };
            fold_into_domain(val, target);
            specs.insert(*sym, ParamSpec::Fuzz { domain, exclude });
            true
        },
        Attribute::Apply(id, _, _) => {
            let aloc = env.get_node_loc(*id);
            env.error(&aloc, "Unexpected nested attribute in test declaration");
            false
        },
    }
}

/// Insert `new_spec` for `sym`, or report a duplicate / mixed-form error.
fn insert_or_reject(
    env: &GlobalEnv,
    specs: &mut BTreeMap<Symbol, ParamSpec>,
    sym: Symbol,
    new_spec: ParamSpec,
    entry_loc: &Loc,
) -> bool {
    if specs.contains_key(&sym) {
        env.error(
            entry_loc,
            "Duplicate or conflicting spec for this parameter (use one of `=`, `in`, or `!=`)",
        );
        return false;
    }
    specs.insert(sym, new_spec);
    true
}

/// Flatten a model-AST `AttributeValue` into literals and ranges inside the
/// given [`Domain`]. Unions and nested lists are flattened recursively;
/// anything else lands in `literals`.
fn fold_into_domain(value: &AttributeValue, dom: &mut Domain) {
    match value {
        AttributeValue::Range {
            lo,
            hi,
            inclusive_hi,
            ..
        } => dom.ranges.push(RangeSpec {
            lo: (**lo).clone(),
            hi: (**hi).clone(),
            inclusive_hi: *inclusive_hi,
        }),
        AttributeValue::List(_, items) | AttributeValue::Union(_, items) => {
            for item in items {
                fold_into_domain(item, dom);
            }
        },
        leaf => dom.literals.push(leaf.clone()),
    }
}

fn attribute_value_loc(env: &GlobalEnv, value: &AttributeValue) -> Loc {
    let id = match value {
        AttributeValue::Value(id, _) => *id,
        AttributeValue::Name(id, _, _) => *id,
        AttributeValue::List(id, _) => *id,
        AttributeValue::Range { id, .. } => *id,
        AttributeValue::Union(id, _) => *id,
    };
    env.get_node_loc(id)
}

fn parse_failure_attribute(
    env: &GlobalEnv,
    current_module: &ModuleName,
    expected_attr: &Attribute,
) -> Option<ExpectedFailure> {
    match expected_attr {
        Attribute::Assign(id, _sym, _val) => {
            let assign_loc = env.get_node_loc(*id);
            let invalid_assignment_msg = "Invalid expected failure code assignment";
            let expected_msg =
                "Expect an #[expected_failure(...)] attribute for error specification";
            env.error_with_labels(&assign_loc, invalid_assignment_msg, vec![(
                assign_loc.clone(),
                expected_msg.to_string(),
            )]);
            None
        },
        Attribute::Constrained(id, _, _, _) => {
            let aloc = env.get_node_loc(*id);
            env.error(
                &aloc,
                "Constraint operators (`!=`, `in`) are not supported in #[expected_failure(...)]",
            );
            None
        },
        Attribute::Apply(id, sym, attrs) => {
            assert!(
                TestingAttribute::EXPECTED_FAILURE == env.symbol_pool().string(*sym).to_string(),
                "ICE: We should only be parsing a raw expected failure attribute"
            );
            if attrs.is_empty() {
                return Some(ExpectedFailure::Expected);
            };
            let mut attrs: BTreeMap<String, Attribute> = attrs
                .iter()
                .map(|attr| {
                    (
                        env.symbol_pool().string(attr.name()).to_string(),
                        attr.clone(),
                    )
                })
                .collect();
            let mut expected_failure_kind_vec = TestingAttribute::expected_failure_cases()
                .iter()
                .filter_map(|k| {
                    let k = k.to_string();
                    let attr = attrs.remove(&k)?;
                    Some((k, attr))
                })
                .collect::<Vec<_>>();
            if expected_failure_kind_vec.len() != 1 {
                let invalid_attr_msg = format!(
                    "Invalid #[expected_failure(...)] attribute, expected 1 failure kind but found {}. Expected one of: {}",
                    expected_failure_kind_vec.len(),
                    TestingAttribute::expected_failure_cases().to_vec().join(", ")
                );
                let aloc = env.get_node_loc(*id);
                env.error(&aloc, &invalid_attr_msg);
                return None;
            }
            let (expected_failure_kind, attr) = expected_failure_kind_vec.pop().unwrap();
            let location_opt = attrs.remove(TestingAttribute::ERROR_LOCATION);
            let attr_loc = env.get_node_loc(attr.node_id());
            let (status_code, sub_status_code, location) = match expected_failure_kind.as_str() {
                TestingAttribute::ABORT_CODE_NAME => {
                    let (_value_name_loc, attr_value) =
                        get_assigned_attribute(env, TestingAttribute::ABORT_CODE_NAME, attr)?;
                    let (value_loc, opt_const_module_id, u) =
                        convert_constant_value_u64_constant_or_value(
                            env,
                            current_module,
                            &attr_value,
                        )?;
                    let location = if let Some(location_attr) = location_opt {
                        convert_location(env, location_attr)?
                    } else if let Some(location) = opt_const_module_id {
                        location
                    } else {
                        let tip = format!(
                            "Replace value with constant from expected module or add `{}=...` \
                            attribute.",
                            TestingAttribute::ERROR_LOCATION
                        );
                        env.diag_with_labels(
                            Severity::Warning,
                            &attr_loc,
                            "Test will pass on an abort from *any* module.",
                            vec![(value_loc, tip)],
                        );
                        return Some(ExpectedFailure::ExpectedWithCodeDEPRECATED(u));
                    };
                    (StatusCode::ABORTED, Some(u), location)
                },
                TestingAttribute::ARITHMETIC_ERROR_NAME => {
                    check_attribute_unassigned(env, TestingAttribute::ARITHMETIC_ERROR_NAME, attr)?;
                    let location_attr = check_location(
                        env,
                        attr_loc,
                        TestingAttribute::ARITHMETIC_ERROR_NAME,
                        location_opt,
                    )?;
                    let location = convert_location(env, location_attr)?;
                    (StatusCode::ARITHMETIC_ERROR, None, location)
                },
                TestingAttribute::OUT_OF_GAS_NAME => {
                    check_attribute_unassigned(env, TestingAttribute::OUT_OF_GAS_NAME, attr)?;
                    let location_attr = check_location(
                        env,
                        attr_loc,
                        TestingAttribute::OUT_OF_GAS_NAME,
                        location_opt,
                    )?;
                    let location = convert_location(env, location_attr)?;
                    (StatusCode::OUT_OF_GAS, None, location)
                },
                TestingAttribute::VECTOR_ERROR_NAME => {
                    check_attribute_unassigned(env, TestingAttribute::VECTOR_ERROR_NAME, attr)?;
                    let minor_attr_opt = attrs.remove(TestingAttribute::MINOR_STATUS_NAME);
                    let minor_status = if let Some(minor_attr) = minor_attr_opt {
                        let (_minor_value_loc, minor_value) = get_assigned_attribute(
                            env,
                            TestingAttribute::MINOR_STATUS_NAME,
                            minor_attr,
                        )?;
                        let (_, _, minor_status) = convert_constant_value_u64_constant_or_value(
                            env,
                            current_module,
                            &minor_value,
                        )?;
                        Some(minor_status)
                    } else {
                        None
                    };
                    let location_attr = check_location(
                        env,
                        attr_loc,
                        TestingAttribute::VECTOR_ERROR_NAME,
                        location_opt,
                    )?;
                    let location = convert_location(env, location_attr)?;
                    (StatusCode::VECTOR_OPERATION_ERROR, minor_status, location)
                },
                TestingAttribute::MAJOR_STATUS_NAME => {
                    let (value_name_loc, attr_value) =
                        get_assigned_attribute(env, TestingAttribute::MAJOR_STATUS_NAME, attr)?;
                    let (major_value_loc, _, major_status_u64) =
                        convert_constant_value_u64_constant_or_value(
                            env,
                            current_module,
                            &attr_value,
                        )?;
                    let major_status = if let Ok(c) = StatusCode::try_from(major_status_u64) {
                        c
                    } else {
                        let bad_value = format!(
                            "Invalid value for `{}`",
                            TestingAttribute::MAJOR_STATUS_NAME,
                        );
                        let no_code =
                            format!("No status code associated with value `{major_status_u64}`");
                        env.error_with_labels(&value_name_loc, &bad_value, vec![(
                            major_value_loc,
                            no_code,
                        )]);
                        return None;
                    };
                    let minor_attr_opt = attrs.remove(TestingAttribute::MINOR_STATUS_NAME);
                    let minor_status = if let Some(minor_attr) = minor_attr_opt {
                        let (_minor_value_loc, minor_value) = get_assigned_attribute(
                            env,
                            TestingAttribute::MINOR_STATUS_NAME,
                            minor_attr,
                        )?;
                        let (_, _, minor_status) = convert_constant_value_u64_constant_or_value(
                            env,
                            current_module,
                            &minor_value,
                        )?;
                        Some(minor_status)
                    } else {
                        None
                    };
                    let location_attr = check_location(
                        env,
                        attr_loc,
                        TestingAttribute::MAJOR_STATUS_NAME,
                        location_opt,
                    )?;
                    let location = convert_location(env, location_attr)?;
                    (major_status, minor_status, location)
                },
                _ => unreachable!(),
            };
            // warn for any remaining attrs
            for (_, attr) in attrs {
                let loc = env.get_node_loc(attr.node_id());
                let msg = format!(
                    "Unused attribute for {}",
                    TestingAttribute::ExpectedFailure.name()
                );
                env.diag(Severity::Warning, &loc, &msg);
            }
            Some(ExpectedFailure::ExpectedWithError(ExpectedMoveError(
                status_code,
                sub_status_code,
                move_binary_format::errors::Location::Module(location),
                None,
            )))
        },
    }
}

fn check_attribute_unassigned(env: &GlobalEnv, kind: &str, attr: Attribute) -> Option<()> {
    match attr {
        Attribute::Apply(id, sym, vec) => {
            assert!(env.symbol_pool().string(sym).to_string() == kind);
            if !vec.is_empty() {
                let msg = format!(
                    "Expected no parameters for for expected failure attribute `{}`",
                    kind
                );
                let attr_loc = env.get_node_loc(id);
                env.error(&attr_loc, &msg);
                None
            } else {
                Some(())
            }
        },
        Attribute::Assign(id, sym, _) => {
            assert!(env.symbol_pool().string(sym).to_string() == kind);
            let msg = format!(
                "Expected no assigned value, e.g. `{}`, for expected failure attribute",
                kind
            );
            let attr_loc = env.get_node_loc(id);
            env.error(&attr_loc, &msg);
            None
        },
        Attribute::Constrained(id, sym, _, _) => {
            assert!(env.symbol_pool().string(sym).to_string() == kind);
            let attr_loc = env.get_node_loc(id);
            env.error(
                &attr_loc,
                "Constraint operators (`!=`, `in`) are not supported in expected failure attributes",
            );
            None
        },
    }
}

fn get_assigned_attribute(
    env: &GlobalEnv,
    kind: &str,
    attr: Attribute,
) -> Option<(Loc, AttributeValue)> {
    match attr {
        Attribute::Assign(id, sym, value) => {
            assert!(env.symbol_pool().string(sym).to_string() == kind);
            let loc = env.get_node_loc(id);
            Some((loc, value))
        },
        Attribute::Apply(id, _sym, _vec) => {
            let loc = env.get_node_loc(id);
            let msg = format!(
                "Expected assigned value, e.g. `{}=...`, for expected failure attribute",
                kind
            );
            env.error(&loc, &msg);
            None
        },
        Attribute::Constrained(id, _, _, _) => {
            let loc = env.get_node_loc(id);
            env.error(
                &loc,
                "Constraint operators (`!=`, `in`) are not supported in expected failure attributes",
            );
            None
        },
    }
}

fn convert_location(env: &GlobalEnv, attr: Attribute) -> Option<ModuleId> {
    let (loc, value) = get_assigned_attribute(env, TestingAttribute::ERROR_LOCATION, attr)?;
    match value {
        AttributeValue::Name(id, opt_module_name, sym) => {
            let vloc = env.get_node_loc(id);
            let module_id_opt = convert_module_id(env, vloc.clone(), opt_module_name);
            if !sym.display(env.symbol_pool()).to_string().is_empty() || module_id_opt.is_none() {
                env.error_with_labels(&loc, "invalid attribute value", vec![(
                    vloc,
                    "Expected a module identifier, e.g. 'std::vector'".to_string(),
                )]);
            }
            module_id_opt
        },
        AttributeValue::Value(id, _val) => {
            let vloc = env.get_node_loc(id);
            env.error_with_labels(&loc, "invalid attribute value", vec![(
                vloc,
                "Expected a module identifier, e.g. 'std::vector'".to_string(),
            )]);
            None
        },
        AttributeValue::List(id, _)
        | AttributeValue::Range { id, .. }
        | AttributeValue::Union(id, _) => {
            let vloc = env.get_node_loc(id);
            env.error_with_labels(&loc, "invalid attribute value", vec![(
                vloc,
                "Expected a module identifier, e.g. 'std::vector'".to_string(),
            )]);
            None
        },
    }
}

fn convert_constant_value_u64_constant_or_value(
    env: &GlobalEnv,
    current_module: &ModuleName,
    value: &AttributeValue,
) -> Option<(Loc, Option<ModuleId>, u64)> {
    let (vloc, opt_module_name, member) = match value {
        AttributeValue::Value(id, val) => {
            let loc = env.get_node_loc(*id);
            if let Some((vloc, u)) = convert_model_ast_value_u64(env, loc, val) {
                return Some((vloc, None, u));
            } else {
                return None;
            }
        },
        AttributeValue::Name(id, opt_module_name, sym) => {
            let vloc = env.get_node_loc(*id);
            (vloc, opt_module_name, sym)
        },
        AttributeValue::List(id, _)
        | AttributeValue::Range { id, .. }
        | AttributeValue::Union(id, _) => {
            let loc = env.get_node_loc(*id);
            env.error(
                &loc,
                "Expected a numeric constant or value; list, range, and union forms are not supported here",
            );
            return None;
        },
    };
    let module_env: ModuleEnv = if let Some(module_name) = opt_module_name {
        if let Some(module_env) = env.find_module(module_name) {
            module_env
        } else {
            env.error(
                &vloc,
                &format!(
                    "Unbound module `{}` in constant",
                    module_name.display_full(env)
                ),
            );
            return None;
        }
    } else {
        env.find_module(current_module)
            .expect("current module exists")
    };
    let module_name = opt_module_name.as_ref().unwrap_or(current_module).clone();
    let named_constant_env =
        if let Some(named_constant_env) = module_env.find_named_constant(*member) {
            named_constant_env
        } else {
            env.error(
                &vloc,
                &format!(
                    "Unbound constant `{}` in module `{}`",
                    member.display(env.symbol_pool()),
                    module_name.display_full(env)
                ),
            );
            return None;
        };
    let ty = named_constant_env.get_type();
    let value = named_constant_env.get_value();
    let mod_id: Option<ModuleId> = convert_module_id(env, vloc.clone(), opt_module_name.clone());
    let (severity, message) = match value {
        Value::Number(u) => match ty {
            Type::Primitive(PrimitiveType::U64) => {
                if u <= BigInt::from(u64::MAX) {
                    return Some((vloc, mod_id, u.to_u64().unwrap()));
                } else {
                    (
                        Severity::Bug,
                        format!(
                            "Constant `{}::{}` value is out of range for u64",
                            module_name.display_full(env),
                            named_constant_env.get_name().display(env.symbol_pool())
                        ),
                    )
                }
            },
            Type::Primitive(PrimitiveType::Num) => {
                if u <= BigInt::from(u64::MAX) {
                    return Some((vloc, mod_id, u.to_u64().unwrap()));
                } else {
                    (
                        Severity::Error,
                        format!(
                            "Constant `{}::{}` value is out of range for u64",
                            module_name.display_full(env),
                            named_constant_env.get_name().display(env.symbol_pool())
                        ),
                    )
                }
            },
            _ => (
                Severity::Error,
                format!(
                    "Constant `{}::{}` has a non-u64 value.  Only `u64` values are permitted",
                    module_name.display_full(env),
                    named_constant_env.get_name().display(env.symbol_pool())
                ),
            ),
        },
        _ => (
            Severity::Error,
            format!(
                "Constant `{}::{}` has a non-numeric value.  Only `u64` values are permitted",
                module_name.display_full(env),
                named_constant_env.get_name().display(env.symbol_pool())
            ),
        ),
    };
    env.diag(severity, &vloc, &message);
    None
}

fn convert_module_id(env: &GlobalEnv, _vloc: Loc, module: Option<ModuleName>) -> Option<ModuleId> {
    if let Some(module_name) = module {
        let addr = module_name.addr();
        let sym = module_name.name();
        let sym_rc_str = env.symbol_pool().string(sym).to_string();
        let sym_core_id = Identifier::new(sym_rc_str).unwrap();
        match addr {
            Address::Numerical(addr) => Some(*addr),
            Address::Symbolic(sym) => env.resolve_address_alias(*sym),
        }
        .map(|account_address| ModuleId::new(account_address, sym_core_id))
    } else {
        None
    }
}

fn convert_model_ast_value_u64(env: &GlobalEnv, loc: Loc, value: &Value) -> Option<(Loc, u64)> {
    match value {
        Value::Number(u) => {
            if u <= &BigInt::from(u64::MAX) {
                Some((loc, u.to_u64().unwrap()))
            } else {
                env.error(
                    &loc,
                    "Invalid attribute value: only u64 literal values permitted",
                );
                None
            }
        },
        _ => {
            env.error(
                &loc,
                "Invalid attribute value: only u64 literal values permitted",
            );
            None
        },
    }
}

fn convert_attribute_value_to_move_value(
    env: &GlobalEnv,
    value: &AttributeValue,
) -> Option<MoveValue> {
    // Addresses, bools, and integer literals are accepted. Integers are carried
    // as a `u256` placeholder here because the parameter's actual width is not
    // known until `coerce_to_param_type` runs; coercion narrows (with a range
    // check) to the real type.
    match value {
        AttributeValue::Value(_id, Value::Address(addr)) => match addr {
            Address::Numerical(num) => Some(*num),
            Address::Symbolic(sym) => env.resolve_address_alias(*sym),
        }
        .map(MoveValue::Address),
        AttributeValue::Value(_id, Value::Bool(b)) => Some(MoveValue::Bool(*b)),
        AttributeValue::Value(_id, Value::Number(n)) => bigint_to_u256_carrier(n),
        _ => None,
    }
}

/// Carry a non-negative integer literal as a `u256` `MoveValue`. Returns `None`
/// for negative or larger-than-`u256` values (which cannot appear for a Move
/// integer literal, but are rejected defensively).
fn bigint_to_u256_carrier(n: &BigInt) -> Option<MoveValue> {
    if n.sign() == Sign::Minus {
        return None;
    }
    let (_sign, be) = n.to_bytes_be();
    if be.len() > 32 {
        return None;
    }
    let mut buf = [0u8; 32];
    buf[32 - be.len()..].copy_from_slice(&be);
    buf.reverse(); // to little-endian for U256::from_le_bytes
    Some(MoveValue::U256(u256::U256::from_le_bytes(&buf)))
}

fn check_location<T>(env: &GlobalEnv, loc: Loc, attr: &str, location: Option<T>) -> Option<T> {
    if location.is_none() {
        let msg = format!(
            "Expected `{}` following `{}`",
            TestingAttribute::ERROR_LOCATION,
            attr
        );
        env.error(&loc, &msg)
    }
    location
}
