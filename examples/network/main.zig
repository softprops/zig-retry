const std = @import("std");
const retry = @import("retry");

// run an http server listening on port 3000 i.e. `python3 -m http.server 3000`  in another tab
pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const policy: retry.Policy = .{ .delay = 60 * 1000 * 1000, .max_retries = 1_000 };

    var client = std.http.Client{ .allocator = allocator };
    defer client.deinit();

    _ = try policy.retry(
        struct {
            fn func(c: *std.http.Client) anyerror!std.http.Client.FetchResult {
                const url = "http://localhost:3000";
                std.debug.print("attempting to fetch {s}\n", .{url});
                return c.fetch(.{
                    .location = .{ .url = url },
                });
            }
        }.func,
        .{&client},
    );
}
