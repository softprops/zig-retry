<h1 align="center">
    ♻️ zig retry
</h1>

<div align="center">
    A retry library for fault tolerant zig applications
</div>

---

[![Main](https://github.com/softprops/zig-retry/actions/workflows/ci.yml/badge.svg)](https://github.com/softprops/zig-retry/actions/workflows/ci.yml) ![License Info](https://img.shields.io/github/license/softprops/zig-retry) ![Release](https://img.shields.io/github/v/release/softprops/zig-retry) [![Zig Support](https://img.shields.io/badge/zig-0.13.0-black?logo=zig)](https://ziglang.org/documentation/0.13.0/)

A goal of any operation should be a successful outcome. This package gives operations a better chance at achieving that.

## 📼 installing

Create a new exec project with `zig init`. Copy an example from the examples directory into your into `src/main.zig`

Create a `build.zig.zon` file to declare a dependency

> .zon short for "zig object notation" files are essentially zig structs. `build.zig.zon` is zigs native package manager convention for where to declare dependencies

Starting in zig 0.12.0, you can use and should prefer

```sh
zig fetch --save https://github.com/softprops/zig-retry/archive/refs/tags/v0.1.0.tar.gz
```

otherwise, to manually add it, do so as follows

```diff
.{
    .name = "my-app",
    .version = "0.1.0",
    .dependencies = .{
+       // 👇 declare dep properties
+        .jwt = .{
+            // 👇 uri to download
+            .url = "https://github.com/softprops/zig-retry/archive/refs/tags/v0.1.0.tar.gz",
+            // 👇 hash verification
+            .hash = "...",
+        },
    },
}
```

> the hash below may vary. you can also depend any tag with `https://github.com/softprops/zig-retry/archive/refs/tags/v{version}.tar.gz` or current main with `https://github.com/softprops/zig-retry/archive/refs/heads/main/main.tar.gz`. to resolve a hash omit it and let zig tell you the expected value.

Add the following in your `build.zig` file

```diff
const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});

    const optimize = b.standardOptimizeOption(.{});
    // 👇 de-reference dep from build.zig.zon
+    const retry = b.dependency("retry", .{
+        .target = target,
+        .optimize = optimize,
+    }).module("retry");
    var exe = b.addExecutable(.{
        .name = "your-exe",
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });
    // 👇 add the module to executable
+    exe.root_mode.addImport("retry", retry);

    b.installArtifact(exe);
}
```

## examples

See examples directory

## 🥹 for budding ziglings

Does this look interesting but you're new to zig and feel left out? No problem, zig is young so most us of our new are as well. Here are some resources to help get you up to speed on zig

- [the official zig website](https://ziglang.org/)
- [zig's one-page language documentation](https://ziglang.org/documentation/0.13.0/)
- [ziglearn](https://ziglearn.org/)
- [ziglings exercises](https://github.com/ratfactor/ziglings)


\- softprops 2024
