const std = @import("std");
const Allocator = std.mem.Allocator;

const memory = @import("./memory.zig");
const FREE_ARRAY = memory.FREE_ARRAY;
const GROW_ARRAY = memory.GROW_ARRAY;
const GROW_CAPACITY = memory.GROW_CAPACITY;

const ValueType = enum {
    bool,
    nil,
    number,
};

pub const Value = struct {
    v_type: ValueType,
    as: union {
        boolean: bool,
        number: f64,
    },
};

pub fn IS_BOOL(value: Value) bool {
    return value.v_type == .bool;
}

pub fn IS_NIL(value: Value) bool {
    return value.v_type == .nil;
}

pub fn IS_NUMBER(value: Value) bool {
    return value.v_type == .number;
}

pub fn AS_BOOL(value: Value) bool {
    return value.as.boolean;
}

pub fn AS_NUMBER(value: Value) f64 {
    return value.as.number;
}

pub fn BOOL_VAL(value: bool) Value {
    return .{ .v_type = .bool, .as = .{ .boolean = value } };
}

pub const NIL_VAL = Value{ .v_type = .nil, .as = undefined };

pub fn NUMBER_VAL(value: f64) Value {
    return .{ .v_type = .number, .as = .{ .number = value } };
}

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
    switch (value.v_type) {
        .bool => {
            try stdout.writeAll(if (AS_BOOL(value)) "true" else "false");
        },
        .nil => try stdout.writeAll("nil"),
        .number => try stdout.print("{d}", .{AS_NUMBER(value)}),
    }
}
