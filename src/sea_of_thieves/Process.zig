const std = @import("std");
const sot = @import("sot.zig");
const posix = std.posix;
const Self = @This();

pub const TArray = packed struct {
    start_address: u64,
    length: u16,
};

pub const ActorArray = packed struct {
    start_address: u64,
    length: u32,
};

pub fn findProcessId() !?u64 {
    // TODO: Use posix calls, possibly?
    var dir = try std.fs.openDirAbsolute(
        "/proc",
        .{
            .iterate = true,
        },
    );
    defer dir.close();

    var iterator = dir.iterate();
    while (try iterator.next()) |entry| {
        if (entry.kind != .directory) {
            continue;
        }

        const process_id = std.fmt.parseInt(u64, entry.name, 10) catch {
            continue;
        };

        const is_sot = try isSoTProcess(process_id);
        if (is_sot) {
            return process_id;
        }
    }

    return null;
}

fn isSoTProcess(process_id: u64) !bool {
    var string_buffer: [512]u8 = undefined;

    const path = try std.fmt.bufPrint(
        &string_buffer,
        "/proc/{d}/cmdline",
        .{process_id},
    );

    const fd = try posix.open(path, .{}, 0);
    defer posix.close(fd);

    const buffer_read = try posix.read(
        fd,
        &string_buffer,
    );

    const command = string_buffer[0..buffer_read];
    const found = std.mem.containsAtLeast(u8, command, 1, "SotGame.exe");
    if (!found) {
        return false;
    }

    return true;
}

allocator: std.mem.Allocator,
process_id: u64,
memory_fd: posix.fd_t,

// World* https://github.com/DougTheDruid/SoT-Python-Offset-Finder/blob/main/SDKs/CPP-SDK/Engine_Classes.h
world_address: u64,

// - https://github.com/untyper/ue4-gnames-gobjects-guide
gname_address: u64,
gobject_address: u64,

gname_cache: std.AutoHashMap(u32, []const u8),

pub fn init(allocator: std.mem.Allocator, process_id: u64) !Self {
    var self: Self = undefined;
    self.allocator = allocator;
    self.process_id = process_id;

    var mem_path: [256]u8 = undefined;

    const memory_path = try std.fmt.bufPrint(
        &mem_path,
        "/proc/{d}/mem",
        .{process_id},
    );

    self.memory_fd = try std.posix.open(
        memory_path,
        .{
            .ACCMODE = .RDONLY,
        },
        0,
    );
    errdefer posix.close(self.memory_fd);

    // TODO: Find these patterns automatically:
    // Source: https://github.com/DougTheDruid/SoT-ESP-Framework/blob/main/memory_helper.py#L65
    const world_start_address: u64 = 0x140c84a81; // 48 8B 05 ?? ?? ?? ?? 48 8B 88 ?? ?? ?? ?? 48 85 C9 74 06 48 8B 49 70
    const gname_start_address: u64 = 0x141d89908; // 48 89 3D ?? ?? ?? ?? 41 8B 75 00
    const gobject_start_address: u64 = 0x141e1cb51; // 48 8B 15 ?? ?? ?? ?? 3B 42 1C

    const world_offset = try self.readValue(
        u32,
        world_start_address + 3,
    );

    self.world_address = try self.readValue(
        u64,
        world_start_address + world_offset + 7,
    );

    const gname_offset = try self.readValue(
        u32,
        gname_start_address + 3,
    );

    self.gname_address = try self.readValue(
        u64,
        gname_start_address + gname_offset + 7,
    );

    const gobject_offset = try self.readValue(
        u32,
        gobject_start_address + 3,
    );

    self.gobject_address = try self.readValue(
        u64,
        gobject_start_address + gobject_offset + 7,
    );

    self.gname_cache = std.AutoHashMap(u32, []const u8).init(allocator);
    errdefer self.gname_cache.deinit();

    return self;
}

