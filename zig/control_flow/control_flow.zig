const std = @import("std");

pub const ControlStatus = enum(u32) {
    ok = 0,
    invalid_transition = 1,
    bad_signature = 2,
    unexpected_terminal = 3,

    pub fn passed(self: ControlStatus) bool {
        return self == .ok;
    }

    pub fn code(self: ControlStatus) u32 {
        return @intFromEnum(self);
    }
};

pub const Phase = enum(u32) {
    start = 0,
    read_input = 1,
    compute = 2,
    validate = 3,
    commit = 4,
    done = 5,

    pub fn code(self: Phase) u32 {
        return @intFromEnum(self);
    }
};

pub const Monitor = extern struct {
    phase: u32,
    signature: u32,
    transitions: u32,

    const Self = @This();

    pub fn init() Self {
        return .{
            .phase = @intFromEnum(Phase.start),
            .signature = phaseSignature(.start),
            .transitions = 0,
        };
    }

    pub fn validateCurrent(self: *const Self, expected_phase: Phase) ControlStatus {
        if (self.phase != @intFromEnum(expected_phase)) {
            return .invalid_transition;
        }
        if (self.signature != phaseSignature(expected_phase)) {
            return .bad_signature;
        }
        return .ok;
    }

    pub fn advance(self: *Self, expected_from: Phase, next_phase: Phase) ControlStatus {
        const current_status = self.validateCurrent(expected_from);
        if (!current_status.passed()) {
            return current_status;
        }

        self.phase = @intFromEnum(next_phase);
        self.signature = phaseSignature(next_phase);
        self.transitions +%= 1;
        return .ok;
    }

    pub fn finish(self: *const Self) ControlStatus {
        if (self.phase != @intFromEnum(Phase.done)) {
            return .unexpected_terminal;
        }
        if (self.signature != phaseSignature(.done)) {
            return .bad_signature;
        }
        return .ok;
    }
};

pub fn phaseSignature(phase: Phase) u32 {
    const raw = @intFromEnum(phase);
    var signature: u32 = 0xc0def00d;

    signature ^= raw *% 0x9e3779b9;
    signature = std.math.rotl(u32, signature, @as(u5, @intCast((raw % 13) + 3)));
    signature ^= 0xa5a50000 | raw;
    return signature;
}

test "control flow: status codes are stable ABI values" {
    try std.testing.expectEqual(@as(u32, 0), ControlStatus.ok.code());
    try std.testing.expectEqual(@as(u32, 1), ControlStatus.invalid_transition.code());
    try std.testing.expectEqual(@as(u32, 2), ControlStatus.bad_signature.code());
    try std.testing.expectEqual(@as(u32, 3), ControlStatus.unexpected_terminal.code());
}

test "control flow: phase codes are stable ABI values" {
    try std.testing.expectEqual(@as(u32, 0), Phase.start.code());
    try std.testing.expectEqual(@as(u32, 1), Phase.read_input.code());
    try std.testing.expectEqual(@as(u32, 2), Phase.compute.code());
    try std.testing.expectEqual(@as(u32, 3), Phase.validate.code());
    try std.testing.expectEqual(@as(u32, 4), Phase.commit.code());
    try std.testing.expectEqual(@as(u32, 5), Phase.done.code());
}

test "control flow: legal sequence reaches done" {
    var monitor = Monitor.init();

    try std.testing.expectEqual(ControlStatus.ok, monitor.advance(.start, .read_input));
    try std.testing.expectEqual(ControlStatus.ok, monitor.advance(.read_input, .compute));
    try std.testing.expectEqual(ControlStatus.ok, monitor.advance(.compute, .validate));
    try std.testing.expectEqual(ControlStatus.ok, monitor.advance(.validate, .commit));
    try std.testing.expectEqual(ControlStatus.ok, monitor.advance(.commit, .done));

    try std.testing.expectEqual(ControlStatus.ok, monitor.finish());
    try std.testing.expectEqual(@intFromEnum(Phase.done), monitor.phase);
    try std.testing.expectEqual(@as(u32, 5), monitor.transitions);
}

test "control flow: corrupted phase is invalid transition" {
    var monitor = Monitor.init();

    try std.testing.expectEqual(ControlStatus.ok, monitor.advance(.start, .read_input));
    monitor.phase = @intFromEnum(Phase.commit);

    try std.testing.expectEqual(
        ControlStatus.invalid_transition,
        monitor.advance(.read_input, .compute),
    );
}

test "control flow: corrupted signature is bad signature" {
    var monitor = Monitor.init();

    monitor.signature ^= 0x10;

    try std.testing.expectEqual(
        ControlStatus.bad_signature,
        monitor.advance(.start, .read_input),
    );
}

test "control flow: skipped phase is invalid transition" {
    var monitor = Monitor.init();

    try std.testing.expectEqual(ControlStatus.ok, monitor.advance(.start, .read_input));
    try std.testing.expectEqual(
        ControlStatus.invalid_transition,
        monitor.advance(.compute, .validate),
    );
}

test "control flow: repeated phase is invalid transition" {
    var monitor = Monitor.init();

    try std.testing.expectEqual(ControlStatus.ok, monitor.advance(.start, .read_input));
    try std.testing.expectEqual(
        ControlStatus.invalid_transition,
        monitor.advance(.start, .read_input),
    );
}

test "control flow: unexpected terminal and done signature corruption" {
    var monitor = Monitor.init();

    try std.testing.expectEqual(ControlStatus.ok, monitor.advance(.start, .read_input));
    try std.testing.expectEqual(ControlStatus.unexpected_terminal, monitor.finish());

    monitor.phase = @intFromEnum(Phase.done);
    monitor.signature = phaseSignature(.start);
    try std.testing.expectEqual(ControlStatus.bad_signature, monitor.finish());
}
