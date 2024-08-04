const std = @import("std");
const sot = @import("sea_of_thieves");
const Language = @import("Language.zig");
const Map = @import("Map.zig");
const ray = @import("raylib.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    const allocator = gpa.allocator();

    const process_id = try sot.Process.findProcessId() orelse {
        std.log.err("Could not find a Sot process.", .{});
        return;
    };

    std.log.info("Found Sot Process ID: {}", .{process_id});

    var process = try sot.Process.init(allocator, process_id);
    defer process.deinit();

    const parsed = try std.json.parseFromSlice(
        []sot.Island,
        allocator,
        @embedFile("./assets/islands.json"),
        .{},
    );
    defer parsed.deinit();
    const islands = parsed.value;

    var lang = try Language.init(allocator, @embedFile("./assets/lang/en_us.txt"));
    defer lang.deinit();

    ray.SetConfigFlags(ray.FLAG_WINDOW_RESIZABLE);
    ray.InitWindow(800, 800, "Sea of Thieves Minimap");
    defer ray.CloseWindow();

    ray.SetTargetFPS(60);

    var map = Map{
        .islands = islands,
        .process = &process,
        .lang = &lang,
    };

    while (true) {
        if (ray.WindowShouldClose()) {
            break;
        }

        map.update();

        ray.BeginDrawing();
        defer ray.EndDrawing();

        ray.ClearBackground(ray.WHITE);

        map.draw();
    }
}
