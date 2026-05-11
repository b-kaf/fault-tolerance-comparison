const std = @import("std");

pub const CheckStatus = enum(u32) {
    ok = 0,
    below_min = 1,
    above_max = 2,
    invalid_length = 3,
    invalid_checksum = 4,
    inconsistent_fields = 5,
    invalid_tag = 6,

    pub fn passed(self: CheckStatus) bool {
        return self == .ok;
    }

    pub fn code(self: CheckStatus) u32 {
        return @intFromEnum(self);
    }
};

pub fn passed(status: CheckStatus) bool {
    return status.passed();
}

pub fn requireRangeU32(value: u32, min: u32, max: u32) CheckStatus {
    if (min > max) {
        return .inconsistent_fields;
    }
    if (value < min) {
        return .below_min;
    }
    if (value > max) {
        return .above_max;
    }
    return .ok;
}

pub fn requireLengthU32(length: u32, capacity: u32) CheckStatus {
    if (length > capacity) {
        return .invalid_length;
    }
    return .ok;
}

pub fn requireEqualU32(actual: u32, expected: u32) CheckStatus {
    if (actual != expected) {
        return .inconsistent_fields;
    }
    return .ok;
}

pub fn requireChecksumU32(expected: u32, words: []const u32) CheckStatus {
    if (checksumWordsU32(words) != expected) {
        return .invalid_checksum;
    }
    return .ok;
}

pub fn checksumWordsU32(words: []const u32) u32 {
    var hash: u32 = 0x811c9dc5;

    for (words) |word| {
        hash ^= word;
        hash *%= 0x01000193;
        hash = std.math.rotl(u32, hash, 5);
    }

    return hash;
}

pub const SampleTag = enum(u32) {
    idle = 0,
    sample = 1,
    command = 2,
};

pub fn requireSampleTag(raw: u32) CheckStatus {
    return switch (raw) {
        @intFromEnum(SampleTag.idle),
        @intFromEnum(SampleTag.sample),
        @intFromEnum(SampleTag.command),
        => .ok,
        else => .invalid_tag,
    };
}

pub const CheckedRecord = struct {
    tag: u32,
    value: u32,
    min: u32,
    max: u32,
    length: u32,
    capacity: u32,
    checksum: u32,

    const Self = @This();

    pub fn init(tag: SampleTag, value: u32, min: u32, max: u32, length: u32, capacity: u32) Self {
        var self = Self{
            .tag = @intFromEnum(tag),
            .value = value,
            .min = min,
            .max = max,
            .length = length,
            .capacity = capacity,
            .checksum = 0,
        };
        self.refreshChecksum();
        return self;
    }

    pub fn refreshChecksum(self: *Self) void {
        self.checksum = self.computeChecksum();
    }

    pub fn computeChecksum(self: *const Self) u32 {
        return checksumWordsU32(&.{
            self.tag,
            self.value,
            self.min,
            self.max,
            self.length,
            self.capacity,
        });
    }

    pub fn validate(self: *const Self) CheckStatus {
        const tag_status = requireSampleTag(self.tag);
        if (!tag_status.passed()) {
            return tag_status;
        }

        const range_status = requireRangeU32(self.value, self.min, self.max);
        if (!range_status.passed()) {
            return range_status;
        }

        const length_status = requireLengthU32(self.length, self.capacity);
        if (!length_status.passed()) {
            return length_status;
        }

        return requireChecksumU32(self.checksum, &.{
            self.tag,
            self.value,
            self.min,
            self.max,
            self.length,
            self.capacity,
        });
    }
};

test "checker: status codes are stable ABI values" {
    try std.testing.expectEqual(@as(u32, 0), CheckStatus.ok.code());
    try std.testing.expectEqual(@as(u32, 1), CheckStatus.below_min.code());
    try std.testing.expectEqual(@as(u32, 2), CheckStatus.above_max.code());
    try std.testing.expectEqual(@as(u32, 3), CheckStatus.invalid_length.code());
    try std.testing.expectEqual(@as(u32, 4), CheckStatus.invalid_checksum.code());
    try std.testing.expectEqual(@as(u32, 5), CheckStatus.inconsistent_fields.code());
    try std.testing.expectEqual(@as(u32, 6), CheckStatus.invalid_tag.code());
}

test "checker: range check accepts inclusive bounds" {
    try std.testing.expectEqual(CheckStatus.ok, requireRangeU32(10, 10, 20));
    try std.testing.expectEqual(CheckStatus.ok, requireRangeU32(20, 10, 20));
}

test "checker: range check reports low high and invalid bounds" {
    try std.testing.expectEqual(CheckStatus.below_min, requireRangeU32(9, 10, 20));
    try std.testing.expectEqual(CheckStatus.above_max, requireRangeU32(21, 10, 20));
    try std.testing.expectEqual(CheckStatus.inconsistent_fields, requireRangeU32(10, 20, 10));
}

test "checker: length check rejects length beyond capacity" {
    try std.testing.expectEqual(CheckStatus.ok, requireLengthU32(4, 4));
    try std.testing.expectEqual(CheckStatus.invalid_length, requireLengthU32(5, 4));
}

test "checker: checksum check detects changed words" {
    const words = [_]u32{ 1, 2, 3, 4 };
    const checksum = checksumWordsU32(&words);
    try std.testing.expectEqual(CheckStatus.ok, requireChecksumU32(checksum, &words));

    const changed = [_]u32{ 1, 2, 3, 5 };
    try std.testing.expectEqual(CheckStatus.invalid_checksum, requireChecksumU32(checksum, &changed));
}

test "checker: sample tag check rejects unknown tag values" {
    try std.testing.expectEqual(CheckStatus.ok, requireSampleTag(@intFromEnum(SampleTag.command)));
    try std.testing.expectEqual(CheckStatus.invalid_tag, requireSampleTag(99));
}

test "checker: checked record validates clean state" {
    const record = CheckedRecord.init(.sample, 50, 10, 100, 3, 8);
    try std.testing.expectEqual(CheckStatus.ok, record.validate());
}

test "checker: checked record detects semantic field failures before checksum" {
    var record = CheckedRecord.init(.sample, 50, 10, 100, 3, 8);

    record.value = 101;
    try std.testing.expectEqual(CheckStatus.above_max, record.validate());

    record = CheckedRecord.init(.sample, 50, 10, 100, 9, 8);
    try std.testing.expectEqual(CheckStatus.invalid_length, record.validate());

    record = CheckedRecord.init(.sample, 50, 100, 10, 3, 8);
    try std.testing.expectEqual(CheckStatus.inconsistent_fields, record.validate());
}

test "checker: checked record detects checksum-only corruption" {
    var record = CheckedRecord.init(.sample, 50, 10, 100, 3, 8);
    record.checksum ^= 0x10;
    try std.testing.expectEqual(CheckStatus.invalid_checksum, record.validate());
}

test "checker: checked record can refresh checksum after valid mutation" {
    var record = CheckedRecord.init(.sample, 50, 10, 100, 3, 8);
    record.value = 60;
    try std.testing.expectEqual(CheckStatus.invalid_checksum, record.validate());

    record.refreshChecksum();
    try std.testing.expectEqual(CheckStatus.ok, record.validate());
}
