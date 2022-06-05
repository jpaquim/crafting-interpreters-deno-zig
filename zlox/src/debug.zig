const std = @import("std");

const chk = @import("./chunk.zig");
const Chunk = chk.Chunk;
const OpCode = chk.OpCode;

const AS_FUNCTION = @import("./object.zig").AS_FUNCTION;

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
        .op_pop => return simpleInstruction("OP_POP", offset),
        .op_get_local => return byteInstruction("OP_GET_LOCAL", chunk, offset),
        .op_set_local => return byteInstruction("OP_SET_LOCAL", chunk, offset),
        .op_get_global => return constantInstruction("OP_GET_GLOBAL", chunk, offset),
        .op_define_global => return constantInstruction("OP_DEFINE_GLOBAL", chunk, offset),
        .op_set_global => return constantInstruction("OP_SET_GLOBAL", chunk, offset),
        .op_get_upvalue => return byteInstruction("OP_GET_UPVALUE", chunk, offset),
        .op_set_upvalue => return byteInstruction("OP_SET_UPVALUE", chunk, offset),
        .op_equal => return simpleInstruction("OP_EQUAL", offset),
        .op_greater => return simpleInstruction("OP_GREATER", offset),
        .op_less => return simpleInstruction("OP_LESS", offset),
        .op_add => return simpleInstruction("OP_ADD", offset),
        .op_subtract => return simpleInstruction("OP_SUBTRACT", offset),
        .op_multiply => return simpleInstruction("OP_MULTIPLY", offset),
        .op_divide => return simpleInstruction("OP_DIVIDE", offset),
        .op_not => return simpleInstruction("OP_NOT", offset),
        .op_negate => return simpleInstruction("OP_NEGATE", offset),
        .op_print => return simpleInstruction("OP_PRINT", offset),
        .op_jump => return jumpInstruction("OP_JUMP", 1, chunk, offset),
        .op_jump_if_false => return jumpInstruction("OP_JUMP_IF_FALSE", 1, chunk, offset),
        .op_loop => return jumpInstruction("OP_LOOP", -1, chunk, offset),
        .op_call => return byteInstruction("OP_CALL", chunk, offset),
        .op_class => return constantInstruction("OP_CLASS", chunk, offset),
        .op_closure => {
            var offset_ = offset + 1;
            const constant = chunk.code.?.ptr[offset_];
            offset_ += 1;
            try stdout.print("{s:<16} {d:4} ", .{ "OP_CLOSURE", constant });
            try printValue(chunk.constants.values.?[constant]);
            try stdout.writeByte('\n');

            const function = AS_FUNCTION(chunk.constants.values.?[constant]);
            var j: usize = 0;
            while (j < function.upvalue_count) : (j += 1) {
                const is_local = chunk.code.?[offset_];
                offset_ += 1;
                const index = chunk.code.?[offset_];
                offset_ += 1;
                try stdout.print(
                    "{d:0>4}      |                     {s} {d}\n",
                    .{ offset - 2, if (is_local == 1) @as([]const u8, "local") else "upvalue", index },
                );
            }

            return offset_;
        },
        .op_close_upvalue => return simpleInstruction("OP_CLOSE_UPVALUE", offset),
        .op_return => return simpleInstruction("OP_RETURN", offset),
    }
    try stdout.print("Unknown opcode {d}\n", .{instruction});
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

fn byteInstruction(name: []const u8, chunk: *Chunk, offset: usize) !usize {
    const slot = chunk.code.?[offset + 1];
    try stdout.print("{s:<16} {d:4}\n", .{ name, slot });
    return offset + 2;
}

fn jumpInstruction(name: []const u8, comptime sign: comptime_int, chunk: *Chunk, offset: usize) !usize {
    var jump = @as(u16, chunk.code.?[offset + 1]) << 8;
    jump |= chunk.code.?[offset + 2];
    try stdout.print("{s:<16} {d:4} -> {d}\n", .{ name, offset, @intCast(i32, offset + 3) + sign * @as(i32, jump) });
    return offset + 3;
}
