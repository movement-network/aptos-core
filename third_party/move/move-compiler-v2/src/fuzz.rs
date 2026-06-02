// Copyright (c) Aptos Foundation
// SPDX-License-Identifier: Apache-2.0

//! Fuzz value generation for the `#[test]` attribute.
//!
//! ## Design
//!
//! Modeled on Foundry's fuzz architecture (`crates/evm/fuzz/`): the compiler
//! does not pick fuzz values itself. It collects per-parameter constraints
//! (`a in <domain>`, `a != <exclude>`, or absence-of-spec) into a [`ParamSpec`]
//! and asks a [`FuzzValueSource`] to materialize concrete values for each
//! parameter at plan-build time.
//!
//! Three sources of values are mixed when sampling a primitive parameter, in
//! the same spirit as Foundry's `UintStrategy` (`crates/evm/fuzz/src/strategies/uint.rs`):
//!
//! - **Random** — pseudo-random values drawn from the parameter type's full
//!   width (default 50%).
//! - **Edge cases** — boundary values like `0`, `1`, `MAX`, `MAX-1`, `MAX/2`
//!   to catch off-by-one bugs (default 10%).
//! - **Dictionary** — values mined from the surrounding Move program: named
//!   address aliases and module-level constants of compatible primitive
//!   types (default 40%).
//!
//! Domain (`a in ...`) and exclude (`a != ...`) sets filter the candidate
//! after generation; on a reject we redraw, capped at [`FUZZ_RETRIES`] times
//! the requested count to avoid pathological loops.
//!
//! The implementation is deterministic given the seed and intentionally
//! avoids `proptest` to keep the dependency surface small — the Foundry
//! analogue is `proptest` driven, but for a Move test runner the value
//! pipeline can be a plain seeded RNG since we do not (yet) need shrinking.

use move_core_types::{
    account_address::AccountAddress, language_storage::ModuleId, u256, value::MoveValue,
};
use move_model::{
    ast::{Address, AttributeValue, Value},
    model::GlobalEnv,
    ty::{PrimitiveType, Type},
};
use num::{bigint::Sign, BigInt, ToPrimitive};
use std::collections::BTreeMap;

// ---------------------------------------------------------------------------
// Public surface — unchanged from Phase 2
// ---------------------------------------------------------------------------

/// A single inclusive/half-open range. Both endpoints are model-AST literals
/// because the compiler does not commit to a concrete representation until the
/// source materializes a sample for the parameter type.
#[derive(Debug, Clone)]
pub struct RangeSpec {
    pub lo: AttributeValue,
    pub hi: AttributeValue,
    pub inclusive_hi: bool,
}

/// A union of discrete literals and ranges. An empty domain is treated as
/// "unrestricted" when used as a fuzz `domain`, and as "no exclusions" when
/// used as an `exclude`.
#[derive(Debug, Clone, Default)]
pub struct Domain {
    pub literals: Vec<AttributeValue>,
    pub ranges: Vec<RangeSpec>,
}

impl Domain {
    pub fn is_empty(&self) -> bool {
        self.literals.is_empty() && self.ranges.is_empty()
    }
}

/// What the compiler resolved for one function parameter after reading the
/// `#[test(...)]` attribute and any constraints attached to it.
#[derive(Debug, Clone)]
pub enum ParamSpec {
    /// `a = <literal>` — a single explicit value.
    Concrete(MoveValue),
    /// `a = [<literal>, <literal>, ...]` — a matrix that expands into N cases.
    Matrix(Vec<MoveValue>),
    /// `a` not mentioned, or `a in ...` / `a != ...`. The fuzz source samples
    /// `n` values from `domain` (unrestricted when empty), subject to
    /// `exclude`.
    Fuzz { domain: Domain, exclude: Domain },
}

// ---------------------------------------------------------------------------
// Plan metadata sidecar — Topic 3 / Topic 2
// ---------------------------------------------------------------------------

/// Per-argument origin for an expanded test case. The runner consults this to
/// decide whether shrinking and mutation are applicable to a failing case.
#[derive(Debug, Clone)]
pub enum ArgOrigin {
    /// The argument came from a `Concrete` or `Matrix` spec; not shrinkable.
    Fixed,
    /// The argument was drawn by the fuzz source; eligible for shrink/mutate.
    Fuzz {
        param_name: String,
        ty: Type,
        domain: Domain,
        exclude: Domain,
    },
}

/// Map from `(module_id, expanded_test_name)` to per-argument origin. The
/// runner can look up an entry for a failing test to know which arguments to
/// shrink and which to keep fixed.
#[derive(Debug, Default, Clone)]
pub struct FuzzPlanMetadata {
    pub entries: BTreeMap<(ModuleId, String), Vec<ArgOrigin>>,
}

impl FuzzPlanMetadata {
    pub fn insert(&mut self, module_id: ModuleId, test_name: String, origins: Vec<ArgOrigin>) {
        self.entries.insert((module_id, test_name), origins);
    }

    pub fn get(&self, module_id: &ModuleId, test_name: &str) -> Option<&Vec<ArgOrigin>> {
        // ModuleId isn't Hash for BTreeMap lookup with (&_, &str); rebuild key.
        self.entries
            .iter()
            .find(|((m, n), _)| m == module_id && n == test_name)
            .map(|(_, v)| v)
    }
}

