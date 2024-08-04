//! failable doesn't always translate to `ErrorUnion`. sometimes it just translates
//! to unexpected which can be represented with plain values. `retryIf` with a `Condition` allows you
//! to define what unexpected means for your operations as a user defined function
const std = @import("std");
const retry = @import("retry");

const Counter = struct {
    value: usize = 0,
    fn incr(self: *@This()) usize {
        self.value += 1;
        return self.value;
    }
};

pub fn main() !void {
    // 👇 create a new policy with default values
    const policy: retry.Policy = .{};
    var counter = Counter{};
    // 👇 attempt an operation which increments a counter
    const result = policy.retryIf(
        struct {
            fn func(c: *Counter) usize {
                return c.incr();
            }
        }.func,
        // 👇 arguments to pass to operation
        .{&counter},
        // 👇 user defined condition, when evals to true operation will be retried
        retry.Condition(usize).func(struct {
            fn func(value: usize) bool {
                return value < 3;
            }
        }.func),
    );
    std.debug.print("result {d}\n", .{result});
}
