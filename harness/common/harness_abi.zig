/// Stable ABI shared with `harness_abi.h` and the Python injector.
/// Numeric values here must match the C header — see comptime asserts in
/// each harness for parity with the technique-specific enums.

pub const stage = struct {
    pub const boot: u32 = 0;
    pub const after_init: u32 = 1;
    pub const before_read: u32 = 2;
    pub const after_read: u32 = 3;
    pub const after_checkpoint: u32 = 4;
    pub const after_mutation: u32 = 5;
    pub const before_commit: u32 = 6;
    pub const after_commit: u32 = 7;
};

pub const fault = struct {
    pub const none: u32 = 0;
    pub const copy_a: u32 = 1;
    pub const all_distinct: u32 = 2;
    pub const active_value: u32 = 10;
    pub const active_length: u32 = 11;
    pub const active_checksum: u32 = 12;
    pub const checkpoint_value: u32 = 13;
    pub const checkpoint_checksum: u32 = 14;
    pub const active_value_and_checkpoint_checksum: u32 = 15;
};

pub const status = struct {
    pub const ok: u32 = 0;
    pub const no_majority: u32 = 1;
};

pub const restart = struct {
    pub const committed: u32 = 0;
    pub const restored: u32 = 1;
    pub const restore_failed: u32 = 2;
};