/// Plugged in by the unit-test entrypoint. The compiler never instantiates
/// fuzz values itself; it only collects constraints.
///
/// Three methods, two with default impls — implementers only need [`sample`].
/// [`shrink`] gives counterexample minimization (Topic 3); [`mutate`] backs
/// the corpus-driven path (Topic 2).
pub trait FuzzValueSource: Send + Sync {
    /// Materialize `n` values of type `ty` for parameter `param_name`, drawn
    /// from `domain` (unrestricted when empty) and avoiding any value in
    /// `exclude`. `seed` is provided for reproducibility.
    ///
    /// Passing `n == 0` requests the source's own configured run count (for
    /// [`DefaultFuzzSource`] that is [`FuzzConfig::runs`]). Callers that are
    /// generic over the source — like the plan builder — pass `0` so the
    /// `--fuzz-runs` setting is honored instead of a hardcoded count.
    ///
    /// `param_name` enables Foundry-style fixtures — sources can route
    /// per-parameter using user-declared `FIXTURE_<name>` constants. The
    /// caller passes the parameter's display string so the trait doesn't
    /// depend on a `SymbolPool`.
    fn sample(
        &self,
        ty: &Type,
        param_name: &str,
        domain: &Domain,
        exclude: &Domain,
        n: usize,
        seed: u64,
    ) -> Result<Vec<MoveValue>, String>;

    /// Produce a "smaller" candidate close to `current` for shrinking a failing
    /// counterexample. Returns `None` when no further shrinking is possible —
    /// the runner stops shrinking when this returns `None` or when no shrink
    /// candidate still reproduces the failure.
    ///
    /// Default: no shrinking. Override for type-aware minimization.
    fn shrink(
        &self,
        _ty: &Type,
        _param_name: &str,
        _current: &MoveValue,
        _domain: &Domain,
        _exclude: &Domain,
    ) -> Option<MoveValue> {
        None
    }

    /// Mutate `current` to a nearby value for corpus-driven exploration.
    /// Returns `None` when no useful mutation is available. The mutated value
    /// must still satisfy the original `domain` / `exclude`.
    ///
    /// Default: no mutation. Override when wiring corpus replay.
    fn mutate(
        &self,
        _ty: &Type,
        _param_name: &str,
        _current: &MoveValue,
        _domain: &Domain,
        _exclude: &Domain,
        _seed: u64,
    ) -> Option<MoveValue> {
        None
    }
}

/// Default source that produces no samples and reports a clear error. Plug a
/// real implementation in to light up the fuzz path.
pub struct NoFuzzSource;

impl FuzzValueSource for NoFuzzSource {
    fn sample(
        &self,
        _ty: &Type,
        _param_name: &str,
        _domain: &Domain,
        _exclude: &Domain,
        _n: usize,
        _seed: u64,
    ) -> Result<Vec<MoveValue>, String> {
        Err(
            "no fuzz value source is registered; install a `FuzzValueSource` to enable \
             implicit-fuzz #[test] expansion"
                .to_string(),
        )
    }
}

// ---------------------------------------------------------------------------
// Configuration
// ---------------------------------------------------------------------------

/// Tunables for [`DefaultFuzzSource`]. The knob *names* mirror Foundry's
/// `[fuzz]` section so users coming from EVM tooling find familiar dials, but
/// the defaults are not identical: `runs` defaults to 16 rather than Foundry's
/// 256. The lower default is intentional — each case is a full in-process
/// MoveVM execution, and the plan builder Cartesian-multiplies fuzz `runs`
/// against any explicit `#[test]` matrices under a `MAX_FUZZ_CASES` (1024) cap,
/// so a 256 default would blow that ceiling as soon as a test has a couple of
/// matrix dimensions. Raise `runs` (or `--fuzz-runs`) for deeper search.
/// `dictionary_weight` does match Foundry's default of 40.
#[derive(Clone, Debug)]
pub struct FuzzConfig {
    /// Number of samples drawn per implicit-fuzz parameter.
    pub runs: usize,
    /// Base RNG seed. Independent of the seed argument passed to
    /// [`FuzzValueSource::sample`] — the two are mixed together so that the
    /// same source can produce stable but parameter-distinct streams.
    pub seed: u64,
    /// Relative weight (0..=100) of dictionary draws against the random+edge
    /// strategies. Mirrors Foundry's `dictionary_weight` (default 40).
    pub dictionary_weight: u8,
    /// Maximum number of retries (relative to `runs`) when domain/exclude
    /// constraints reject candidate draws.
    pub max_retry_multiplier: usize,
}

impl Default for FuzzConfig {
    fn default() -> Self {
        Self {
            runs: 16,
            seed: 0,
            dictionary_weight: 40,
            max_retry_multiplier: 64,
        }
    }
}

/// Foundry's `prop_oneof` carves up 100. We use the same shape so the
/// invariants travel: `random + edge + dictionary == 100`.
const EDGE_WEIGHT: u8 = 10;

// ---------------------------------------------------------------------------
// Dictionary — Foundry analogue of `crates/evm/fuzz/src/strategies/state.rs`
// ---------------------------------------------------------------------------

/// Typed pool of "interesting values" mined from the Move program. Roughly
/// analogous to Foundry's `FuzzDictionary`, but Move-shaped: instead of
/// account addresses + bytecode PUSH bytes + storage values from the EVM DB,
/// we collect named addresses + module-constant values from the model.
///
/// `fixtures` holds per-parameter-name pools harvested from constants whose
/// name starts with `FIXTURE_` / `fixture_` (case-insensitive). The
/// remainder of the name, lowercased, is the parameter key. E.g.
/// `const FIXTURE_AMOUNT: u64 = 42;` populates `fixtures["amount"]`.
#[derive(Default, Debug)]
pub struct FuzzDictionary {
    pub addresses: Vec<AccountAddress>,
    pub uints: Vec<BigInt>,
    pub bools: Vec<bool>,
    pub fixtures: BTreeMap<String, FixturePool>,
}

/// Typed buckets for a single parameter's fixtures.
#[derive(Default, Debug, Clone)]
pub struct FixturePool {
    pub addresses: Vec<AccountAddress>,
    pub uints: Vec<BigInt>,
    pub bools: Vec<bool>,
}

impl FixturePool {
    fn is_empty(&self) -> bool {
        self.addresses.is_empty() && self.uints.is_empty() && self.bools.is_empty()
    }
}

const FIXTURE_PREFIX: &str = "fixture_";

