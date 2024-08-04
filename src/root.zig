const std = @import("std");
const testing = std.testing;

var Rand = std.rand.DefaultPrng.init(0);

/// Determines of an optional should be retried based on the the value
/// of a result
pub fn Condition(comptime T: type) type {
    return union(enum) {
        on_err: void,
        func: *const fn (T) bool,

        /// Retries on any error of an error union result
        pub fn onErr() @This() {
            switch (@typeInfo(T)) {
                .ErrorUnion => {},
                else => @compileError(
                    "onErr conditions assume ErrorUnion return types. Provided with a " ++ @typeName(T) ++ " type instead",
                ),
            }
            return .{ .on_err = {} };
        }

        /// Retries depending on the result of a user defined func
        pub fn func(f: *const fn (T) bool) @This() {
            return .{ .func = f };
        }

        /// returns true if a value indicates an operation to be retried
        fn retryable(self: @This(), val: T) bool {
            return switch (self) {
                .on_err => switch (@typeInfo(T)) {
                    .ErrorUnion => if (val) |_| false else |_| true,
                    else => false,
                },
                .func => |v| v(val),
            };
        }
    };
}

test Condition {
    const onErr = Condition(anyerror!void).onErr();
    try std.testing.expect(onErr.retryable(error.FAIL));
    try std.testing.expect(!onErr.retryable({}));

    const func = Condition(usize).func(struct {
        fn func(n: usize) bool {
            return n < 1;
        }
    }.func);
    try std.testing.expect(func.retryable(0));
    try std.testing.expect(!func.retryable(1));
}

/// Types of backoffs, a sequence of delays between operation invocations
pub const Backoff = union(enum) {
    fixed: void,
    exponential: f64,

    fn fixed() @This() {
        return .{ .fixed = {} };
    }

    fn exponential(exponent: f64) @This() {
        return .{ .exponential = exponent };
    }

    pub fn iterator(self: @This(), policy: Policy) Iterator {
        return .{ .policy = policy, .backoff = self };
    }

    pub const Iterator = struct {
        policy: Policy,
        backoff: Backoff,
        current: f64 = 1,
        fn next(self: *@This()) ?usize {
            if (self.policy.max_retries > 0) {
                const factor: f64 = switch (self.backoff) {
                    .fixed => self.current,
                    .exponential => |v| blk: {
                        const fac = self.current;
                        const next_factor = self.current * v;
                        self.current = next_factor;
                        break :blk fac;
                    },
                };

                var delay: usize = @intFromFloat(factor * @as(f64, @floatFromInt(self.policy.delay)));
                if (self.policy.jitter) |rand| {
                    delay = @intFromFloat(rand.float(f64) * @as(f64, @floatFromInt(delay)));
                }
                if (self.policy.max_delay) |max| {
                    delay = @min(delay, max);
                }
                self.policy.max_retries -= 1;
                return delay;
            }
            return null;
        }
    };
};

/// A Policy captures rules that define the expected behavior
/// of a retry including number of times to retry and frequency
///
/// The defaults settings include exponential backoff with 2.0 exponent, no max delay, max retries of 5
pub const Policy = struct {
    /// type of backoff delay, defaults to Backoff
    backoff: Backoff = Backoff.exponential(2.0),
    /// random used to produce a "jitter" effect. defaults to std.rand.DefaultPrng
    jitter: ?std.Random = Rand.random(),
    /// delay in nanoseconds, defaults to 100ms in nanos
    delay: usize = std.time.ns_per_ms * 100,
    /// upper bound for amount of delay applied, in nanoseconds
    max_delay: ?usize = null,
    /// upper bound for number of times to retry an operation
    max_retries: usize = 5,

    /// Conventice for common configuration. Returns a new Policy with defaults with a fixed delay (no jitter)
    pub fn fixed(delay: usize) @This() {
        return .{
            .backoff = Backoff.fixed(),
            .delay = delay,
            .jitter = null,
        };
    }

    /// Conventice for common configuration. Returns a new Policy with defaults with an exponential delay
    fn exponential(delay: usize, exponent: f64) @This() {
        return .{
            .backoff = Backoff.exponential(exponent),
            .delay = delay,
        };
    }

    pub fn withMaxRetries(self: @This(), max: usize) @This() {
        var c = self;
        c.max_retries = max;
        return c;
    }

    /// Returns an iterator of backoff delays
    pub fn backoffs(self: @This()) Backoff.Iterator {
        return self.backoff.iterator(self);
    }

    /// Retries an operation if it fails, where "fail" means
    /// the function returns an ErrorUnion containing an error
    ///
    /// The provided function is assumed to be a function returning
    /// and ErrorUnion
    pub fn retry(
        self: @This(),
        comptime f: anytype,
        args: anytype,
    ) returnType(f) {
        return self.retryIf(f, args, Condition(returnType(f)).onErr());
    }

    /// retries an operation based on a user defined function
    pub fn retryIf(
        self: *const @This(),
        comptime f: anytype,
        args: anytype,
        cond: Condition(returnType(f)),
    ) returnType(f) {
        var iter = self.backoffs();
        while (true) {
            const result = @call(.auto, f, args);
            if (cond.retryable(result)) {
                if (iter.next()) |delay| {
                    std.time.sleep(delay);
                    continue;
                }
            }
            return result;
        }
    }
};

fn returnType(comptime f: anytype) type {
    const msg = "expected a function with a return type";
    return switch (@typeInfo(@TypeOf(f))) {
        .Fn => |info| info.return_type orelse {
            @compileError(msg);
        },
        else => @compileError(msg),
    };
}

test "Policy.backoffs" {
    for ([_]struct {
        name: []const u8,
        policy: Policy,
        expected: []const usize,
    }{
        .{
            .name = "fixed",
            .policy = Policy.fixed(1),
            .expected = &.{ 1, 1, 1, 1 },
        },
        .{
            .name = "exponential (without jitter)",
            .policy = Policy{
                .backoff = Backoff.exponential(2.0),
                .delay = 1,
                .jitter = null,
            },
            .expected = &.{ 1, 2, 4, 8 },
        },
    }) |case| {
        var it = case.policy.backoffs();
        for (case.expected) |exp| {
            std.testing.expectEqual(exp, it.next().?) catch |err| {
                std.debug.print("{s} err {} given value {d} \n", .{ case.name, err, exp });
                return err;
            };
        }
    }
}

test "Policy reuse" {
    const policy: Policy = .{};

    try std.testing.expectError(
        error.FAIL,
        policy.retry(struct {
            fn func() error{FAIL}!void {
                return error.FAIL;
            }
        }.func, .{}),
    );

    try std.testing.expectError(
        error.FAIL,
        policy.retry(struct {
            fn func() error{FAIL}!void {
                return error.FAIL;
            }
        }.func, .{}),
    );

    // we expect that a policy used once doesn't impact the same policy instance
    // from being reused multiple times
    try std.testing.expectEqual(policy.max_retries, (Policy{}).max_retries);
}
