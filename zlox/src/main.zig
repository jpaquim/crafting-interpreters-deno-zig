const std = @import("std");
const Allocator = std.mem.Allocator;

const chk = @import("./chunk.zig");
const Chunk = chk.Chunk;
const OpCode = chk.OpCode;
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
    writeChunk(allocator, &chunk, @enumToInt(OpCode.op_return));

    try disassembleChunk(&chunk, "test chunk");

    defer freeChunk(allocator, &chunk);
}