impl FuzzDictionary {
    /// Walk the [`GlobalEnv`] and harvest:
    /// - every resolved named-address alias,
    /// - every primitive-typed module constant,
    /// - per-name fixture pools from `FIXTURE_<param>` constants.
    pub fn from_env(env: &GlobalEnv) -> Self {
        let mut d = FuzzDictionary::default();

        for addr in env.get_address_alias_map().values() {
            d.addresses.push(*addr);
        }

        for module in env.get_modules() {
            for c in module.get_named_constants() {
                let raw_name = env.symbol_pool().string(c.get_name()).to_string();
                let lowered = raw_name.to_lowercase();
                let value = c.get_value();

                // Dictionary-wide insertion.
                insert_value_into_buckets(env, &value, &mut d.addresses, &mut d.uints, &mut d.bools);

                // Fixture insertion when the name matches the prefix.
                if let Some(rest) = lowered.strip_prefix(FIXTURE_PREFIX) {
                    if !rest.is_empty() {
                        let pool = d.fixtures.entry(rest.to_string()).or_default();
                        insert_value_into_buckets(
                            env,
                            &value,
                            &mut pool.addresses,
                            &mut pool.uints,
                            &mut pool.bools,
                        );
                    }
                }
            }
        }

        d.addresses.sort_unstable();
        d.addresses.dedup();
        d.uints.sort();
        d.uints.dedup();
        d.bools.sort();
        d.bools.dedup();
        for pool in d.fixtures.values_mut() {
            pool.addresses.sort_unstable();
            pool.addresses.dedup();
            pool.uints.sort();
            pool.uints.dedup();
            pool.bools.sort();
            pool.bools.dedup();
        }
        d
    }

    /// Lookup a fixture pool by lowercased parameter name. Returns `None`
    /// when no fixtures were declared for that name.
    pub fn fixture_for(&self, param_name_lowered: &str) -> Option<&FixturePool> {
        self.fixtures
            .get(param_name_lowered)
            .filter(|p| !p.is_empty())
    }
}

/// Slot a model AST `Value` into the appropriate typed bucket(s). Address
/// aliases that resolve are flattened to their numeric form.
fn insert_value_into_buckets(
    env: &GlobalEnv,
    value: &Value,
    addrs: &mut Vec<AccountAddress>,
    uints: &mut Vec<BigInt>,
    bools: &mut Vec<bool>,
) {
    match value {
        Value::Address(Address::Numerical(a)) => addrs.push(*a),
        Value::Address(Address::Symbolic(s)) => {
            if let Some(a) = env.resolve_address_alias(*s) {
                addrs.push(a);
            }
        },
        Value::Number(n) => uints.push(n.clone()),
        Value::Bool(b) => bools.push(*b),
        // Vector / ByteArray / Tuple are skipped for now — see Phase-4 design notes.
        _ => {},
    }
}

// ---------------------------------------------------------------------------
// DefaultFuzzSource — Foundry analogue of `FuzzedExecutor`
// ---------------------------------------------------------------------------

/// Built-in fuzz value source: deterministic per `(config.seed, sample-seed)`,
/// honors Move primitive types, and mixes random + edge + dictionary draws.
pub struct DefaultFuzzSource {
    pub config: FuzzConfig,
    pub dictionary: FuzzDictionary,
}

impl DefaultFuzzSource {
    /// Construct a source whose dictionary is harvested from `env`. Use this
    /// from the unit-test entrypoint — the dictionary is rebuilt per
    /// compilation.
    pub fn new(env: &GlobalEnv, config: FuzzConfig) -> Self {
        Self {
            dictionary: FuzzDictionary::from_env(env),
            config,
        }
    }

    /// Construct a source with an empty dictionary. Useful in tests where the
    /// dictionary pollution shouldn't matter.
    pub fn with_empty_dictionary(config: FuzzConfig) -> Self {
        Self {
            dictionary: FuzzDictionary::default(),
            config,
        }
    }
}

impl FuzzValueSource for DefaultFuzzSource {
    fn sample(
        &self,
        ty: &Type,
        param_name: &str,
        domain: &Domain,
        exclude: &Domain,
        n: usize,
        seed: u64,
    ) -> Result<Vec<MoveValue>, String> {
        let count = if n == 0 { self.config.runs } else { n };
        // Mix the configured base seed with the parameter-specific seed so that
        // two parameters of the same type don't generate identical streams.
        let mut rng = Rng(self.config.seed.wrapping_mul(0x9E3779B97F4A7C15).wrapping_add(seed));
        let fixture_pool = self.dictionary.fixture_for(&param_name.to_lowercase());

        match prim_kind(ty) {
            Some(PrimKind::AddressLike(addr_like)) => sample_addresses(
                &mut rng,
                count,
                addr_like,
                domain,
                exclude,
                &self.dictionary,
                fixture_pool,
            ),
            Some(PrimKind::Uint(width)) => sample_uints(
                &mut rng,
                count,
                width,
                domain,
                exclude,
                &self.dictionary,
                fixture_pool,
                self.config.dictionary_weight,
                self.config.max_retry_multiplier,
            ),
            Some(PrimKind::Bool) => {
                sample_bools(&mut rng, count, domain, exclude, fixture_pool)
            },
            None => Err(format!(
                "fuzz: cannot sample for parameter type `{:?}`; only address/signer, \
                 uN (u8..u256), and bool are supported by the default source",
                ty
            )),
        }
    }

    fn shrink(
        &self,
        ty: &Type,
        _param_name: &str,
        current: &MoveValue,
        domain: &Domain,
        exclude: &Domain,
    ) -> Option<MoveValue> {
        shrink_value(ty, current, domain, exclude)
    }

    fn mutate(
        &self,
        ty: &Type,
        _param_name: &str,
        current: &MoveValue,
        domain: &Domain,
        exclude: &Domain,
        seed: u64,
    ) -> Option<MoveValue> {
        let mut rng = Rng(self.config.seed.wrapping_add(seed));
        mutate_value(&mut rng, ty, current, domain, exclude, &self.dictionary)
    }
}

// ---------------------------------------------------------------------------
// RNG — inline SplitMix64
// ---------------------------------------------------------------------------

