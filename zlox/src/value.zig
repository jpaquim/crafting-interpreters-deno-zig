const std = @import("std");
const Allocator = std.mem.Allocator;

const NAN_BOXING = @import("./common.zig").NAN_BOXING;

const memory = @import("./memory.zig");
const FREE_ARRAY = memory.FREE_ARRAY;
const GROW_ARRAY = memory.GROW_ARRAY;
const GROW_CAPACITY = memory.GROW_CAPACITY;

const o = @import("./object.zig");
const Obj = o.Obj;
const AS_STRING = o.AS_STRING;
const printObject = o.printObject;

const ValueType = enum {
    bool,
    nil,
    number,
    obj,
};

const SIGN_BIT: u64 = 0x8000000000000000;
const QNAN: u64 = 0x7ffc000000000000;

const TAG_NIL: u64 = 1;
const TAG_FALSE: u64 = 2;
const TAG_TRUE: u64 = 3;

pub const Value = if (NAN_BOXING) u64 else struct {
    v_type: ValueType,
    as: union {
        boolean: bool,
        number: f64,
        obj: *Obj,
    },
};

pub fn IS_BOOL(value: Value) bool {
    if (NAN_BOXING) return (value | 1) == TRUE_VAL;

    return value.v_type == .bool;
}

pub fn IS_NIL(value: Value) bool {
    if (NAN_BOXING) return value == NIL_VAL;

    return value.v_type == .nil;
}

pub fn IS_NUMBER(value: Value) bool {
    if (NAN_BOXING) return (value & QNAN) != QNAN;

    return value.v_type == .number;
}

pub fn IS_OBJ(value: Value) bool {
    if (NAN_BOXING) return (value & (QNAN | SIGN_BIT)) == (QNAN | SIGN_BIT);

    return value.v_type == .obj;
}

pub fn AS_BOOL(value: Value) bool {
    if (NAN_BOXING) return value == TRUE_VAL;

    return value.as.boolean;
}

pub fn AS_NUMBER(value: Value) f64 {
    if (NAN_BOXING) return valueToNum(value);

    return value.as.number;
}

pub fn AS_OBJ(value: Value) *Obj {
    if (NAN_BOXING) return @intToPtr(*Obj, value & (~(SIGN_BIT | QNAN)));

    return value.as.obj;
}

pub fn BOOL_VAL(value: bool) Value {
    if (NAN_BOXING) return if (value) TRUE_VAL else FALSE_VAL;

    return .{ .v_type = .bool, .as = .{ .boolean = value } };
}

pub const FALSE_VAL = QNAN | TAG_FALSE;
pub const TRUE_VAL = QNAN | TAG_TRUE;
pub const NIL_VAL = if (NAN_BOXING) @as(Value, QNAN | TAG_NIL) else Value{ .v_type = .nil, .as = undefined };

pub fn NUMBER_VAL(value: f64) Value {
    if (NAN_BOXING) return numToValue(value);

    return .{ .v_type = .number, .as = .{ .number = value } };
}

fn valueToNum(value: Value) f64 {
    return @bitCast(f64, value);
}

fn numToValue(num: f64) Value {
    return @bitCast(u64, num);
}

pub fn OBJ_VAL(object: *Obj) Value {
    if (NAN_BOXING) return SIGN_BIT | QNAN | @ptrToInt(object);

    return .{ .v_type = .obj, .as = .{ .obj = object } };
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
    if (NAN_BOXING) {
        if (IS_BOOL(value)) {
            try stdout.writeAll(if (AS_BOOL(value)) "true" else "false");
        } else if (IS_NIL(value)) {
            try stdout.writeAll("nil");
        } else if (IS_NUMBER(value)) {
            try stdout.print("{d}", .{AS_NUMBER(value)});
        } else if (IS_OBJ(value)) {
            try printObject(value);
        }
    } else {
        switch (value.v_type) {
            .bool => {
                try stdout.writeAll(if (AS_BOOL(value)) "true" else "false");
            },
            .nil => try stdout.writeAll("nil"),
            .number => try stdout.print("{d}", .{AS_NUMBER(value)}),
            .obj => try printObject(value),
        }
    }
}

pub fn valuesEqual(a: Value, b: Value) bool {
    if (NAN_BOXING) {
        if (IS_NUMBER(a) and IS_NUMBER(b)) {
            return AS_NUMBER(a) == AS_NUMBER(b);
        }
        return a == b;
    } else {
        if (a.v_type != b.v_type) return false;
        switch (a.v_type) {
            .bool => return AS_BOOL(a) == AS_BOOL(b),
            .nil => return true,
            .number => return AS_NUMBER(a) == AS_NUMBER(b),
            .obj => return AS_OBJ(a) == AS_OBJ(b),
        }
    }
}
