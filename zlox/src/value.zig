const std = @import("std");
const Allocator = std.mem.Allocator;

const memory = @import("./memory.zig");
const FREE_ARRAY = memory.FREE_ARRAY;
const GROW_ARRAY = memory.GROW_ARRAY;
const GROW_CAPACITY = memory.GROW_CAPACITY;

pub const Value = f64;

pub const ValueArray = struct {
    capacity: usize,
    count: usize,
    values: ?[]Value,
};

pub fn initValueArray(array: *ValueArray) void {
    array.values = null;
    array.capacity = 0;
    array.count = 0;
}

pub fn writeValueArray(allocator: Allocator, array: *ValueArray, value: Value) void {
    if (array.capacity < array.count + 1) {
        const old_capacity = array.capacity;
        array.capacity = GROW_CAPACITY(old_capacity);
        array.values = GROW_ARRAY(allocator, Value, array.values, old_capacity, array.capacity);
    }

    array.values.?[array.count] = value;
    array.count += 1;
}

pub fn freeValueArray(allocator: Allocator, array: *ValueArray) void {
    FREE_ARRAY(allocator, Value, array.values, array.capacity);
    initValueArray(array);
}

pub fn printValue(value: Value) !void {
    const stdout = std.io.getStdOut().writer();
    try stdout.print("{d}", .{value});
}
