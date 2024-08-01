const std = @import("std");
const sot = @import("sea_of_thieves");
const ray = @import("raylib.zig");
const Self = @This();

islands: []sot.Island,
crews: std.ArrayList(sot.Crew),
min_x: f32 = -2_000,
max_x: f32 = 2_000,
min_y: f32 = -2_000,
max_y: f32 = 2_000,
camera: ray.Camera2D = .{
    .zoom = 1,
},
water_color: ray.Color = .{
    .r = 0x57,
    .g = 0xb9,
    .b = 0xec,
    .a = 0xff,
},

pub fn update(self: *Self) void {
    if (ray.IsMouseButtonDown(ray.MOUSE_BUTTON_LEFT)) {
        var mouse_delta = ray.GetMouseDelta();
        mouse_delta = ray.Vector2Scale(mouse_delta, -1 / self.camera.zoom);
        self.camera.target = ray.Vector2Add(self.camera.target, mouse_delta);
        self.clampCamera();
    }

    const wheel_delta = ray.GetMouseWheelMove();
    if (wheel_delta != 0) {
        const mouse_pos = ray.GetMousePosition();
        const mouse_world_pos = ray.GetScreenToWorld2D(mouse_pos, self.camera);

        self.camera.offset = mouse_pos;
        self.camera.target = mouse_world_pos;
        self.clampCamera();

        var scale_factor = 1 + (0.25 * ray.fabsf(wheel_delta));
        if (wheel_delta < 0) scale_factor = 1 / scale_factor;
        self.camera.zoom = ray.Clamp(self.camera.zoom * scale_factor, 0.125, 64);
    }
}

fn clampCamera(self: *Self) void {
    self.camera.target.x = ray.Clamp(self.camera.target.x, self.min_x, self.max_x);
    self.camera.target.y = ray.Clamp(self.camera.target.y, self.min_y, self.max_y);
}

pub fn draw(self: *Self) void {
    self.drawIslands();
    self.drawCrews();
}

fn drawIslands(self: *Self) void {
    ray.BeginMode2D(self.camera);
    defer ray.EndMode2D();

    ray.ClearBackground(self.water_color);

    var name_buffer: [1024]u8 = undefined;
    const font_size: f32 = 20 / self.camera.zoom;
    const text_spacing: f32 = 2 / self.camera.zoom;

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

        const x = island.x / 200;
        const y = island.y / 200;

        // TODO: Draw the texture here
        ray.DrawCircleV(
            .{
                .x = x,
                .y = y,
            },
            30,
            ray.GRAY,
        );

        ray.DrawTextEx(
            ray.GetFontDefault(),
            @ptrCast(name),
            .{
                .x = x - (label_size.x / 2),
                .y = y - (label_size.y / 2),
            },
            font_size,
            text_spacing,
            ray.BLACK,
        );
    }
}

fn drawCrews(self: *Self) void {
    const font_size: c_int = 20;

    const x: c_int = 10;
    var y: c_int = 10;

    ray.DrawText("Crews:", x, y, font_size, ray.BLACK);
    y += font_size + 5;

    for (self.crews.items) |crew| {
        const name = switch (crew.ship_type) {
            .sloop => "sloop",
            .brigantine => "brigantine",
            .galleon => "galleon",
        };

        ray.DrawText(name, x, y, font_size, ray.BLACK);
        y += font_size + 5;
    }
}
