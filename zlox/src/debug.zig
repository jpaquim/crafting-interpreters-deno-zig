const std = @import("std");

const chk = @import("./chunk.zig");
const Chunk = chk.Chunk;
const OpCode = chk.OpCode;

const printValue = @import("./value.zig").printValue;

const stdout = std.io.getStdOut().writer();

pub fn disassembleChunk(chunk: *Chunk, name: []const u8) !void {
    try stdout.print("== {s} ==\n", .{name});

    var offset: usize = 0;
    while (offset < chunk.count) : (offset = try disassembleInstruction(chunk, offset)) {}
}

fn disassembleInstruction(chunk: *Chunk, offset: usize) !usize {
    try stdout.print("{d:0>4} ", .{offset});

    const instruction = @intToEnum(OpCode, chunk.code.?[offset]);
    switch (instruction) {
        OpCode.op_constant => return constantInstruction("OP_CONSTANT", chunk, offset),
        OpCode.op_return => return simpleInstruction("OP_RETURN", offset),
        // else => {
        //     stdout.print("Unknown opcode {d}\n", .{instruction});
        //     return offset + 1;
        // },
    }
}

fn constantInstruction(name: []const u8, chunk: *Chunk, offset: usize) !usize {
    const constant = chunk.code.?[offset + 1];
    try stdout.print("{s:<16} {d:4} '", .{ name, constant });
    try printValue(chunk.constants.values.?[constant]);
    try stdout.writeAll("'\n");
    return offset + 2;
}

fn simpleInstruction(name: []const u8, offset: usize) !usize {
    try stdout.print("{s}\n", .{name});
    return offset + 1;
}
