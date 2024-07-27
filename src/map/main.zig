const std = @import("std");
const sot = @import("sea_of_thieves");
const Map = @import("Map.zig");
const ray = @import("raylib.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    const allocator = gpa.allocator();

    const parsed = try std.json.parseFromSlice(
        []sot.Island,
        allocator,
        @embedFile("./assets/islands.json"),
        .{},
    );
    defer parsed.deinit();
    const islands = parsed.value;

    ray.SetConfigFlags(ray.FLAG_WINDOW_RESIZABLE);
    ray.InitWindow(800, 800, "Sea of Thieves Minimap");
    defer ray.CloseWindow();

    ray.SetTargetFPS(60);

    var camera = ray.Camera2D{
        .zoom = 1,
    };
    camera.zoom = 2;

    var crews = std.ArrayList(sot.Crew).init(allocator);
    defer crews.deinit();

    try crews.append(.{
        .ship_type = .sloop,
        .ship_name = "ok",
        .players = 2,
        .x = 5,
        .y = 20,
    });

    try crews.append(.{
        .ship_type = .galleon,
        .ship_name = "ok",
        .players = 2,
        .x = 5,
        .y = 20,
    });

    var map = Map{
        .islands = islands,
        .crews = crews,
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
