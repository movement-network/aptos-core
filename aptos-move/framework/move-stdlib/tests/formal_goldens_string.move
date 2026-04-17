#[test_only]
/// Curated UTF-8 cases for Lean `MovementFormal.Std.String` (`String.fromUTF8?`) alignment.
module std::formal_goldens_string {
    use std::option;
    use std::string;

    #[test]
    fun golden_utf8_empty() {
        let v = vector[];
        let o = string::try_utf8(v);
        assert!(option::is_some(&o), 0);
    }

    #[test]
    fun golden_utf8_ascii_hi() {
        let v = vector[0x48, 0x69];
        let o = string::try_utf8(v);
        assert!(option::is_some(&o), 0);
    }

    #[test]
    fun golden_utf8_rejects_lone_high_byte() {
        let v = vector[0xff];
        let o = string::try_utf8(v);
        assert!(option::is_none(&o), 0);
    }
}
