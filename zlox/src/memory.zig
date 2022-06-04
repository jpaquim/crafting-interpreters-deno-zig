const std = @import("std");
const Allocator = std.mem.Allocator;

const chk = @import("./chunk.zig");
const freeChunk = chk.freeChunk;

const common = @import("./common.zig");
const DEBUG_LOG_GC = common.DEBUG_LOG_GC;
const DEBUG_STRESS_GC = common.DEBUG_STRESS_GC;

const o = @import("./object.zig");
const Obj = o.Obj;
const ObjClosure = o.ObjClosure;
const ObjFunction = o.ObjFunction;
const ObjNative = o.ObjNative;
const ObjString = o.ObjString;
const ObjUpvalue = o.ObjUpvalue;

const table = @import("./table.zig");
const markTable = table.markTable;

const v = @import("./value.zig");
const Value = v.Value;
const AS_OBJ = v.AS_OBJ;
const IS_OBJ = v.IS_OBJ;
const OBJ_VAL = v.OBJ_VAL;
const printValue = v.printValue;

const vm = @import("./vm.zig");

pub fn ALLOCATE(allocator: Allocator, comptime T: type, count: usize) ?[]T {
    const ptr = reallocate(allocator, null, 0, @sizeOf(T) * count);
    return if (ptr) |bytes| std.mem.bytesAsSlice(T, @alignCast(@alignOf(T), bytes)) else null;
}

fn FREE(allocator: Allocator, comptime T: type, ptr: *Obj) void {
    const result = reallocate(
        allocator,
        std.mem.asBytes(@fieldParentPtr(T, "obj", ptr)),
        @sizeOf(T),
        0,
    );
    std.debug.assert(result == null);
}

pub fn GROW_CAPACITY(capacity: usize) usize {
    return if (capacity < 8) 8 else capacity * 2;
}

pub fn GROW_ARRAY(allocator: Allocator, comptime T: type, slice: ?[]T, old_count: usize, new_count: usize) ?[]T {
    return std.mem.bytesAsSlice(T, @alignCast(@alignOf(T), reallocate(
        allocator,
        if (slice != null) std.mem.sliceAsBytes(slice.?) else null,
        @sizeOf(T) * old_count,
        @sizeOf(T) * new_count,
    ).?));
}

pub fn FREE_ARRAY(allocator: Allocator, comptime T: type, slice: ?[]T, old_count: usize) void {
    const result = reallocate(
        allocator,
        if (slice != null) std.mem.sliceAsBytes(slice.?) else null,
        @sizeOf(T) * old_count,
        0,
    );
    std.debug.assert(result == null);
}

pub fn reallocate(allocator: Allocator, slice: ?[]u8, old_size: usize, new_size: usize) ?[]u8 {
    if (new_size > old_size) {
        if (DEBUG_STRESS_GC) {
            collectGarbage();
        }
    }

    if (new_size == 0) {
        if (slice != null) allocator.free(slice.?);
        return null;
    }

    if (old_size == 0) {
        return allocator.alloc(u8, new_size) catch std.process.exit(1);
    }

    const result = allocator.realloc(slice.?, new_size) catch std.process.exit(1);
    return result;
}

pub fn markObject(object: ?*Obj) void {
    if (object == null) return;
    if (DEBUG_LOG_GC) {
        const stdout = std.io.getStdOut().writer();
        stdout.print("{*} mark ", .{object.?}) catch unreachable;
        printValue(OBJ_VAL(object.?)) catch unreachable;
        stdout.writeByte('\n') catch unreachable;
    }

    object.?.is_marked = true;
}

pub fn markValue(value: Value) void {
    if (IS_OBJ(value)) markObject(AS_OBJ(value));
}

fn freeObject(allocator: Allocator, object: *Obj) void {
    if (DEBUG_LOG_GC) {
        const stdout = std.io.getStdOut().writer();
        stdout.print("{*} free type {d}\n", .{ object, object.o_type }) catch unreachable;
    }

    switch (object.o_type) {
        .closure => {
            const closure = @fieldParentPtr(ObjClosure, "obj", object);
            FREE_ARRAY(allocator, ?*ObjUpvalue, if (closure.upvalues == null) null else closure.upvalues.?[0..closure.upvalue_count], closure.upvalue_count);
            FREE(allocator, ObjClosure, object);
        },
        .function => {
            const function = @fieldParentPtr(ObjFunction, "obj", object);
            freeChunk(allocator, &function.chunk);
            FREE(allocator, ObjFunction, object);
        },
        .native => {
            FREE(allocator, ObjNative, object);
        },
        .string => {
            const string = @fieldParentPtr(ObjString, "obj", object);
            FREE_ARRAY(allocator, u8, string.chars[0..string.length], string.length);
            FREE(allocator, ObjString, object);
        },
        .upvalue => {
            FREE(allocator, ObjUpvalue, object);
        },
    }
}

fn markRoots() void {
    var slot = @ptrCast([*]Value, &vm.vm.stack);
    while (@ptrToInt(slot) < @ptrToInt(vm.vm.stack_top)) : (slot += 1) {
        markValue(slot[0]);
    }

    markTable(&vm.vm.globals);
}

fn collectGarbage() void {
    if (DEBUG_LOG_GC) {
        const stdout = std.io.getStdOut().writer();
        stdout.writeAll("-- gc begin\n") catch unreachable;
    }

    markRoots();

    if (DEBUG_LOG_GC) {
        const stdout = std.io.getStdOut().writer();
        stdout.writeAll("-- gc end\n") catch unreachable;
    }
}

pub fn freeObjects(allocator: Allocator) void {
    var object = vm.vm.objects;
    while (object) |obj| {
        const next = obj.next;
        freeObject(allocator, obj);
        object = next;
    }
}
