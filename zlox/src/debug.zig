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

pub fn disassembleInstruction(chunk: *Chunk, offset: usize) !usize {
    try stdout.print("{d:0>4} ", .{offset});
    if (offset > 0 and chunk.lines.?[offset] == chunk.lines.?[offset - 1]) {
        try stdout.writeAll("   | ");
    } else {
        try stdout.print("{d:>4} ", .{chunk.lines.?[offset]});
    }

    const instruction = chunk.code.?[offset];
    switch (@intToEnum(OpCode, instruction)) {
        .op_constant => return constantInstruction("OP_CONSTANT", chunk, offset),
        .op_nil => return simpleInstruction("OP_NIL", offset),
        .op_true => return simpleInstruction("OP_TRUE", offset),
        .op_false => return simpleInstruction("OP_FALSE", offset),
        .op_equal => return simpleInstruction("OP_EQUAL", offset),
        .op_greater => return simpleInstruction("OP_GREATER", offset),
        .op_less => return simpleInstruction("OP_LESS", offset),
        .op_add => return simpleInstruction("OP_ADD", offset),
        .op_subtract => return simpleInstruction("OP_SUBTRACT", offset),
        .op_multiply => return simpleInstruction("OP_MULTIPLY", offset),
        .op_divide => return simpleInstruction("OP_DIVIDE", offset),
        .op_not => return simpleInstruction("OP_NOT", offset),
        .op_negate => return simpleInstruction("OP_NEGATE", offset),
        .op_return => return simpleInstruction("OP_RETURN", offset),
    }
    stdout.print("Unknown opcode {d}\n", .{instruction});
    return offset + 1;
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
