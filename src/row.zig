const std = @import("std");
const mem = std.mem;

// Row is one record with a fixed schema
// Currently it has three columns
// - id: unique identifier (4 bytes)
// - username: user's name (32 bytes)
// - email: user's email (255 bytes)

// 4 (id) + 32 (username) + 255 (email) = 291 bytes
pub const ROW_SIZE = 291;

pub const ID_SIZE = 4;
pub const USERNAME_SIZE = 32;
pub const EMAIL_SIZE = 255;

pub const Row = struct {
    id: u32,
    username: [USERNAME_SIZE]u8,
    email: [EMAIL_SIZE]u8,

    // Convert this Row struct into bytes for disk storage
    // [0..4] - id (4 bytes)
    // [4..36] - username (32 bytes)
    // [36..291] - email (255 bytes)
    pub fn serialize(self: *const Row, destination: []u8) void {
        mem.writeInt(u32, destination[0..4], self.id, .little);

        // Copy username bytes directly to destination
        @memcpy(destination[4..36], &self.username);

        // Copy email bytes directly to destination
        @memcpy(destination[36..291], &self.email);
    }

    // Convert bytes back into Row struct
    pub fn deserialize(source: []const u8) Row {
        var row: Row = undefined;

        row.id = mem.readInt(u32, source[0..4], .little);

        @memcpy(&row.username, source[4..36]);

        @memcpy(&row.email, source[36..291]);

        return row;
    }

    //
    pub fn print(self: *const Row) void {
        std.debug.print("({d}, {s}, {s})\n", .{ self.id, std.mem.sliceTo(&self.username, 0), std.mem.sliceTo(&self.email, 0) });
    }
};