/// Deterministic SplitMix64 — chosen instead of a `rand` dependency because
/// we only need uniform `u64` output, never a distribution from the `rand`
/// crate. Quality is sufficient for property-style fuzzing.
struct Rng(u64);

impl Rng {
    fn next_u64(&mut self) -> u64 {
        self.0 = self.0.wrapping_add(0x9E3779B97F4A7C15);
        let mut z = self.0;
        z = (z ^ (z >> 30)).wrapping_mul(0xBF58476D1CE4E5B9);
        z = (z ^ (z >> 27)).wrapping_mul(0x94D049BB133111EB);
        z ^ (z >> 31)
    }

    fn pick<'a, T>(&mut self, xs: &'a [T]) -> Option<&'a T> {
        if xs.is_empty() {
            None
        } else {
            Some(&xs[(self.next_u64() as usize) % xs.len()])
        }
    }
}

// ---------------------------------------------------------------------------
// Type classification
// ---------------------------------------------------------------------------

#[derive(Copy, Clone, Debug)]
enum PrimKind {
    AddressLike(AddressLike),
    Uint(UintWidth),
    Bool,
}

#[derive(Copy, Clone, Debug)]
enum AddressLike {
    Address,
    Signer,
}

#[derive(Copy, Clone, Debug)]
enum UintWidth {
    U8,
    U16,
    U32,
    U64,
    U128,
    U256,
}

fn prim_kind(ty: &Type) -> Option<PrimKind> {
    match ty {
        Type::Primitive(p) => match p {
            PrimitiveType::Address => Some(PrimKind::AddressLike(AddressLike::Address)),
            PrimitiveType::Signer => Some(PrimKind::AddressLike(AddressLike::Signer)),
            PrimitiveType::Bool => Some(PrimKind::Bool),
            PrimitiveType::U8 => Some(PrimKind::Uint(UintWidth::U8)),
            PrimitiveType::U16 => Some(PrimKind::Uint(UintWidth::U16)),
            PrimitiveType::U32 => Some(PrimKind::Uint(UintWidth::U32)),
            PrimitiveType::U64 => Some(PrimKind::Uint(UintWidth::U64)),
            PrimitiveType::U128 => Some(PrimKind::Uint(UintWidth::U128)),
            PrimitiveType::U256 => Some(PrimKind::Uint(UintWidth::U256)),
            _ => None,
        },
        Type::Reference(_, inner) => match &**inner {
            Type::Primitive(PrimitiveType::Signer) => {
                Some(PrimKind::AddressLike(AddressLike::Signer))
            },
            _ => None,
        },
        _ => None,
    }
}

// ---------------------------------------------------------------------------
// Per-type samplers
// ---------------------------------------------------------------------------

fn sample_bools(
    rng: &mut Rng,
    n: usize,
    domain: &Domain,
    exclude: &Domain,
    fixtures: Option<&FixturePool>,
) -> Result<Vec<MoveValue>, String> {
    let dom_bools: Vec<bool> = domain.literals.iter().filter_map(extract_bool).collect();
    let exc_bools: Vec<bool> = exclude.literals.iter().filter_map(extract_bool).collect();
    let mut pool: Vec<bool> = if dom_bools.is_empty() {
        vec![false, true]
    } else {
        dom_bools
    };
    if let Some(f) = fixtures {
        // Fixtures don't expand the bool universe but bias the picker — Foundry
        // achieves this via weighting; we just duplicate them in the pool.
        pool.extend(f.bools.iter().copied());
    }
    let pool: Vec<bool> = pool.into_iter().filter(|b| !exc_bools.contains(b)).collect();
    if pool.is_empty() {
        return Err("fuzz: bool domain is empty after exclusions".to_string());
    }
    let mut out = Vec::with_capacity(n);
    for _ in 0..n {
        out.push(MoveValue::Bool(*rng.pick(&pool).unwrap()));
    }
    Ok(out)
}

