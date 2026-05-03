const std = @import("std");

pub const TmrError = error{NoMajority};

pub fn Tmr(comptime T: type) type {
    comptime {
        const info = @typeInfo(T);
        _ = switch (info) {
            .int, .float, .bool, .@"enum" => true,
            else => @compileError("Unsupported type, must be scalar with equality support"),
        };
    }

    return struct {
        a: T,
        b: T,
        c: T,
        fault_count: u32,

        const Self = @This();

        pub fn init(val: T) Self {
            return .{
                .a = val,
                .b = val,
                .c = val,
                .fault_count = 0,
            };
        }

        pub fn write(self: *Self, val: T) void {
            self.a = val;
            self.b = val;
            self.c = val;
        }

        /// Majority vote. Returns the agreed value, or TmrError.NoMajority
        /// if all three copies disagree.
        pub fn read(self: *Self) TmrError!T {
            if (self.a == self.b and self.b == self.c) {
                self.fault_count = 0;
                return self.a;
            }

            // Single-fault cases — majority still valid
            if (self.a == self.b) {
                self.fault_count += 1;
                return self.a;
            }
            if (self.a == self.c) {
                self.fault_count += 1;
                return self.a;
            }
            if (self.b == self.c) {
                self.fault_count += 1;
                return self.b;
            }

            // No majority
            self.fault_count += 1;
            return TmrError.NoMajority;
        }

        /// Inject a fault into copy A — for test harness use only.
        pub fn injectFaultA(self: *Self, bad_val: T) void {
            self.a = bad_val;
        }

        /// Inject a fault into all copies — for test harness use only.
        pub fn injectAll(self: *Self, va: T, vb: T, vc: T) void {
            self.a = va;
            self.b = vb;
            self.c = vc;
        }
    };
}

// -----------------------TMR: Tests----------------------
test "Tmr: clean read returns value" {
    var t = Tmr(u32).init(42);
    const val = try t.read();
    try std.testing.expectEqual(@as(u32, 42), val);
}

test "Tmr: single fault — majority wins" {
    var t = Tmr(u32).init(100);
    t.injectFaultA(0xFF);
    const val = try t.read(); // b==c==100, majority wins
    try std.testing.expectEqual(@as(u32, 100), val);
    try std.testing.expectEqual(@as(u32, 1), t.fault_count);
}

test "Tmr: no majority — error returned" {
    var t = Tmr(u32).init(0);
    t.injectAll(1, 2, 3);
    const result = t.read();
    try std.testing.expectError(TmrError.NoMajority, result);
}

test "Tmr: write restores clean state" {
    var t = Tmr(u32).init(0);
    t.injectAll(1, 2, 3);
    t.write(99);
    const val = try t.read();
    try std.testing.expectEqual(@as(u32, 99), val);
}

test "Tmr: works with bool type" {
    var t = Tmr(bool).init(true);
    t.injectFaultA(false);
    const val = try t.read();
    try std.testing.expect(val == true);
}
