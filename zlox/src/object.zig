const std = @import("std");
const Allocator = std.mem.Allocator;

const memory = @import("./memory.zig");
const ALLOCATE = memory.ALLOCATE;
const FREE_ARRAY = memory.FREE_ARRAY;
const reallocate = memory.reallocate;

const table = @import("./table.zig");
const tableFindString = table.tableFindString;
const tableSet = table.tableSet;

const v = @import("./value.zig");
const Value = v.Value;
const AS_OBJ = v.AS_OBJ;
const IS_OBJ = v.IS_OBJ;
const NIL_VAL = v.NIL_VAL;

const vm = @import("./vm.zig");

const ObjType = enum {
    string,
};

pub const Obj = struct {
    o_type: ObjType,
    next: ?*Obj,
};

pub const ObjString = struct {
    obj: Obj,
    length: usize,
    chars: [*]u8,
    hash: u32,
};

pub fn OBJ_TYPE(value: Value) ObjType {
    return AS_OBJ(value).o_type;
}

pub fn IS_STRING(value: Value) bool {
    return isObjType(value, .string);
}

pub fn AS_STRING(value: Value) *ObjString {
    return @fieldParentPtr(ObjString, "obj", AS_OBJ(value));
    // return @ptrCast(*ObjString, AS_OBJ(value));
}

pub fn AS_CSTRING(value: Value) [*]const u8 {
    // return @ptrCast(*ObjString, AS_OBJ(value)).chars;
    return @fieldParentPtr(ObjString, "obj", AS_OBJ(value)).chars;
}

pub fn ALLOCATE_OBJ(allocator: Allocator, comptime T: type, object_type: ObjType) *T {
    return @fieldParentPtr(T, "obj", allocateObject(allocator, @sizeOf(T), object_type));
}

fn allocateObject(allocator: Allocator, size: usize, o_type: ObjType) *Obj {
    const object = @alignCast(@alignOf(Obj), std.mem.bytesAsValue(Obj, @ptrCast(*[8]u8, reallocate(
        allocator,
        null,
        0,
        size,
    ).?.ptr)));
    object.o_type = o_type;

    object.next = vm.vm.objects;
    vm.vm.objects = object;
    return object;
}

fn allocateString(allocator: Allocator, chars: [*]u8, length: usize, hash: u32) *ObjString {
    const string = ALLOCATE_OBJ(allocator, ObjString, .string);
    string.length = length;
    string.chars = chars;
    string.hash = hash;
    _ = tableSet(allocator, &vm.vm.strings, string, NIL_VAL);
    return string;
}

fn hashString(key: [*]const u8, length: usize) u32 {
    var hash = @as(u32, 2166136261);
    for (key[0..length]) |char| {
        hash ^= char;
        hash *%= 16777619;
    }
    return hash;
}

pub fn takeString(allocator: Allocator, chars: [*]u8, length: usize) *ObjString {
    const hash = hashString(chars, length);
    const interned = tableFindString(&vm.vm.strings, chars, length, hash);

    if (interned != null) {
        FREE_ARRAY(allocator, u8, chars[0..length], length);
        return interned.?;
    }
    return allocateString(allocator, chars, length, hash);
}

pub fn copyString(allocator: Allocator, chars: [*]const u8, length: usize) *ObjString {
    const hash = hashString(chars, length);
    const interned = tableFindString(&vm.vm.strings, chars, length, hash);

    if (interned != null) return interned.?;

    const heapChars = ALLOCATE(allocator, u8, length + 1);
    std.mem.copy(u8, heapChars, chars[0..length]);
    return allocateString(allocator, heapChars.ptr, length, hash);
}

pub fn printObject(value: Value) !void {
    const stdout = std.io.getStdOut().writer();
    switch (OBJ_TYPE(value)) {
        .string => try stdout.writeAll(AS_CSTRING(value)[0..AS_STRING(value).length]),
    }
}

fn isObjType(value: Value, o_type: ObjType) bool {
    return IS_OBJ(value) and AS_OBJ(value).o_type == o_type;
}