fn sample_addresses(
    rng: &mut Rng,
    n: usize,
    kind: AddressLike,
    domain: &Domain,
    exclude: &Domain,
    dict: &FuzzDictionary,
    fixtures: Option<&FixturePool>,
) -> Result<Vec<MoveValue>, String> {
    let dom_addrs: Vec<AccountAddress> = domain
        .literals
        .iter()
        .filter_map(extract_address)
        .collect();
    let exc_addrs: Vec<AccountAddress> = exclude
        .literals
        .iter()
        .filter_map(extract_address)
        .collect();

    // Ranges on addresses are interpreted as [lo, hi] address-byte intervals.
    let dom_ranges = parse_address_ranges(&domain.ranges);
    let exc_ranges = parse_address_ranges(&exclude.ranges);
    let domain_active = !dom_addrs.is_empty() || !dom_ranges.is_empty();

    let wrap = |addr: AccountAddress| match kind {
        AddressLike::Address => MoveValue::Address(addr),
        AddressLike::Signer => MoveValue::Signer(addr),
    };
    let is_excluded = |addr: &AccountAddress| -> bool {
        exc_addrs.contains(addr)
            || exc_ranges
                .iter()
                .any(|(lo, hi, inc)| address_in_range(addr, lo, hi, *inc))
    };
    let in_domain = |addr: &AccountAddress| -> bool {
        !domain_active
            || dom_addrs.contains(addr)
            || dom_ranges
                .iter()
                .any(|(lo, hi, inc)| address_in_range(addr, lo, hi, *inc))
    };

    let mut out = Vec::with_capacity(n);
    let mut tries = 0usize;
    let cap = n.saturating_mul(64).max(1);

    // If the user explicitly listed addresses in the domain, prefer those —
    // they are almost certainly the values they want exercised.
    if !dom_addrs.is_empty() {
        for a in &dom_addrs {
            if !is_excluded(a) {
                out.push(wrap(*a));
                if out.len() == n {
                    return Ok(out);
                }
            }
        }
    }

    // Same for fixtures: drain them upfront so the user always sees them.
    if let Some(f) = fixtures {
        for a in &f.addresses {
            if in_domain(a) && !is_excluded(a) {
                out.push(wrap(*a));
                if out.len() == n {
                    return Ok(out);
                }
            }
        }
    }

    // Finite literal domain with no ranges: random/edge draws almost never
    // land in the listed set, so draw straight from it (with repeats) to fill
    // `n` rather than returning fewer values and capping the run count.
    let literal_only = !dom_addrs.is_empty() && dom_ranges.is_empty();

    while out.len() < n && tries < cap {
        tries += 1;
        if literal_only {
            match rng.pick(&dom_addrs).copied() {
                Some(a) if !is_excluded(&a) => out.push(wrap(a)),
                Some(_) => {},
                None => break,
            }
            continue;
        }
        let pick = rng.next_u64() % 100;
        let candidate = if pick < u64::from(EDGE_WEIGHT) {
            // Edge: well-known anchors.
            let edges = [
                AccountAddress::ZERO,
                AccountAddress::ONE,
                AccountAddress::from_hex_literal("0x2").unwrap_or(AccountAddress::ONE),
            ];
            *rng.pick(&edges).unwrap()
        } else if !dict.addresses.is_empty() && pick < 100 {
            // Dictionary, when available, otherwise random (handled below).
            *rng.pick(&dict.addresses).unwrap()
        } else {
            let mut bytes = [0u8; AccountAddress::LENGTH];
            for chunk in bytes.chunks_exact_mut(8) {
                chunk.copy_from_slice(&rng.next_u64().to_le_bytes());
            }
            AccountAddress::new(bytes)
        };
        let candidate = if dict.addresses.is_empty() && pick >= u64::from(EDGE_WEIGHT) && pick < 100
        {
            // We fell into the "dictionary" branch but the dictionary is empty —
            // synthesize a random address instead.
            let mut bytes = [0u8; AccountAddress::LENGTH];
            for chunk in bytes.chunks_exact_mut(8) {
                chunk.copy_from_slice(&rng.next_u64().to_le_bytes());
            }
            AccountAddress::new(bytes)
        } else {
            candidate
        };
        if !in_domain(&candidate) || is_excluded(&candidate) {
            continue;
        }
        out.push(wrap(candidate));
    }

    if out.is_empty() {
        return Err(
            "fuzz: could not generate any address values satisfying the given constraints"
                .to_string(),
        );
    }
    Ok(out)
}

fn sample_uints(
    rng: &mut Rng,
    n: usize,
    width: UintWidth,
    domain: &Domain,
    exclude: &Domain,
    dict: &FuzzDictionary,
    fixtures: Option<&FixturePool>,
    dictionary_weight: u8,
    max_retry_multiplier: usize,
) -> Result<Vec<MoveValue>, String> {
    let dom_lits: Vec<BigInt> = domain.literals.iter().filter_map(extract_bigint).collect();
    let exc_lits: Vec<BigInt> = exclude.literals.iter().filter_map(extract_bigint).collect();
    let dom_ranges = parse_int_ranges(&domain.ranges);
    let exc_ranges = parse_int_ranges(&exclude.ranges);
    let domain_active = !dom_lits.is_empty() || !dom_ranges.is_empty();
    let edges = uint_edges(width);
    let modulus = uint_modulus(width);

    let is_excluded = |v: &BigInt| -> bool {
        exc_lits.contains(v)
            || exc_ranges
                .iter()
                .any(|(lo, hi, inc)| in_int_range(v, lo, hi, *inc))
    };
    let in_domain = |v: &BigInt| -> bool {
        !domain_active
            || dom_lits.contains(v)
            || dom_ranges
                .iter()
                .any(|(lo, hi, inc)| in_int_range(v, lo, hi, *inc))
    };

    let mut out = Vec::with_capacity(n);

    // Seed with explicit domain literals first.
    for lit in &dom_lits {
        if !is_excluded(lit) {
            if let Some(v) = bigint_to_move_value(lit.clone(), width) {
                out.push(v);
                if out.len() == n {
                    return Ok(out);
                }
            }
        }
    }

    // Fixtures next: declared per-parameter values flow in before the
    // randomized pool.
    if let Some(f) = fixtures {
        for v in &f.uints {
            if in_domain(v) && !is_excluded(v) {
                if let Some(mv) = bigint_to_move_value(v.clone(), width) {
                    out.push(mv);
                    if out.len() == n {
                        return Ok(out);
                    }
                }
            }
        }
    }

    let dictionary_weight = dictionary_weight.min(100);
    let random_weight = 100u64.saturating_sub(u64::from(dictionary_weight) + u64::from(EDGE_WEIGHT));
    let edge_cutoff = u64::from(EDGE_WEIGHT);
    let dict_cutoff = edge_cutoff + u64::from(dictionary_weight);
    let _ = random_weight; // documentation; the random branch is the fall-through

    let mut tries = 0usize;
    let cap = n.saturating_mul(max_retry_multiplier).max(1);
    // When the domain is a finite set of literals (no ranges), random/edge/dict
    // draws almost never land in the set, so we'd return far fewer than `n`
    // values — which then caps the whole function's run count via the zip in
    // the plan builder. Draw straight from the literal set instead.
    let literal_only = domain_active && dom_ranges.is_empty();

    while out.len() < n && tries < cap {
        tries += 1;
        let pick = rng.next_u64() % 100;
        let candidate = if literal_only {
            // Cycle through the listed values (with repeats) to fill `n`.
            match rng.pick(&dom_lits) {
                Some(v) => v.clone(),
                None => break,
            }
        } else if pick < edge_cutoff {
            // Edge sample. If a domain range is active, draw an edge value
            // bracketed against the active range — honoring the half-open
            // upper bound so we never emit the excluded `hi`.
            if let Some((lo, hi, inc)) = rng.pick(&dom_ranges).cloned() {
                let hi_edge = if inc { hi } else { &hi - 1 };
                let endpoints = [lo.clone(), &lo + 1, &hi_edge - 1, hi_edge];
                rng.pick(&endpoints).cloned().unwrap_or_else(BigInt::default)
            } else {
                rng.pick(&edges).cloned().unwrap_or_else(BigInt::default)
            }
        } else if pick < dict_cutoff && !dict.uints.is_empty() {
            rng.pick(&dict.uints).cloned().unwrap_or_else(BigInt::default)
        } else if !dom_ranges.is_empty() {
            // Random within an active domain range.
            let (lo, hi, inc) = rng.pick(&dom_ranges).cloned().unwrap();
            sample_bigint_in_range(rng, &lo, &hi, inc)
        } else {
            // Full-width random draw. Going through `u128` here would cap u128
            // at 2^128-1 (unreachable max) and clamp u256 to its low 128 bits,
            // so draw enough limbs to cover the whole type instead.
            random_bigint_below(rng, &modulus)
        };
        // Coerce candidate into the type's representable range.
        let candidate = ((&candidate % &modulus) + &modulus) % &modulus;
        if !in_domain(&candidate) || is_excluded(&candidate) {
            continue;
        }
        if let Some(v) = bigint_to_move_value(candidate, width) {
            out.push(v);
        }
    }

    if out.is_empty() {
        return Err(
            "fuzz: could not generate any uint values satisfying the given constraints"
                .to_string(),
        );
    }
    Ok(out)
}

