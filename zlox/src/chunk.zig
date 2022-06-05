const std = @import("std");
const Allocator = std.mem.Allocator;

const memory = @import("./memory.zig");
const FREE_ARRAY = memory.FREE_ARRAY;
const GROW_ARRAY = memory.GROW_ARRAY;
const GROW_CAPACITY = memory.GROW_CAPACITY;

const v = @import("./value.zig");
const Value = v.Value;
const ValueArray = v.ValueArray;
const freeValueArray = v.freeValueArray;
const initValueArray = v.initValueArray;
const writeValueArray = v.writeValueArray;

const vm = @import("vm.zig");
const pop = vm.pop;
const push = vm.push;

pub const OpCode = enum(u8) {
    op_constant,
    op_nil,
    op_true,
    op_false,
    op_pop,
    op_get_local,
    op_set_local,
    op_get_global,
    op_define_global,
    op_set_global,
    op_get_upvalue,
    op_set_upvalue,
    op_equal,
    op_greater,
    op_less,
    op_add,
    op_subtract,
    op_multiply,
    op_divide,
    op_not,
    op_negate,
    op_print,
    op_jump,
    op_jump_if_false,
    op_loop,
    op_call,
    op_closure,
    op_close_upvalue,
    op_return,
};

pub const Chunk = struct {
    count: usize,
    capacity: usize,
    code: ?[]u8,
    lines: ?[]usize,
    constants: ValueArray,
};

pub fn initChunk(chunk: *Chunk) void {
    chunk.count = 0;
    chunk.capacity = 0;
    chunk.code = null;
    chunk.lines = null;
    initValueArray(&chunk.constants);
}

pub fn freeChunk(allocator: Allocator, chunk: *Chunk) void {
    FREE_ARRAY(allocator, u8, chunk.code, chunk.capacity);
    FREE_ARRAY(allocator, usize, chunk.lines, chunk.capacity);
    freeValueArray(allocator, &chunk.constants);
    initChunk(chunk);
}

pub fn writeChunk(allocator: Allocator, chunk: *Chunk, byte: u8, line: usize) void {
    if (chunk.capacity < chunk.count + 1) {
        const old_capacity = chunk.capacity;
        chunk.capacity = GROW_CAPACITY(old_capacity);
        chunk.code = GROW_ARRAY(allocator, u8, chunk.code, old_capacity, chunk.capacity);
        chunk.lines = GROW_ARRAY(allocator, usize, chunk.lines, old_capacity, chunk.capacity);
    }

    chunk.code.?[chunk.count] = byte;
    chunk.lines.?[chunk.count] = line;
    chunk.count += 1;
}

pub fn addConstant(allocator: Allocator, chunk: *Chunk, value: Value) usize {
    push(value);
    writeValueArray(allocator, &chunk.constants, value);
    _ = pop();
    return chunk.constants.count - 1;
}
