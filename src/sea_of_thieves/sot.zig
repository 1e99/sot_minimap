pub const Island = @import("Island.zig");
pub const Process = @import("Process.zig");

pub const Position = struct {
    x: f32,
    y: f32,
    z: f32,
    yaw: f32,
    pitch: f32,
};

pub const Region = enum(u8) {
    wilds,
    shores_of_plenty,
    ancient_isles,
    devils_roar,
    sunken_kingdom,
    unknown,
};

pub const ShipType = enum(u8) {
    sloop,
    brigantine,
    galleon,
};

pub const Crew = struct {
    ship_type: ShipType,
    ship_name: ?[]const u8,
    players: u8,
};
