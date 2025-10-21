const std = @import("std");
const mem = std.mem;
const Pager = @import("pager.zig").Pager;
const Row = @import("row.zig");

const PAGE_SIZE = @import("pager.zig").PAGE_SIZE;
const MAX_PAGES = @import("pager.zig").MAX_PAGES;
const ROW_SIZE = Row.ROW_SIZE;

// 4096 / 291 = 13 rows
pub const ROWS_PER_PAGE = PAGE_SIZE / ROW_SIZE;

// 13 * 100 = 1300 rows
pub const MAX_TABLE_ROWS = ROWS_PER_PAGE * MAX_PAGES;

pub const Table = struct {
    // Pager instance handles disk I/O
    pager: Pager,

    // Need to know where to insert new rows and when table is full
    num_rows: u32,

    allocator: mem.Allocator,

    // Initialize the table from existing data on disk
    pub fn init(allocator: mem.Allocator, filename: []const u8) !Table {
        //
        const pager = try Pager.init(allocator, filename);

        //
        const num_rows: u32 = @intCast(pager.file_length / ROW_SIZE);

        return Table{
            .pager = pager,
            .num_rows = num_rows,
            .allocator = allocator,
        };
    }

    pub fn rowSlot(self: *Table, row_num: u32) ![]u8 {
        //
        const page_num = row_num / ROWS_PER_PAGE;

        //
        const page = try self.pager.getPage(page_num);

        // byte offset within the page where this row starts
        // example, row_num = 2, page_num = 0, row_offset = (2%13)*291 = 582
        const row_offset = (row_num % ROWS_PER_PAGE) * ROW_SIZE;

        // [582..(582+291=873)] slice would exclude the last byte (873)
        return page[row_offset .. row_offset + ROW_SIZE];
    }

    // Flush every page to disk and close the file
    pub fn deinit(self: *Table) void {
        //
        const num_full_pages = self.num_rows / ROWS_PER_PAGE;

        //
        const num_additional_rows = self.num_rows % ROWS_PER_PAGE;

        //
        var i: u32 = 0;
        while (i < num_full_pages) : (i += 1) {
            self.pager.flush(i) catch {};
        }

        if (num_additional_rows > 0) {
            self.pager.flush(num_full_pages) catch {};
        }

        self.pager.deinit();
    }
};
