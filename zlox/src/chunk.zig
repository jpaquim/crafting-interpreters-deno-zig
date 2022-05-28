const std = @import("std");
const Allocator = std.mem.Allocator;
const memory = @import("./memory.zig");
const FREE_ARRAY = memory.FREE_ARRAY;
const GROW_ARRAY = memory.GROW_ARRAY;
const GROW_CAPACITY = memory.GROW_CAPACITY;

pub const OpCode = enum(u8) {
    op_return,
};

pub const Chunk = struct {
    count: usize,
    capacity: usize,
    code: ?[]u8,
};

pub fn initChunk(chunk: *Chunk) void {
    chunk.count = 0;
    chunk.capacity = 0;
    chunk.code = null;
}

pub fn freeChunk(allocator: Allocator, chunk: *Chunk) void {
    FREE_ARRAY(allocator, u8, chunk.code, chunk.capacity);
    initChunk(chunk);
}

pub fn writeChunk(allocator: Allocator, chunk: *Chunk, byte: u8) void {
    if (chunk.capacity < chunk.count + 1) {
        const old_capacity = chunk.capacity;
        chunk.capacity = GROW_CAPACITY(old_capacity);
        chunk.code = GROW_ARRAY(allocator, u8, chunk.code, old_capacity, chunk.capacity);
    }

    chunk.code.?[chunk.count] = byte;
    chunk.count += 1;
}