// ---------------------------------------------------------------------------
// AttributeValue extraction & range parsing
// ---------------------------------------------------------------------------

fn extract_bool(v: &AttributeValue) -> Option<bool> {
    match v {
        AttributeValue::Value(_, Value::Bool(b)) => Some(*b),
        _ => None,
    }
}

fn extract_address(v: &AttributeValue) -> Option<AccountAddress> {
    match v {
        AttributeValue::Value(_, Value::Address(Address::Numerical(a))) => Some(*a),
        _ => None,
    }
}

fn extract_bigint(v: &AttributeValue) -> Option<BigInt> {
    match v {
        AttributeValue::Value(_, Value::Number(n)) => Some(n.clone()),
        AttributeValue::Value(_, Value::Address(Address::Numerical(a))) => {
            Some(BigInt::from_bytes_be(Sign::Plus, a.as_ref()))
        },
        _ => None,
    }
}

fn parse_int_ranges(ranges: &[RangeSpec]) -> Vec<(BigInt, BigInt, bool)> {
    ranges
        .iter()
        .filter_map(|r| {
            let lo = extract_bigint(&r.lo)?;
            let hi = extract_bigint(&r.hi)?;
            Some((lo, hi, r.inclusive_hi))
        })
        .collect()
}

fn parse_address_ranges(ranges: &[RangeSpec]) -> Vec<(BigInt, BigInt, bool)> {
    // Treat an address range identically to a numeric range over the
    // 256-bit big-endian interpretation of the address bytes.
    parse_int_ranges(ranges)
}

fn in_int_range(v: &BigInt, lo: &BigInt, hi: &BigInt, inclusive_hi: bool) -> bool {
    if v < lo {
        return false;
    }
    if inclusive_hi {
        v <= hi
    } else {
        v < hi
    }
}

fn address_in_range(addr: &AccountAddress, lo: &BigInt, hi: &BigInt, inclusive_hi: bool) -> bool {
    let v = BigInt::from_bytes_be(Sign::Plus, addr.as_ref());
    in_int_range(&v, lo, hi, inclusive_hi)
}

// ---------------------------------------------------------------------------
// Numeric helpers
// ---------------------------------------------------------------------------

fn uint_modulus(width: UintWidth) -> BigInt {
    match width {
        UintWidth::U8 => BigInt::from(1u64) << 8,
        UintWidth::U16 => BigInt::from(1u64) << 16,
        UintWidth::U32 => BigInt::from(1u64) << 32,
        UintWidth::U64 => BigInt::from(1u128) << 64,
        UintWidth::U128 => BigInt::from(1u128) << 127 << 1,
        UintWidth::U256 => BigInt::from(1u128) << 128 << 128,
    }
}

fn uint_edges(width: UintWidth) -> Vec<BigInt> {
    let m = uint_modulus(width);
    let max = &m - 1;
    let half: BigInt = &m / 2;
    vec![
        BigInt::from(0),
        BigInt::from(1),
        BigInt::from(2),
        &half - 1,
        half.clone(),
        &half + 1,
        &max - 1,
        max,
    ]
}

fn sample_bigint_in_range(rng: &mut Rng, lo: &BigInt, hi: &BigInt, inclusive_hi: bool) -> BigInt {
    let exclusive_hi = if inclusive_hi {
        hi + BigInt::from(1)
    } else {
        hi.clone()
    };
    let span = &exclusive_hi - lo;
    if span <= BigInt::from(0) {
        return lo.clone();
    }
    // Generate a random BigInt 0..span and offset by lo. We approximate with
    // a fixed pool of u64 limbs sufficient for any Move primitive (u256 fits
    // in 4 limbs); a small modulo bias is acceptable for fuzz purposes.
    let mut limbs = Vec::with_capacity(4);
    for _ in 0..4 {
        limbs.push(rng.next_u64());
    }
    let raw = BigInt::from_slice(Sign::Plus, &limbs_to_u32(&limbs));
    lo + raw % span
}

fn limbs_to_u32(u64s: &[u64]) -> Vec<u32> {
    let mut out = Vec::with_capacity(u64s.len() * 2);
    for n in u64s {
        out.push((*n & 0xFFFF_FFFF) as u32);
        out.push((*n >> 32) as u32);
    }
    out
}

