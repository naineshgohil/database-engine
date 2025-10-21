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

    // Setup input/output for the REPL
    var stdin_buffer: [1024]u8 = undefined;
    var stdin_reader_wrapper = std.fs.File.stdin().reader(&stdin_buffer);
    var stdin = &stdin_reader_wrapper.interface;

    var stdout_buffer: [1024]u8 = undefined;
    var stdout_writer_wrapper = std.fs.File.stdout().writer(&stdout_buffer);
    var stdout = &stdout_writer_wrapper.interface;

    // REPL loop
    while (true) {
        try stdout.print("db > ", .{});

        // readUntilDelimiterOrEof - Read until Enter key (newline)
        const input = (stdin.takeDelimiterExclusive('\n')) catch |err| switch (err) {
            error.EndOfStream => break,
            error.StreamTooLong => {
                std.debug.print("Input too long\n", .{});
                continue;
            },
            else => return err,
        };

        const trimmed_input = mem.trim(u8, input, &std.ascii.whitespace);

        if (trimmed_input.len == 0) continue;

        // Check for meta commands (start with '.')
        if (trimmed_input[0] == '.') {
            if (mem.eql(u8, trimmed_input, ".exit")) {
                std.debug.print("Goodbye!\n", .{});
                break;
            } else {
                std.debug.print("Unrecognized command: {s}\n", .{trimmed_input});
                continue;
            }
        }

        var statement = Statement.prepare(trimmed_input) catch |err| {
            std.debug.print("Error: {}\n", .{err});
            continue;
        };

        statement.execute(&table) catch |err| {
            std.debug.print("Error: {}\n", .{err});
            continue;
        };
    }
}
