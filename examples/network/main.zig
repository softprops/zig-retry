//! When dialing into a network server you aren't always guaranteed a response for a number of reasons.
//! To be fault-tolerant, its a best practice to retry, idempotent network requests
//!
//! This program will retrie attempt to fetch data from an an http server listening on port 3000.
//!
//! Run an http server listening on port 3000, `python3 -m http.server 3000` for example, in another tab to complete the program
const std = @import("std");
const retry = @import("retry");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // 👇 create a new policy
    const policy = retry.Policy.fixed(1 * std.time.ns_per_s).withMaxRetries(1000);

    var client = std.http.Client{ .allocator = allocator };
    defer client.deinit();
    const url = "http://localhost:3000";

    // 👇 retry operation until successful state presents itself
    const resp = try policy.retry(
        struct {
            fn func(c: *std.http.Client) anyerror!std.http.Client.FetchResult {
                std.debug.print("attempting to fetch {s}\n", .{url});
                return c.fetch(.{ .location = .{ .url = url } });
            }
        }.func,
        // 👇 arguments to pass to operation
        .{&client},
    );
    std.debug.print("got response {}", .{resp.status});
}
