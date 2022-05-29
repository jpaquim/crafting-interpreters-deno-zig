const std = @import("std");
const initScanner = @import("./scanner.zig").initScanner;

const stdout = std.io.getStdOut().writer();

pub fn compile(source: []const u8) !void {
    initScanner(source);
    var line: usize = undefined;
    while (true) {
        const token = scanToken();
        if (token.line != line) {
            try stdout.print("{d:4}", .{token.line});
            line = token.line;
        } else {
            try stdout.writeAll("   | ");
        }
        const slice = @as([*]Token, token.start)[0..token.length];
        try stdout.print("{d:2} '{s}'\n", .{ token.t_type, slice });

        if (token.t_type == .eof) break;
    }
}
