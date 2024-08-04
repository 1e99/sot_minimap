const std = @import("std");
const Self = @This();

allocator: std.mem.Allocator,
bundle: std.StringHashMap([]const u8),

pub fn init(allocator: std.mem.Allocator, file: []const u8) !Self {
    var bundle = std.StringHashMap([]const u8).init(allocator);
    errdefer bundle.deinit();

    var i: usize = 0;
    while (i < file.len) {
        const key = blk: {
            const start_i = i;
            while (i < file.len and file[i] != '=') {
                i += 1;
            }

            break :blk file[start_i..i];
        };
        i += 1;

        const translation = blk: {
            const start_i = i;
            while (i < file.len and file[i] != '\n') {
                i += 1;
            }

            const raw_translation = file[start_i..i];

            var translation = try allocator.alloc(u8, raw_translation.len + 1);
            errdefer allocator.free(translation);

            for (raw_translation, 0..) |b, j| {
                translation[j] = b;
            }

            translation[translation.len - 1] = 0;
            break :blk translation;
        };
        i += 1;

        std.log.info("{s} {s}", .{ key, translation });
        try bundle.put(key, translation);
    }

    return Self{
        .allocator = allocator,
        .bundle = bundle,
    };
}

pub fn deinit(self: *Self) void {
    var translations = self.bundle.valueIterator();
    while (translations.next()) |translation| {
        self.allocator.free(translation.*);
    }

    self.bundle.deinit();
}

pub fn translate(self: *Self, key: []const u8) []const u8 {
    const value = self.bundle.get(key);
    if (value) |translation| {
        return translation;
    }

    return key;
}
