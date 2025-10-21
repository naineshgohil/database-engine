const std = @import("std");
const mem = std.mem;
const Table = @import("table.zig");

// Cursor is a pointer to a specific position in the table
//

pub const Cursor = struct {
    table: *Table,

    // Which row number is the cursor pointing to
    row_num: u32,

    //
    end_of_table: bool,

    //
    pub fn tableStart(table: *Table) Cursor {
        return Cursor{
            .table = table,
            .row_num = 0,
            .end_of_table = (table.num_rows == 0),
        };
    }

    //
    pub fn tableEnd(table: *Table) Cursor {
        return Cursor{ .table = table, .row_num = table.num_rows, .end_of_table = true };
    }

    //
    pub fn value(self: *Cursor) ![]u8 {
        return try self.table.rowSlot(self.row_num);
    }

    pub fn advance(self: *Cursor) void {
        if (!self.end_of_table) {
            self.row_num += 1;
        }

        if (self.row_num >= self.table.num_rows) {
            self.end_of_table = true;
        }
    }
};
