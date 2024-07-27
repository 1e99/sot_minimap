const std = @import("std");
const sot = @import("sea_of_thieves");
const ray = @import("raylib.zig");
const Self = @This();

islands: []sot.Island,
camera: ray.Camera2D = .{
    .zoom = 1,
},

pub fn update(self: *Self) void {
    if (ray.IsMouseButtonDown(ray.MOUSE_BUTTON_LEFT)) {
        var mouse_delta = ray.GetMouseDelta();
        mouse_delta = ray.Vector2Scale(mouse_delta, -1 / self.camera.zoom);
        self.camera.target = ray.Vector2Add(self.camera.target, mouse_delta);
    }

    const wheel_delta = ray.GetMouseWheelMove();
    if (wheel_delta != 0) {
        const mouse_pos = ray.GetMousePosition();
        const mouse_world_pos = ray.GetScreenToWorld2D(mouse_pos, self.camera);

        self.camera.offset = mouse_pos;
        self.camera.target = mouse_world_pos;

        var scale_factor = 1 + (0.25 * ray.fabsf(wheel_delta));
        if (wheel_delta < 0) scale_factor = 1 / scale_factor;
        self.camera.zoom = ray.Clamp(self.camera.zoom * scale_factor, 0.125, 64);
    }
}

pub fn draw(self: *Self) void {
    self.drawIslands();
}

fn drawIslands(self: *Self) void {
    ray.BeginMode2D(self.camera);
    defer ray.EndMode2D();

    ray.ClearBackground(ray.BLUE);

    var name_buffer: [1024]u8 = undefined;
    const font_size: f32 = 20;
    const text_spacing: f32 = 2;

    const font = ray.GetFontDefault();

    for (self.islands) |island| {
        const name = std.fmt.bufPrint(
            &name_buffer,
            "{s}\x00",
            .{island.name},
        ) catch "";

        const label_size = ray.MeasureTextEx(
            font,
            @ptrCast(name),
            font_size,
            text_spacing,
        );

        ray.DrawTextEx(
            ray.GetFontDefault(),
            @ptrCast(name),
            .{
                .x = (island.x / 200) - (label_size.x / 2),
                .y = (island.y / 200) - (label_size.y / 2),
            },
            font_size,
            text_spacing,
            ray.BLACK,
        );
    }
}
