const std = @import("std");
const Allocator = std.mem.Allocator;

const chk = @import("./chunk.zig");
const freeChunk = chk.freeChunk;

const common = @import("./common.zig");
const DEBUG_LOG_GC = common.DEBUG_LOG_GC;
const DEBUG_STRESS_GC = common.DEBUG_STRESS_GC;

const markCompilerRoots = @import("./compiler.zig").markCompilerRoots;

const o = @import("./object.zig");
const Obj = o.Obj;
const ObjClass = o.ObjClass;
const ObjClosure = o.ObjClosure;
const ObjFunction = o.ObjFunction;
const ObjInstance = o.ObjInstance;
const ObjNative = o.ObjNative;
const ObjString = o.ObjString;
const ObjUpvalue = o.ObjUpvalue;

const table = @import("./table.zig");
const freeTable = table.freeTable;
const markTable = table.markTable;
const tableRemoveWhite = table.tableRemoveWhite;

const v = @import("./value.zig");
const Value = v.Value;
const ValueArray = v.ValueArray;
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

const GC_HEAP_GROW_FACTOR = 2;

pub fn reallocate(allocator: Allocator, slice: ?[]u8, old_size: usize, new_size: usize) ?[]u8 {
    vm.vm.bytes_allocated = vm.vm.bytes_allocated + new_size - old_size;
    if (new_size > old_size) {
        if (DEBUG_STRESS_GC) {
            collectGarbage(allocator);
        }

        if (vm.vm.bytes_allocated > vm.vm.next_gc) {
            collectGarbage(allocator);
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

pub fn markObject(allocator: Allocator, object_: ?*Obj) void {
    if (object_ == null) return;
    const object = object_.?;
    if (object.is_marked) return;

    if (DEBUG_LOG_GC) {
        const stdout = std.io.getStdOut().writer();
        stdout.print("{*} mark ", .{object}) catch unreachable;
        printValue(OBJ_VAL(object)) catch unreachable;
        stdout.writeByte('\n') catch unreachable;
    }

    object.is_marked = true;

    if (vm.vm.gray_capacity < vm.vm.gray_count + 1) {
        vm.vm.gray_capacity = GROW_CAPACITY(vm.vm.gray_capacity);
        vm.vm.gray_stack = (if (vm.vm.gray_stack) |gray_stack| allocator.realloc(gray_stack, vm.vm.gray_capacity) else allocator.alloc(*Obj, vm.vm.gray_capacity)) catch std.process.exit(1);
    }

    vm.vm.gray_stack.?[vm.vm.gray_count] = object;
    vm.vm.gray_count += 1;
}

pub fn markValue(allocator: Allocator, value: Value) void {
    if (IS_OBJ(value)) markObject(allocator, AS_OBJ(value));
}

fn markArray(allocator: Allocator, array: *ValueArray) void {
    var i: usize = 0;
    while (i < array.count) : (i += 1) {
        markValue(allocator, array.values.?[i]);
    }
}

fn blackenObject(allocator: Allocator, object: *Obj) void {
    if (DEBUG_LOG_GC) {
        const stdout = std.io.getStdOut().writer();
        stdout.print("{*} blacken ", .{object}) catch unreachable;
        printValue(OBJ_VAL(object)) catch unreachable;
        stdout.writeByte('\n') catch unreachable;
    }

    switch (object.o_type) {
        .class => {
            const klass = @fieldParentPtr(ObjClass, "obj", object);
            markObject(allocator, &klass.name.obj);
        },
        .closure => {
            const closure = @fieldParentPtr(ObjClosure, "obj", object);
            markObject(allocator, &closure.function.obj);
            var i: usize = 0;
            while (i < closure.upvalue_count) : (i += 1) {
                markObject(allocator, &closure.upvalues.?[i].?.obj);
            }
        },
        .function => {
            const function = @fieldParentPtr(ObjFunction, "obj", object);
            markObject(allocator, if (function.name) |name| &name.obj else null);
            markArray(allocator, &function.chunk.constants);
        },
        .instance => {
            const instance = @fieldParentPtr(ObjInstance, "obj", object);
            markObject(allocator, &instance.klass.obj);
            markTable(allocator, &instance.fields);
        },
        .upvalue => {
            markValue(allocator, @fieldParentPtr(ObjUpvalue, "obj", object).closed);
        },
        .native, .string => {},
    }
}

fn freeObject(allocator: Allocator, object: *Obj) void {
    if (DEBUG_LOG_GC) {
        const stdout = std.io.getStdOut().writer();
        stdout.print("{*} free type {d}\n", .{ object, object.o_type }) catch unreachable;
    }

    switch (object.o_type) {
        .class => {
            FREE(allocator, ObjClass, object);
        },
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
        .instance => {
            const instance = @fieldParentPtr(ObjInstance, "obj", object);
            freeTable(allocator, &instance.fields);
            FREE(allocator, ObjInstance, object);
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

fn markRoots(allocator: Allocator) void {
    var slot = @ptrCast([*]Value, &vm.vm.stack);
    while (@ptrToInt(slot) < @ptrToInt(vm.vm.stack_top)) : (slot += 1) {
        markValue(allocator, slot[0]);
    }

    for (vm.vm.frames[0..vm.vm.frame_count]) |frame| {
        markObject(allocator, &frame.closure.obj);
    }

    var upvalue = vm.vm.open_upvalues;
    while (upvalue != null) : (upvalue = upvalue.?.next) {
        markObject(allocator, &upvalue.?.obj);
    }

    markTable(allocator, &vm.vm.globals);

    markCompilerRoots(allocator);
}

fn traceReferences(allocator: Allocator) void {
    while (vm.vm.gray_count > 0) {
        vm.vm.gray_count -= 1;
        const object = vm.vm.gray_stack.?[vm.vm.gray_count];
        blackenObject(allocator, object);
    }
}

fn sweep(allocator: Allocator) void {
    var previous: ?*Obj = null;
    var object_ = vm.vm.objects;
    while (object_) |object| {
        if (object.is_marked) {
            object.is_marked = false;
            previous = object;
            object_ = object.next;
        } else {
            const unreached = object;
            object_ = object.next;
            if (previous != null) {
                previous.?.next = object_;
            } else {
                vm.vm.objects = object_;
            }

            freeObject(allocator, unreached);
        }
    }
}

fn collectGarbage(allocator: Allocator) void {
    var before: usize = undefined;
    if (DEBUG_LOG_GC) {
        const stdout = std.io.getStdOut().writer();
        stdout.writeAll("-- gc begin\n") catch unreachable;
        before = vm.vm.bytes_allocated;
    }

    markRoots(allocator);
    traceReferences(allocator);
    tableRemoveWhite(&vm.vm.strings);
    sweep(allocator);

    vm.vm.next_gc = vm.vm.bytes_allocated * GC_HEAP_GROW_FACTOR;

    if (DEBUG_LOG_GC) {
        const stdout = std.io.getStdOut().writer();
        stdout.writeAll("-- gc end\n") catch unreachable;
        stdout.print(
            "   collected {} bytes (from {} to {}) next at {}\n",
            .{ before - vm.vm.bytes_allocated, before, vm.vm.bytes_allocated, vm.vm.next_gc },
        ) catch unreachable;
    }
}

pub fn freeObjects(allocator: Allocator) void {
    var object = vm.vm.objects;
    while (object) |obj| {
        const next = obj.next;
        freeObject(allocator, obj);
        object = next;
    }

    if (vm.vm.gray_stack) |gray_stack| {
        allocator.free(gray_stack);
    }
}
