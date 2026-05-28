const checker = @import("checker");
const checkpoint = @import("checkpoint");
const fuzz = @import("fuzz_abi.zig");

pub const RecordPtrs = struct {
    tag: *volatile u32,
    value: *volatile u32,
    min: *volatile u32,
    max: *volatile u32,
    length: *volatile u32,
    capacity: *volatile u32,
    checksum: *volatile u32,
};

pub const CheckpointedPtrs = struct {
    active: RecordPtrs,
    saved: RecordPtrs,
};

pub fn loadRecord(p: RecordPtrs) checker.CheckedRecord {
    return .{
        .tag = fuzz.load32(p.tag),
        .value = fuzz.load32(p.value),
        .min = fuzz.load32(p.min),
        .max = fuzz.load32(p.max),
        .length = fuzz.load32(p.length),
        .capacity = fuzz.load32(p.capacity),
        .checksum = fuzz.load32(p.checksum),
    };
}

pub fn mirrorRecord(p: RecordPtrs, r: checker.CheckedRecord) void {
    fuzz.store32(p.tag, r.tag);
    fuzz.store32(p.value, r.value);
    fuzz.store32(p.min, r.min);
    fuzz.store32(p.max, r.max);
    fuzz.store32(p.length, r.length);
    fuzz.store32(p.capacity, r.capacity);
    fuzz.store32(p.checksum, r.checksum);
}

pub fn loadCheckpointed(p: CheckpointedPtrs) checkpoint.CheckpointedRecord {
    return .{
        .active = loadRecord(p.active),
        .checkpoint = loadRecord(p.saved),
    };
}

pub fn mirrorCheckpointed(p: CheckpointedPtrs, state: *const checkpoint.CheckpointedRecord) void {
    mirrorRecord(p.active, state.active);
    mirrorRecord(p.saved, state.checkpoint);
}

pub fn sampleRecord(value: u32) checker.CheckedRecord {
    return checker.CheckedRecord.init(.sample, value, 0, 1000, 6, 16);
}

pub fn sampleInitialValue(rng: *u64) u32 {
    return 100 + (fuzz.randomU32(rng) % 700);
}