/// Draw a (uniform-ish) random `BigInt` in `[0, modulus)` for any Move uint
/// width. Generates one extra limb beyond the modulus width before reducing,
/// so the high end of wide types (u128 max, the upper 128 bits of u256) is
/// reachable; a small modulo bias is acceptable for fuzzing.
fn random_bigint_below(rng: &mut Rng, modulus: &BigInt) -> BigInt {
    if modulus <= &BigInt::from(1) {
        return BigInt::from(0);
    }
    // Bits in `modulus`; one extra 64-bit limb makes the reduction bias
    // negligible across the whole range.
    let limbs = ((modulus.bits() / 64) + 1).max(1) as usize;
    let mut words = Vec::with_capacity(limbs);
    for _ in 0..limbs {
        words.push(rng.next_u64());
    }
    let raw = BigInt::from_slice(Sign::Plus, &limbs_to_u32(&words));
    raw % modulus
}

// ---------------------------------------------------------------------------
// Shrinking — Topic 3
// ---------------------------------------------------------------------------

/// Produce one shrink candidate closer to "minimal" than `current`. Order is
/// deterministic: zero first, then halving, then decrement. The runner calls
/// this in a loop and stops when the shrunk value either passes the test or
/// when this returns `None`.
fn shrink_value(
    ty: &Type,
    current: &MoveValue,
    domain: &Domain,
    exclude: &Domain,
) -> Option<MoveValue> {
    let kind = prim_kind(ty)?;
    let dom_lits;
    let dom_ranges;
    let exc_lits;
    let exc_ranges;
    let domain_active;

    match kind {
        PrimKind::Uint(width) => {
            dom_lits = domain
                .literals
                .iter()
                .filter_map(extract_bigint)
                .collect::<Vec<_>>();
            dom_ranges = parse_int_ranges(&domain.ranges);
            exc_lits = exclude
                .literals
                .iter()
                .filter_map(extract_bigint)
                .collect::<Vec<_>>();
            exc_ranges = parse_int_ranges(&exclude.ranges);
            domain_active = !dom_lits.is_empty() || !dom_ranges.is_empty();
            let cur = move_value_to_bigint(current)?;
            // Build candidates in order from "most aggressive shrink" to least.
            let candidates: Vec<BigInt> = vec![
                BigInt::from(0),
                &cur / 2,
                &cur - 1,
            ];
            for c in candidates {
                if c == cur {
                    continue;
                }
                if c < BigInt::from(0) {
                    continue;
                }
                let in_dom = !domain_active
                    || dom_lits.contains(&c)
                    || dom_ranges
                        .iter()
                        .any(|(lo, hi, inc)| in_int_range(&c, lo, hi, *inc));
                let excluded = exc_lits.contains(&c)
                    || exc_ranges
                        .iter()
                        .any(|(lo, hi, inc)| in_int_range(&c, lo, hi, *inc));
                if in_dom && !excluded {
                    return bigint_to_move_value(c, width);
                }
            }
            None
        },
        PrimKind::Bool => match current {
            MoveValue::Bool(true) => {
                let exc: Vec<bool> = exclude.literals.iter().filter_map(extract_bool).collect();
                let dom: Vec<bool> = domain.literals.iter().filter_map(extract_bool).collect();
                let domain_active = !dom.is_empty();
                let in_dom = !domain_active || dom.contains(&false);
                if in_dom && !exc.contains(&false) {
                    Some(MoveValue::Bool(false))
                } else {
                    None
                }
            },
            _ => None,
        },
        PrimKind::AddressLike(kind) => {
            let cur = match current {
                MoveValue::Address(a) | MoveValue::Signer(a) => *a,
                _ => return None,
            };
            let dom_addrs: Vec<AccountAddress> = domain
                .literals
                .iter()
                .filter_map(extract_address)
                .collect();
            let exc_addrs: Vec<AccountAddress> = exclude
                .literals
                .iter()
                .filter_map(extract_address)
                .collect();
            let dom_ranges = parse_address_ranges(&domain.ranges);
            let exc_ranges = parse_address_ranges(&exclude.ranges);
            let domain_active = !dom_addrs.is_empty() || !dom_ranges.is_empty();
            // Address "shrink" candidates: 0x0, 0x1, and any domain-literal that's "smaller".
            let mut candidates = vec![AccountAddress::ZERO, AccountAddress::ONE];
            for a in &dom_addrs {
                if a.as_ref() < cur.as_ref() {
                    candidates.push(*a);
                }
            }
            for c in candidates {
                if c == cur {
                    continue;
                }
                let in_dom = !domain_active
                    || dom_addrs.contains(&c)
                    || dom_ranges
                        .iter()
                        .any(|(lo, hi, inc)| address_in_range(&c, lo, hi, *inc));
                let excluded = exc_addrs.contains(&c)
                    || exc_ranges
                        .iter()
                        .any(|(lo, hi, inc)| address_in_range(&c, lo, hi, *inc));
                if in_dom && !excluded {
                    return Some(match kind {
                        AddressLike::Address => MoveValue::Address(c),
                        AddressLike::Signer => MoveValue::Signer(c),
                    });
                }
            }
            None
        },
    }
}

fn move_value_to_bigint(v: &MoveValue) -> Option<BigInt> {
    match v {
        MoveValue::U8(x) => Some(BigInt::from(*x)),
        MoveValue::U16(x) => Some(BigInt::from(*x)),
        MoveValue::U32(x) => Some(BigInt::from(*x)),
        MoveValue::U64(x) => Some(BigInt::from(*x)),
        MoveValue::U128(x) => Some(BigInt::from(*x)),
        MoveValue::U256(x) => {
            // u256::U256 → big-endian bytes → BigInt
            let bytes_le = x.to_le_bytes();
            let mut bytes_be = bytes_le;
            bytes_be.reverse();
            Some(BigInt::from_bytes_be(Sign::Plus, &bytes_be))
        },
        _ => None,
    }
}

// ---------------------------------------------------------------------------
// Mutation — Topic 2 (corpus-driven exploration)
// ---------------------------------------------------------------------------

