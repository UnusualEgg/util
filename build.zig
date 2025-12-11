const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const w4_util = b.addModule("w4_util", .{
        .root_source_file = b.path("src/w4_util.zig"),
        .optimize = optimize,
        .target = target,
    });

    _ = b.addModule("menu", .{
        .root_source_file = b.path("src/menu.zig"),
        .optimize = optimize,
        .target = target,
        .imports = &.{
            .{
                .name = "w4_util",
                .module = w4_util,
            },
        },
    });

    _ = b.addModule("w4_alloc", .{
        .root_source_file = b.path("src/w4_alloc.zig"),
        .target = target,
        .optimize = optimize,
    });
}
