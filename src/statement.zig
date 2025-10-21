const std = @import("std");
const fmt = std.fmt;
const mem = std.mem;
const Row = @import("row.zig");
const Table = @import("table.zig");
const Cursor = @import("cursor.zig");

// A statement is a parsed database command (INSERT or SELECT)
// We need to convert user input into executble operations

pub const StatementType = enum { INSERT, SELECT };

pub const Statement = struct {
    type: StatementType,

    row_to_insert: ?Row,

    // Parse a text command into a Statement struct
    // Converts user input like "insert 1 neal neal@gmail.com" into a
    // structured statement
    pub fn prepare(input: []const u8) !Statement {
        if (mem.startsWith(u8, input, "insert")) {
            const statement = Statement{
                .type = .INSERT,
                .row_to_insert = null,
            };

            const tokens = mem.tokenizeAny(u8, input, " ");

            // Skip the "insert keyword"
            _ = tokens.next();

            // Get id, username, and email
            const id_str = tokens.next() orelse return error.SyntaxError;
            const username_str = tokens.next() orelse return error.SyntaxError;
            const email_str = tokens.next() orelse return error.SyntaxError;

            const row: Row = undefined;
            row.id = try fmt.parseInt(u32, id_str, 10);

            @memset(&row.username, 0);
            @memcpy(row.username[0..@min(username_str.len, row.USERNAME_SIZE)], username_str[0..@min(username_str.len, row.USERNAME_SIZE)]);

            @memset(&row.email, 0);
            @memcpy(row.email[0..@min(email_str.len, row.EMAIL_SIZE)], email_str[0..@min(email_str.len, row.EMAIL_SIZE)]);

            statement.row_to_insert = row;

            return statement;
        } else if (mem.startsWith(u8, input, "select")) {
            return Statement{
                .type = .SELECT,
                .row_to_insert = null,
            };
        } else {
            return error.UnrecognizedStatement;
        }
    }

    //
    pub fn execute(self: *Statement, table: *Table) !void {
        switch (self.type) {
            .INSERT => try executeInsert(self, table),
            .SELECT => try executeSelect(table),
        }
    }
};

// Take the row from the statement and writes it to the table
fn executeInsert(statement: *Statement, table: *Table) !void {
    if (table.num_rows >= Table.MAX_TABLE_ROWS) {
        return error.TableFull;
    }

    //
    const row = statement.row_to_insert orelse return error.NoRowToInsert;

    // Get a cursor pointing to the end of table
    const cursor = Cursor.tableEnd(table);

    // Get the memory location where this row should be written
    const slot = try cursor.value();

    //
    row.serialize(slot);

    table.num_rows += 1;
}

// Display all rows in the table
fn executeSelect(table: *Table) !void {
    const cursor = Cursor.tableStart(table);

    while (!cursor.end_of_table) {
        const slot = try cursor.value();

        //
        const row = Row.deserialize(slot);

        //
        row.print();

        //
        cursor.advance();
    }
}
