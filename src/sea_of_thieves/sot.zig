pub const Island = @import("Island.zig");
pub const Process = @import("Process.zig");

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
