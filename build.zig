const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const sea_of_thieves = b.addModule("sea_of_thieves", .{
        .root_source_file = b.path("src/sea_of_thieves/sot.zig"),
    });

    const raylib = b.dependency("raylib", .{
        .target = target,
        .optimize = optimize,
    });

    const map = b.addExecutable(.{
        .name = "sot_map",
        .root_source_file = b.path("src/map/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    map.root_module.addImport("sea_of_thieves", sea_of_thieves);
    map.linkLibrary(raylib.artifact("raylib"));
    map.addIncludePath(raylib.path("src/"));

    const extractor = b.addExecutable(.{
        .name = "sot_extractor",
        .root_source_file = b.path("src/extractor/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    extractor.root_module.addImport("sea_of_thieves", sea_of_thieves);

    b.installArtifact(map);
    b.installArtifact(extractor);
}
