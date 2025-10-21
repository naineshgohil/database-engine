const std = @import("std");
const fs = std.fs;
const mem = std.mem;

// Page - A fixed-size block (4KB) - atomic unit of disk I/O
// Buffer Pool - In-memory cache that holds frequently accessed pages

// 4096 matches the OS page size
pub const PAGE_SIZE = 4096;

//
pub const MAX_PAGES = 100;

pub const Pager = struct {
    file: fs.File,

    file_length: u64,

    // Buffer pool - array of optional page pointers
    // In-memory cache to avoid slow disk reads
    pages: [MAX_PAGES]?[]u8,

    //
    allocator: mem.Allocator,

    pub fn init(allocator: mem.Allocator, filename: []const u8) !Pager {
        const file = try fs.cwd().createFile(filename, .{ .read = true, .truncate = false });

        const file_length = try file.getEndPos();

        const pager = Pager{ .file = file, .file_length = file_length, .pages = [_]?[]u8{null} ** MAX_PAGES, .allocator = allocator };

        return pager;
    }

    pub fn getPage(self: *Pager, page_num: u32) ![]u8 {
        if (page_num >= MAX_PAGES) {
            return error.PageOutOfBounds;
        }

        if (self.pages[page_num]) |page| {
            return page;
        }

        // Cache miss: need to load this page from disk
        // Need a buffer in RAM to read disk data into
        const page = try self.allocator.alloc(u8, PAGE_SIZE);
        errdefer self.allocator.free(page);

        const num_pages_file = self.file_length / PAGE_SIZE;

        if (page_num < num_pages_file) {
            // Calculate the byte offset in the file where page starts
            // page 0 starts at byte 0, page 1 at byte 4096, etc.
            try self.file.seekTo(page_num * PAGE_SIZE);

            // Read PAGE_SIZE bytes from the file into our page buffer
            const bytes_read = try self.file.read(page);

            if (bytes_read < PAGE_SIZE) {
                @memset(page[bytes_read..], 0);
            }
        } else {
            // Initialize a new page with 0s
            @memset(page, 0);
        }

        // Cache it
        self.pages[page_num] = page;

        return page;
    }

    // Write a page from memory back to disk
    pub fn flush(self: *Pager, page_num: u32) !void {
        if (self.pages[page_num]) |page| {
            // Move file pointer to where this page should be written
            try self.file.seekTo(page_num * PAGE_SIZE);

            // Persist in-memory changes to permanent storage
            try self.file.writeAll(page);
        }
    }

    // Flushes all pages to disk and frees allocated memory
    pub fn deinit(self: *Pager) void {
        for (self.pages, 0..) |maybe_page, i| {
            if (maybe_page) |page| {
                self.flush(@intCast(i)) catch {};
                self.allocator.free(page);
            }
        }

        self.file.close();
    }
};
