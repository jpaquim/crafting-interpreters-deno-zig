const std = @import("std");
const Allocator = std.mem.Allocator;

const chk = @import("./chunk.zig");
const Chunk = chk.Chunk;
const initChunk = chk.initChunk;

const common = @import("./common.zig");
const DEBUG_LOG_GC = common.DEBUG_LOG_GC;

const memory = @import("./memory.zig");
const ALLOCATE = memory.ALLOCATE;
const FREE_ARRAY = memory.FREE_ARRAY;
const reallocate = memory.reallocate;

const table = @import("./table.zig");
const Table = table.Table;
const initTable = table.initTable;
const tableFindString = table.tableFindString;
const tableSet = table.tableSet;

const v = @import("./value.zig");
const Value = v.Value;
const AS_OBJ = v.AS_OBJ;
const IS_OBJ = v.IS_OBJ;
const NIL_VAL = v.NIL_VAL;
const OBJ_VAL = v.OBJ_VAL;

const vm = @import("./vm.zig");
const push = vm.push;
const pop = vm.pop;

const ObjType = enum {
    bound_method,
    class,
    closure,
    function,
    instance,
    native,
    string,
    upvalue,
};

pub const Obj = struct {
    o_type: ObjType,
    is_marked: bool,
    next: ?*Obj,
};

pub const ObjFunction = struct {
    obj: Obj,
    arity: usize,
    upvalue_count: usize,
    chunk: Chunk,
    name: ?*ObjString,
};

pub const NativeFn = fn (arg_count: u8, args: [*]Value) Value;

pub const ObjNative = struct {
    obj: Obj,
    function: NativeFn,
};

pub const ObjString = struct {
    obj: Obj,
    length: usize,
    chars: [*]u8,
    hash: u32,
};

pub const ObjUpvalue = struct {
    obj: Obj,
    location: *Value,
    closed: Value,
    next: ?*ObjUpvalue,
};

pub const ObjClosure = struct {
    obj: Obj,
    function: *ObjFunction,
    upvalues: ?[*]?*ObjUpvalue,
    upvalue_count: usize,
};

pub const ObjClass = struct {
    obj: Obj,
    name: *ObjString,
    methods: Table,
};

pub const ObjInstance = struct {
    obj: Obj,
    klass: *ObjClass,
    fields: Table,
};

pub const ObjBoundMethod = struct {
    obj: Obj,
    receiver: Value,
    method: *ObjClosure,
};

pub fn OBJ_TYPE(value: Value) ObjType {
    return AS_OBJ(value).o_type;
}

pub fn IS_BOUND_METHOD(value: Value) bool {
    return isObjType(value, .bound_method);
}

pub fn IS_CLASS(value: Value) bool {
    return isObjType(value, .class);
}

pub fn IS_CLOSURE(value: Value) bool {
    return isObjType(value, .closure);
}

pub fn IS_FUNCTION(value: Value) bool {
    return isObjType(value, .function);
}

pub fn IS_INSTANCE(value: Value) bool {
    return isObjType(value, .instance);
}

pub fn IS_NATIVE(value: Value) bool {
    return isObjType(value, .native);
}

pub fn IS_STRING(value: Value) bool {
    return isObjType(value, .string);
}

pub fn AS_BOUND_METHOD(value: Value) *ObjBoundMethod {
    return @fieldParentPtr(ObjBoundMethod, "obj", AS_OBJ(value));
}

pub fn AS_CLASS(value: Value) *ObjClass {
    return @fieldParentPtr(ObjClass, "obj", AS_OBJ(value));
}

pub fn AS_CLOSURE(value: Value) *ObjClosure {
    return @fieldParentPtr(ObjClosure, "obj", AS_OBJ(value));
}

pub fn AS_FUNCTION(value: Value) *ObjFunction {
    return @fieldParentPtr(ObjFunction, "obj", AS_OBJ(value));
}

pub fn AS_INSTANCE(value: Value) *ObjInstance {
    return @fieldParentPtr(ObjInstance, "obj", AS_OBJ(value));
}

pub fn AS_NATIVE(value: Value) NativeFn {
    return @fieldParentPtr(ObjNative, "obj", AS_OBJ(value)).function;
}

pub fn AS_STRING(value: Value) *ObjString {
    return @fieldParentPtr(ObjString, "obj", AS_OBJ(value));
}

pub fn AS_CSTRING(value: Value) [*]const u8 {
    return @fieldParentPtr(ObjString, "obj", AS_OBJ(value)).chars;
}

fn ALLOCATE_OBJ(allocator: Allocator, comptime T: type, object_type: ObjType) *T {
    return @fieldParentPtr(T, "obj", allocateObject(allocator, @sizeOf(T), object_type));
}

