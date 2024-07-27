const sot = @import("sot.zig");
const Self = @This();

pub const Type = enum(u8) {
    normal,
    outpost,
    seapost,
    sea_fort,
    skeleton_fort,
    skeleton_camp,
    fort_of_the_damned,
    reapers_hideout,
    shrine,
    treasury,
    unknown,
};

name: []const u8,
type: Type,
region: sot.Region,
x: f32,
y: f32,