pub fn deinit(self: *Self) void {
    posix.close(self.memory_fd);
    var gnames = self.gname_cache.valueIterator();
    while (gnames.next()) |gname| {
        self.allocator.free(gname.*);
    }

    self.gname_cache.deinit();
}

pub fn isRunning(self: *const Self) bool {
    _ = posix.fcntl(
        self.memory_fd,
        posix.F.GETFD,
        0,
    ) catch {
        return false;
    };

    return true;
}

pub fn readPlayerPosition(self: *Self) !?sot.Position {
    // GameInstance* https://github.com/DougTheDruid/SoT-Python-Offset-Finder/blob/main/SDKs/CPP-SDK/Engine_Classes.h
    const game_instance_address = try self.readValue(
        u64,
        self.world_address + 0x1c0,
    );

    if (game_instance_address == 0x0) {
        return null;
    }

    // TArray<LocalPlayer*>
    const local_players = try self.readValue(
        TArray,
        game_instance_address + 0x38,
    );

    if (local_players.length == 0) {
        return null;
    }

    // LocalPlayer* https://github.com/DougTheDruid/SoT-Python-Offset-Finder/blob/main/SDKs/CPP-SDK/Engine_Classes.h
    const player_address = try self.readValue(
        u64,
        local_players.start_address,
    );

    if (player_address == 0x0) {
        return null;
    }

    // PlayerController* https://github.com/DougTheDruid/SoT-Python-Offset-Finder/blob/main/SDKs/CPP-SDK/Engine_Classes.h
    const controller_address = try self.readValue(
        u64,
        player_address + 0x30,
    );

    if (controller_address == 0x0) {
        return null;
    }

    // PlayerCameraManager* https://github.com/DougTheDruid/SoT-Python-Offset-Finder/blob/main/SDKs/CPP-SDK/Engine_Classes.h
    const camera_manager_address = try self.readValue(
        u64,
        controller_address + 0x458,
    );

    if (camera_manager_address == 0x0) {
        return null;
    }

    const position = try self.readValue(
        [5]f32,
        camera_manager_address // No need to dereference pointers here
        + 0x440 // CameraCacheEntry https://github.com/DougTheDruid/SoT-Python-Offset-Finder/blob/main/SDKs/CPP-SDK/Engine_Structs.h
        + 0x10 // MinimalViewInfo https://github.com/DougTheDruid/SoT-Python-Offset-Finder/blob/main/SDKs/CPP-SDK/Engine_Structs.h
        + 0x0, // Vector https://github.com/DougTheDruid/SoT-Python-Offset-Finder/blob/main/SDKs/CPP-SDK/CoreUObject_Structs.h
    );

    return .{
        .x = position[0],
        .y = position[1],
        .z = position[2],
        .yaw = position[3],
        .pitch = position[4],
    };
}

pub fn readValue(self: *Self, comptime T: type, offset: u64) !T {
    var buffer: T = undefined;

    // TODO: Check return value
    _ = try posix.pread(
        self.memory_fd,
        std.mem.asBytes(&buffer),
        offset,
    );

    return buffer;
}

pub fn readFName(self: *Self, entry_id: u32) ![]const u8 {
    const chaced_buffer = self.gname_cache.get(entry_id);
    if (chaced_buffer) |buffer| {
        return buffer;
    }

    var buffer = try self.allocator.alloc(u8, 0);
    errdefer self.allocator.free(buffer);

    const name_address_address = try self.readValue(
        u64,
        self.gname_address + ((entry_id / 0x4_000) * 0x8),
    );

    var name_address = try self.readValue(
        u64,
        name_address_address + (0x8 * (entry_id % 0x4_000)),
    );

    name_address += 0x10;

    while (true) {
        const char = try self.readValue(
            u8,
            name_address,
        );
        if (char == 0x00) {
            break;
        }

        name_address += 1;

        const length = buffer.len;
        buffer = try self.allocator.realloc(buffer, length + 1);
        buffer[length] = char;
    }

    try self.gname_cache.put(entry_id, buffer);
    return buffer;
}
