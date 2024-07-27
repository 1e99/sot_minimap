const std = @import("std");
const sot = @import("sea_of_thieves");
const Self = @This();

pub const Error = error{
    NoIslandSerivceActor,
};

process: *sot.Process,
allocator: std.mem.Allocator,
output_dir: std.fs.Dir,

pub fn extract(self: *Self) !void {
    std.log.info("Extracting islands...", .{});

    // Level* https://github.com/DougTheDruid/SoT-Python-Offset-Finder/blob/main/SDKs/CPP-SDK/Engine_Classes.h#L2017
    const level_address = try self.process.readValue(
        u64,
        self.process.world_address + 0x1b0,
    );

    const actor_array = try self.process.readValue(
        sot.Process.ActorArray,
        level_address + 0xa0,
    );

    for (0..actor_array.length) |i| {
        // Actor* https://github.com/DougTheDruid/SoT-Python-Offset-Finder/blob/main/SDKs/CPP-SDK/Engine_Classes.h#L1419
        const actor_address = try self.process.readValue(
            u64,
            actor_array.start_address + (i * 8),
        );

        const actor_id = try self.process.readValue(
            u32,
            actor_address + 24,
        );

        var raw_string: [256]u8 = undefined;
        const actor_name = try self.process.readFName(
            &raw_string,
            actor_id,
        );

        const eql = std.mem.eql(u8, actor_name, "IslandService");
        if (!eql) {
            continue;
        }

        try self.extractIslands(actor_address);
        return;
    }

    return Error.NoIslandSerivceActor;
}

fn extractIslands(
    self: *Self,
    // IslandService* https://github.com/DougTheDruid/SoT-Python-Offset-Finder/blob/main/SDKs/CPP-SDK/Athena_Classes.h#L16284
    island_service_address: u64,
) !void {
    // TArray<Island*>
    const islands_array = try self.process.readValue(
        sot.Process.TArray,
        island_service_address + 0x480,
    );

    var islands = try self.allocator.alloc(
        sot.Island,
        islands_array.length,
    );

    for (0..islands_array.length) |i| {
        islands[i] = try self.extractIsland(islands_array.start_address + (i * 0x70));
    }

    var islands_file = try self.output_dir.createFile("islands.json", .{});
    defer islands_file.close();

    try std.json.stringify(
        islands,
        .{},
        islands_file.writer(),
    );
}

fn extractIsland(
    self: *Self,
    // Island https://github.com/DougTheDruid/SoT-Python-Offset-Finder/blob/main/SDKs/CPP-SDK/Athena_Structs.h#L2387
    island_address: u64,
) !sot.Island {
    const name_id = try self.process.readValue(
        u32,
        island_address + 0x0,
    );

    const name_buffer = try self.allocator.alloc(u8, 1024);
    const name = try self.process.readFName(
        name_buffer,
        name_id,
    );

    // Vector https://github.com/DougTheDruid/SoT-Python-Offset-Finder/blob/main/SDKs/CPP-SDK/CoreUObject_Structs.h#L185
    const center = try self.process.readValue(
        [3]f32,
        island_address + 0x18,
    );

    const island_type: sot.Island.Type = blk: {
        const startsWith = std.mem.startsWith;
        // normal
        // outpost
        // seapost
        if (startsWith(u8, name, "Sea_Fort_")) break :blk .sea_fort;
        // skeleton_fort
        // skeleton_camp
        // shrine
        // treasury
        // unknown
        break :blk .unknown;
    };

    const island_region: sot.Region = blk: {
        const startsWith = std.mem.startsWith;
        if (startsWith(u8, name, "wld_")) break :blk .wilds;
        if (startsWith(u8, name, "bsp_")) break :blk .shores_of_plenty;
        if (startsWith(u8, name, "wsp_")) break :blk .ancient_isles;
        if (startsWith(u8, name, "dvr_")) break :blk .devils_roar;
        if (startsWith(u8, name, "skd_")) break :blk .sunken_kingdom;
        break :blk .unknown;
    };

    return sot.Island{
        .name = name,
        .type = island_type,
        .region = island_region,
        .x = center[0],
        .y = center[1],
    };
}
