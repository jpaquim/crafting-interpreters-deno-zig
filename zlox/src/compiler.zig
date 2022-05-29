const std = @import("std");
const scanner = @import("./scanner.zig");
const initScanner = scanner.initScanner;
const scanToken = scanner.scanToken;

const stdout = std.io.getStdOut().writer();

pub fn compile(source: []const u8) !void {
    initScanner(source);
    var line: usize = undefined;
    while (true) {
        const token = scanToken();
        if (token.line != line) {
            try stdout.print("{d:4} ", .{token.line});
            line = token.line;
        } else {
            try stdout.writeAll("   | ");
        }
        try stdout.print("{d:2} '{s}'\n", .{ @enumToInt(token.t_type), token.start[0..token.length] });

        if (token.t_type == .EOF) break;
    }
}
