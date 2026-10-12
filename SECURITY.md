# Aptos Foundation Bounty Program

The Aptos Foundation welcomes feedback from security researchers and the general public to help improve the security of the Aptos Network, and, at its sole discretion, offers bounty rewards for security reports that identify previously unknown, in-scope security vulnerabilities.

To learn more visit the [Aptos Foundation Bounty Program](https://hackenproof.com/aptos) page.

## Move VM: fail-closed struct and enum field layouts

`MoveStructLayout::fields` and `MoveStructLayout::into_fields` return `Option`.
A missing, inconsistent, or out-of-range `RuntimeVariants` tag is `None`. It is
never an empty field list.

An empty field list is a valid unit variant (`Some(&[])` / `Some(vec![])`).
Substituting `&[]` for an unknown tag lets a caller treat a bad tag as a unit
variant. BCS serialization would then emit bytes that strict deserialization
rejects — a serialize/deserialize asymmetry that can wedge state after an enum
upgrade (a resource that can be written but never read back).

Movement [#411](https://github.com/movement-network/aptos-core/pull/411) closed
that hole on the BCS serialize path by rejecting out-of-range tags in
`try_get_variant_field_layouts`. The layout accessors themselves still returned
an empty slice, so other walkers (`as_move_value`, delayed-field string
recognition) could still treat a bad tag as a unit variant.

Invariant:

- Serialization must not emit an unknown variant tag.
- Every `fields` / `into_fields` caller must handle `None` and must not fall
  back to empty fields.

This change does not enable feature flags 81 or 95.
