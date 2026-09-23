// `_a = []` is a programmer error: it would produce zero cases for this
// dimension. We report a diagnostic at plan-build time instead of crashing
// the runner with an out-of-bounds index.
module 0x1::M {
    #[test(_a = [])]
    public fun empty_matrix(_a: u64) { }
}
