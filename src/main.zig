const std = @import("std");
const mem = std.mem;
const Table = @import("table.zig").Table;
const Statement = @import("statement.zig").Statement;
const database_engine_ii = @import("database_engine_ii");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    const allocator = gpa.allocator();

    const arguments = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, arguments);

    // Check is the user provided a filename
    if (arguments.len < 2) {
        std.debug.print("Usage: db <filename>\n", .{});
        return;
    }

    const filename = arguments[1];

    // Initialize connection to the database file
    var table = try Table.init(allocator, filename);
    defer table.deinit();

    // Setup input/output for REPL
    var stdin_buffer: [1024]u8 = undefined;
    var stdin_reader_wrapper = std.fs.File.stdin().reader(&stdin_buffer);
    const stdin = &stdin_reader_wrapper.interface;

    var line_writer = std.Io.Writer.Allocating.init(allocator);
    defer line_writer.deinit();

    var stdout_buffer: [1024]u8 = undefined;
    var stdout_writer_wrapper = std.fs.File.stdout().writer(&stdout_buffer);
    const stdout = &stdout_writer_wrapper.interface;

    try stdout.writeAll("db > ");
    try stdout.flush();

    while (stdin.streamDelimiter(&line_writer.writer, '\n')) |_| {
        const input = line_writer.written();

        var input_copy: [256]u8 = undefined;
        @memcpy(input_copy[0..input.len], input);
        const trimmed = mem.trim(u8, input_copy[0..input.len], &std.ascii.whitespace);

        line_writer.clearRetainingCapacity();
        stdin.toss(1);

        if (trimmed.len == 0) continue;

        if (trimmed[0] == '.') {
            if (mem.eql(u8, trimmed, ".exit")) {
                break;
            } else {
                try stdout.print("Unrecognized command: {s}\n", .{trimmed});
            }

            continue;
        }

        var statement = Statement.prepare(trimmed) catch |err| {
            try stdout.print("Error: {}\n", .{err});
            continue;
        };

        statement.execute(&table) catch |err| {
            try stdout.print("Error: {}\n", .{err});
        };

        try stdout.writeAll("db > ");
        try stdout.flush();
    } else |err| if (err != error.EndOfStream) return err;
}
