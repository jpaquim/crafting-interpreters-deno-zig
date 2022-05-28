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

pub fn main() anyerror!void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var chunk: Chunk = undefined;
    initChunk(&chunk);

    const constant = addConstant(allocator, &chunk, 1.2);
    writeChunk(allocator, &chunk, @enumToInt(OpCode.op_constant), 123);
    writeChunk(allocator, &chunk, constant, 123);

    writeChunk(allocator, &chunk, @enumToInt(OpCode.op_return), 123);

    try disassembleChunk(&chunk, "test chunk");

    defer freeChunk(allocator, &chunk);
}