/// Produce one mutated value near `current`. Mirrors Foundry's
/// `mutate_param_value` at `crates/evm/fuzz/src/strategies/param.rs`: bit
/// flips on the low byte, increment/decrement, swap from the dictionary,
/// or pick a domain literal. Result must satisfy the original constraints.
fn mutate_value(
    rng: &mut Rng,
    ty: &Type,
    current: &MoveValue,
    domain: &Domain,
    exclude: &Domain,
    dict: &FuzzDictionary,
) -> Option<MoveValue> {
    let kind = prim_kind(ty)?;
    match kind {
        PrimKind::Uint(width) => {
            let cur = move_value_to_bigint(current)?;
            let m = uint_modulus(width);
            let choice = rng.next_u64() % 5;
            let cand = match choice {
                0 => &cur + 1,
                1 => (&cur + &m - 1) % &m, // decrement with wraparound
                2 => cur.clone() ^ BigInt::from(rng.next_u64() & 0xFF),
                3 => {
                    if let Some(d) = rng.pick(&dict.uints) {
                        d.clone()
                    } else {
                        &cur ^ BigInt::from(1)
                    }
                },
                _ => {
                    let lits: Vec<BigInt> =
                        domain.literals.iter().filter_map(extract_bigint).collect();
                    rng.pick(&lits).cloned().unwrap_or(cur.clone())
                },
            };
            let cand = ((&cand % &m) + &m) % &m;
            if cand == cur {
                return None;
            }
            // Domain/exclude filter.
            let dom_lits: Vec<BigInt> =
                domain.literals.iter().filter_map(extract_bigint).collect();
            let dom_ranges = parse_int_ranges(&domain.ranges);
            let exc_lits: Vec<BigInt> =
                exclude.literals.iter().filter_map(extract_bigint).collect();
            let exc_ranges = parse_int_ranges(&exclude.ranges);
            let active = !dom_lits.is_empty() || !dom_ranges.is_empty();
            let in_dom = !active
                || dom_lits.contains(&cand)
                || dom_ranges
                    .iter()
                    .any(|(lo, hi, inc)| in_int_range(&cand, lo, hi, *inc));
            let excluded = exc_lits.contains(&cand)
                || exc_ranges
                    .iter()
                    .any(|(lo, hi, inc)| in_int_range(&cand, lo, hi, *inc));
            if in_dom && !excluded {
                bigint_to_move_value(cand, width)
            } else {
                None
            }
        },
        PrimKind::Bool => match current {
            MoveValue::Bool(b) => {
                let flipped = !*b;
                let exc: Vec<bool> =
                    exclude.literals.iter().filter_map(extract_bool).collect();
                let dom: Vec<bool> = domain.literals.iter().filter_map(extract_bool).collect();
                let active = !dom.is_empty();
                let in_dom = !active || dom.contains(&flipped);
                if in_dom && !exc.contains(&flipped) {
                    Some(MoveValue::Bool(flipped))
                } else {
                    None
                }
            },
            _ => None,
        },
        PrimKind::AddressLike(kind) => {
            let cur = match current {
                MoveValue::Address(a) | MoveValue::Signer(a) => *a,
                _ => return None,
            };
            let choice = rng.next_u64() % 3;
            let cand = match choice {
                0 => *rng.pick(&dict.addresses).unwrap_or(&AccountAddress::ZERO),
                1 => {
                    // Bit flip in the low byte.
                    let mut bytes = cur.into_bytes();
                    let last = bytes.len() - 1;
                    bytes[last] ^= 1;
                    AccountAddress::new(bytes)
                },
                _ => {
                    let lits: Vec<AccountAddress> = domain
                        .literals
                        .iter()
                        .filter_map(extract_address)
                        .collect();
                    *rng.pick(&lits).unwrap_or(&cur)
                },
            };
            if cand == cur {
                return None;
            }
            let dom_addrs: Vec<AccountAddress> = domain
                .literals
                .iter()
                .filter_map(extract_address)
                .collect();
            let exc_addrs: Vec<AccountAddress> = exclude
                .literals
                .iter()
                .filter_map(extract_address)
                .collect();
            let dom_ranges = parse_address_ranges(&domain.ranges);
            let exc_ranges = parse_address_ranges(&exclude.ranges);
            let active = !dom_addrs.is_empty() || !dom_ranges.is_empty();
            let in_dom = !active
                || dom_addrs.contains(&cand)
                || dom_ranges
                    .iter()
                    .any(|(lo, hi, inc)| address_in_range(&cand, lo, hi, *inc));
            let excluded = exc_addrs.contains(&cand)
                || exc_ranges
                    .iter()
                    .any(|(lo, hi, inc)| address_in_range(&cand, lo, hi, *inc));
            if in_dom && !excluded {
                Some(match kind {
                    AddressLike::Address => MoveValue::Address(cand),
                    AddressLike::Signer => MoveValue::Signer(cand),
                })
            } else {
                None
            }
        },
    }
}

fn bigint_to_move_value(n: BigInt, width: UintWidth) -> Option<MoveValue> {
    let m = uint_modulus(width);
    let n = ((&n % &m) + &m) % &m;
    match width {
        UintWidth::U8 => n.to_u64().map(|x| MoveValue::U8(x as u8)),
        UintWidth::U16 => n.to_u64().map(|x| MoveValue::U16(x as u16)),
        UintWidth::U32 => n.to_u64().map(|x| MoveValue::U32(x as u32)),
        UintWidth::U64 => n.to_u64().map(MoveValue::U64),
        UintWidth::U128 => n.to_u128().map(MoveValue::U128),
        UintWidth::U256 => {
            // Take the low 32 bytes (big-endian) of `n`.
            let (_sign, bytes_be) = n.to_bytes_be();
            let mut buf = [0u8; 32];
            let off = 32usize.saturating_sub(bytes_be.len());
            buf[off..].copy_from_slice(&bytes_be[bytes_be.len().saturating_sub(32)..]);
            // u256::U256 has a `from_be_bytes`/`from_le_bytes` API; use whichever is present.
            Some(MoveValue::U256(u256::U256::from_le_bytes(&{
                let mut le = buf;
                le.reverse();
                le
            })))
        },
    }
}
