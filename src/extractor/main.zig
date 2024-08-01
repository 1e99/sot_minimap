const std = @import("std");
const sot = @import("sea_of_thieves");
const Islands = @import("Islands.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    var arena = std.heap.ArenaAllocator.init(gpa.allocator());
    defer arena.deinit();

    const allocator = arena.allocator();

    const process_id = try sot.Process.findProcessId() orelse {
        std.log.err("Could not find a Sot process.", .{});
        return;
    };

    std.log.info("Found Sot Process ID: {}", .{process_id});

    var process = try sot.Process.init(allocator, process_id);
    defer process.deinit();

    const cwd = std.fs.cwd();

    // TODO: Change permissions so that I don't need sudo to delete it
    const output_dir = try cwd.makeOpenPath(
        "extractor-out",
        .{},
    );

    {
        var islands = Islands{
            .process = &process,
            .allocator = allocator,
            .output_dir = output_dir,
        };

        try islands.extract();
    }
}
