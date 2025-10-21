const std = @import("std");
const mem = std.mem;
const Table = @import("table.zig");
const Statement = @import("statement.zig");
const database_engine_ii = @import("database_engine_ii");

pub fn main() !void {
    const gpa = std.heap.GeneralPurposeAllocator(.{}){};
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
    const table = try Table.init(allocator, filename);
    defer table.deinit();

    // Setup input/output for the REPL
    const stdin = std.io.getStdIn().reader();
    const stdout = std.io.getStdOut().writer();

    // Buffer to hold user input
    const buffer: [256]u8 = undefined;

    // REPL loop
    while (true) {
        try stdout.print("db > ", .{});

        // readUntilDelimiterOrEof - Read until Enter key (newline)
        const input = (try stdin.readUntilDelimiterOrEof(&buffer, '\n')) orelse break;

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

        const statement = Statement.prepare(trimmed_input) catch |err| {
            std.debug.print("Error: {}\n", .{err});
            continue;
        };

        statement.execute(&table) catch |err| {
            std.debug.print("Error: {}\n", .{err});
            continue;
        };
    }
}
