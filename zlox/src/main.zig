const std = @import("std");
const Allocator = std.mem.Allocator;

const chk = @import("./chunk.zig");
const Chunk = chk.Chunk;
const OpCode = chk.OpCode;
const addConstant = chk.addConstant;
const freeChunk = chk.freeChunk;
const initChunk = chk.initChunk;
const writeChunk = chk.writeChunk;

const debug = @import("./debug.zig");
const disassembleChunk = debug.disassembleChunk;
const vm = @import("./vm.zig");
const freeVM = vm.freeVM;
const initVM = vm.initVM;
const interpret = vm.interpret;

const stdin = std.io.getStdIn().reader();
const stdout = std.io.getStdOut().writer();
const stderr = std.io.getStdErr().writer();

fn repl() !void {
    var buffer: [1024]u8 = undefined;
    while (true) {
        try stdout.writeAll("> ");
        const line = (try stdin.readUntilDelimiterOrEof(&buffer, '\n')) orelse {
            try stdout.writeByte('\n');
            break;
        };

        _ = try interpret(line);
    }
}

fn readFile(allocator: Allocator, path: []const u8) ![]const u8 {
    const file = std.fs.cwd().openFile(path, .{}) catch {
        try stderr.print("Could not open file \"{s}\".\n", .{path});
        std.process.exit(74);
    };
    defer file.close();
    const len = @as(usize, (try file.stat()).size);
    const buffer = file.reader().readAllAlloc(allocator, len) catch |err| {
        switch (err) {
            error.OutOfMemory => {
                try stderr.print("Not enough memory to read \"{s}\".\n", .{path});
                std.process.exit(74);
            },
            else => {
                try stderr.print("Could not read file \"{s}\".\n", .{path});
                std.process.exit(74);
            },
        }
    };
    return buffer;
}

fn runFile(allocator: Allocator, path: []const u8) !void {
    const source = try readFile(allocator, path);
    defer allocator.free(source);
    const result = try interpret(source);

    if (result == .compile_error) std.process.exit(65);
    if (result == .runtime_error) std.process.exit(70);
}

pub fn main() anyerror!void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    initVM();
    defer freeVM();
    // read command line arguments
    var iter = std.process.args();
    // ignore first argument (executable file)
    _ = iter.skip();

    // read second argument as file to load
    if (iter.next()) |filename| {
        try runFile(allocator, filename);
    } else {
        try repl();
    }

    if (iter.skip()) {
        try stderr.writeAll("Usage: zlox [path]\n");
        std.process.exit(64);
    }
}