fn allocateObject(allocator: Allocator, size: usize, o_type: ObjType) *Obj {
    const object = @ptrCast(*Obj, @alignCast(@alignOf(Obj), reallocate(
        allocator,
        null,
        0,
        size,
    ).?));
    object.o_type = o_type;
    object.is_marked = false;

    object.next = vm.vm.objects;
    vm.vm.objects = object;

    if (DEBUG_LOG_GC) {
        stdout.print("{*} allocate {} for {d}\n", .{ object, size, o_type }) catch unreachable;
    }

    return object;
}

pub fn newBoundMethod(allocator: Allocator, receiver: Value, method: *ObjClosure) *ObjBoundMethod {
    const bound = ALLOCATE_OBJ(allocator, ObjBoundMethod, .bound_method);
    bound.receiver = receiver;
    bound.method = method;
    return bound;
}

pub fn newClass(allocator: Allocator, name: *ObjString) *ObjClass {
    const klass = ALLOCATE_OBJ(allocator, ObjClass, .class);
    klass.name = name;
    initTable(&klass.methods);
    return klass;
}

pub fn newClosure(allocator: Allocator, function: *ObjFunction) *ObjClosure {
    const upvalues = ALLOCATE(allocator, ?*ObjUpvalue, function.upvalue_count);
    var i: usize = 0;
    while (i < function.upvalue_count) : (i += 1) {
        upvalues.?[i] = null;
    }

    const closure = ALLOCATE_OBJ(allocator, ObjClosure, .closure);
    closure.function = function;
    closure.upvalues = if (upvalues == null) null else upvalues.?.ptr;
    closure.upvalue_count = function.upvalue_count;
    return closure;
}

pub fn newFunction(allocator: Allocator) *ObjFunction {
    const function = ALLOCATE_OBJ(allocator, ObjFunction, .function);
    function.arity = 0;
    function.upvalue_count = 0;
    function.name = null;
    initChunk(&function.chunk);
    return function;
}

pub fn newInstance(allocator: Allocator, klass: *ObjClass) *ObjInstance {
    const instance = ALLOCATE_OBJ(allocator, ObjInstance, .instance);
    instance.klass = klass;
    initTable(&instance.fields);
    return instance;
}

pub fn newNative(allocator: Allocator, function: NativeFn) *ObjNative {
    const native = ALLOCATE_OBJ(allocator, ObjNative, .native);
    native.function = function;
    return native;
}

fn allocateString(allocator: Allocator, chars: [*]u8, length: usize, hash: u32) *ObjString {
    const string = ALLOCATE_OBJ(allocator, ObjString, .string);
    string.length = length;
    string.chars = chars;
    string.hash = hash;

    push(OBJ_VAL(&string.obj));
    _ = tableSet(allocator, &vm.vm.strings, string, NIL_VAL);
    _ = pop();

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

    const heapChars = ALLOCATE(allocator, u8, length + 1).?;
    std.mem.copy(u8, heapChars, chars[0..length]);
    return allocateString(allocator, heapChars.ptr, length, hash);
}

pub fn newUpvalue(allocator: Allocator, slot: *Value) *ObjUpvalue {
    const upvalue = ALLOCATE_OBJ(allocator, ObjUpvalue, .upvalue);
    upvalue.closed = NIL_VAL;
    upvalue.location = slot;
    upvalue.next = null;
    return upvalue;
}

const stdout = std.io.getStdOut().writer();

fn printFunction(function: *ObjFunction) !void {
    if (function.name == null) {
        try stdout.writeAll("<script>");
        return;
    }
    try stdout.print("<fn {s}>", .{function.name.?.chars[0..function.name.?.length]});
}

pub fn printObject(value: Value) !void {
    switch (OBJ_TYPE(value)) {
        .bound_method => try printFunction(AS_BOUND_METHOD(value).method.function),
        .class => {
            const name = AS_CLASS(value).name;
            try stdout.writeAll(name.chars[0..name.length]);
        },
        .closure => try printFunction(AS_CLOSURE(value).function),
        .function => try printFunction(AS_FUNCTION(value)),
        .instance => {
            const name = AS_INSTANCE(value).klass.name;
            try stdout.print("{s} instance", .{name.chars[0..name.length]});
        },
        .native => try stdout.writeAll("<native fn>"),
        .string => try stdout.writeAll(AS_CSTRING(value)[0..AS_STRING(value).length]),
        .upvalue => try stdout.writeAll("upvalue"),
        // .upvalue => unreachable,
    }
}

fn isObjType(value: Value, o_type: ObjType) bool {
    return IS_OBJ(value) and AS_OBJ(value).o_type == o_type;
}
