const std = @import("std");
const Allocator = std.mem.Allocator;

const chk = @import("./chunk.zig");
const OpCode = chk.OpCode;

const compile = @import("./compiler.zig").compile;
const common = @import("./common.zig");
const DEBUG_TRACE_EXECUTION = common.DEBUG_TRACE_EXECUTION;
const U8_COUNT = common.U8_COUNT;
const disassembleInstruction = @import("./debug.zig").disassembleInstruction;

const memory = @import("./memory.zig");
const ALLOCATE = memory.ALLOCATE;
const freeObjects = memory.freeObjects;

const o = @import("./object.zig");
const NativeFn = o.NativeFn;
const Obj = o.Obj;
const ObjClass = o.ObjClass;
const ObjClosure = o.ObjClosure;
const ObjFunction = o.ObjFunction;
const ObjString = o.ObjString;
const ObjUpvalue = o.ObjUpvalue;
const copyString = o.copyString;
const newBoundMethod = o.newBoundMethod;
const newClass = o.newClass;
const newClosure = o.newClosure;
const newInstance = o.newInstance;
const newNative = o.newNative;
const newUpvalue = o.newUpvalue;
const takeString = o.takeString;
const AS_BOUND_METHOD = o.AS_BOUND_METHOD;
const AS_CLASS = o.AS_CLASS;
const AS_CLOSURE = o.AS_CLOSURE;
const AS_FUNCTION = o.AS_FUNCTION;
const AS_INSTANCE = o.AS_INSTANCE;
const AS_NATIVE = o.AS_NATIVE;
const AS_STRING = o.AS_STRING;
const IS_CLASS = o.IS_CLASS;
const IS_INSTANCE = o.IS_INSTANCE;
const IS_STRING = o.IS_STRING;
const OBJ_TYPE = o.OBJ_TYPE;

const table = @import("./table.zig");
const Table = table.Table;
const initTable = table.initTable;
const freeTable = table.freeTable;
const tableDelete = table.tableDelete;
const tableAddAll = table.tableAddAll;
const tableGet = table.tableGet;
const tableSet = table.tableSet;

const v = @import("./value.zig");
const Value = v.Value;
const printValue = v.printValue;
const valuesEqual = v.valuesEqual;
const AS_BOOL = v.AS_BOOL;
const AS_NUMBER = v.AS_NUMBER;
const BOOL_VAL = v.BOOL_VAL;
const IS_BOOL = v.IS_BOOL;
const IS_NIL = v.IS_NIL;
const IS_NUMBER = v.IS_NUMBER;
const IS_OBJ = v.IS_OBJ;
const NIL_VAL = v.NIL_VAL;
const NUMBER_VAL = v.NUMBER_VAL;
const OBJ_VAL = v.OBJ_VAL;

const FRAMES_MAX = 64;
const STACK_MAX = FRAMES_MAX + U8_COUNT;

const CallFrame = struct {
    closure: *ObjClosure,
    ip: [*]u8,
    slots: [*]Value,
};

pub const VM = struct {
    frames: [FRAMES_MAX]CallFrame,
    frame_count: usize,

    stack: [STACK_MAX]Value,
    stack_top: [*]Value,
    globals: Table,
    strings: Table,
    init_string: ?*ObjString,
    open_upvalues: ?*ObjUpvalue,

    bytes_allocated: usize,
    next_gc: usize,
    objects: ?*Obj,
    gray_count: usize,
    gray_capacity: usize,
    gray_stack: ?[]*Obj,
};

const InterpretResult = enum {
    ok,
    compile_error,
    runtime_error,
};

pub var vm: VM = undefined;

fn clockNative(_: u8, _: [*]Value) Value {
    var timespec: std.os.timespec = undefined;
    std.os.clock_gettime(std.os.CLOCK.PROCESS_CPUTIME_ID, &timespec) catch unreachable;
    const clocks_per_second = 1000000;
    const clocks = timespec.tv_sec * 1000000 + @divFloor(timespec.tv_nsec, 1000);
    return NUMBER_VAL(@intToFloat(f64, clocks) / clocks_per_second);
}

fn resetStack() void {
    vm.stack_top = &vm.stack;
    vm.frame_count = 0;
    vm.open_upvalues = null;
}

const stderr = std.io.getStdErr().writer();

fn runtimeError(comptime format: []const u8, args: anytype) void {
    stderr.print(format, args) catch unreachable;
    stderr.writeByte('\n') catch unreachable;

    var i: usize = vm.frame_count;
    while (i > 0) {
        i -= 1;
        const frame = &vm.frames[i];
        const function = frame.closure.function;
        const instruction = @ptrToInt(frame.ip) - @ptrToInt(function.chunk.code.?.ptr) - 1;
        stderr.print("[line {d}] in ", .{function.chunk.lines.?[instruction]}) catch unreachable;
        if (function.name) |name| {
            stderr.print("{s}()\n", .{name.chars[0..name.length]}) catch unreachable;
        } else {
            stderr.writeAll("script\n") catch unreachable;
        }
    }

    resetStack();
}

fn defineNative(allocator: Allocator, name: []const u8, function: NativeFn) void {
    push(OBJ_VAL(&copyString(allocator, name.ptr, name.len).obj));
    push(OBJ_VAL(&newNative(allocator, function).obj));
    _ = tableSet(allocator, &vm.globals, AS_STRING(vm.stack[0]), vm.stack[1]);
    _ = pop();
    _ = pop();
}

pub fn initVM(allocator: Allocator) void {
    resetStack();
    vm.objects = null;
    vm.bytes_allocated = 0;
    vm.next_gc = 1024 * 1024;

    vm.gray_count = 0;
    vm.gray_capacity = 0;
    vm.gray_stack = null;

    initTable(&vm.globals);
    initTable(&vm.strings);

    vm.init_string = null;
    vm.init_string = copyString(allocator, "init", 4);

    defineNative(allocator, "clock", clockNative);
}

pub fn freeVM(allocator: Allocator) void {
    freeTable(allocator, &vm.globals);
    freeTable(allocator, &vm.strings);
    vm.init_string = null;
    freeObjects(allocator);
}

fn READ_BYTE(frame: *CallFrame) u8 {
    const instruction = frame.ip[0];
    frame.ip += 1;
    return instruction;
}

fn READ_CONSTANT(frame: *CallFrame) Value {
    return frame.closure.function.chunk.constants.values.?[READ_BYTE(frame)];
}

fn READ_SHORT(frame: *CallFrame) u16 {
    const first = frame.ip[0];
    const second = frame.ip[1];
    frame.ip += 2;
    return (@as(u16, first) << 8) | second;
}

fn READ_STRING(frame: *CallFrame) *ObjString {
    return AS_STRING(READ_CONSTANT(frame));
}

fn run(allocator: Allocator) !InterpretResult {
    var frame = &vm.frames[vm.frame_count - 1];

    const stdout = std.io.getStdOut().writer();
    while (true) {
        if (DEBUG_TRACE_EXECUTION) {
            try stdout.writeAll("          ");
            var slot: [*]Value = &vm.stack;
            while (@ptrToInt(slot) < @ptrToInt(vm.stack_top)) : (slot += 1) {
                try stdout.writeAll("[ ");
                try printValue(slot[0]);
                try stdout.writeAll(" ]");
            }
            try stdout.writeByte('\n');
            _ = try disassembleInstruction(&frame.closure.function.chunk, @ptrToInt(frame.ip) - @ptrToInt(frame.closure.function.chunk.code.?.ptr));
        }

        const instruction = @intToEnum(OpCode, READ_BYTE(frame));
        switch (instruction) {
            .op_constant => {
                const constant = READ_CONSTANT(frame);
                push(constant);
            },
            .op_nil => push(NIL_VAL),
            .op_true => push(BOOL_VAL(true)),
            .op_false => push(BOOL_VAL(false)),
            .op_pop => _ = pop(),
            .op_get_local => {
                const slot = READ_BYTE(frame);
                push(frame.slots[slot]);
            },
            .op_set_local => {
                const slot = READ_BYTE(frame);
                frame.slots[slot] = peek(0);
            },
            .op_get_global => {
                const name = READ_STRING(frame);
                var value: Value = undefined;
                if (!tableGet(&vm.globals, name, &value)) {
                    runtimeError("Undefined variable '{s}'.", .{name.chars[0..name.length]});
                    return .runtime_error;
                }
                push(value);
            },
            .op_define_global => {
                const name = READ_STRING(frame);
                _ = tableSet(allocator, &vm.globals, name, peek(0));
                _ = pop();
            },
            .op_set_global => {
                const name = READ_STRING(frame);
                if (tableSet(allocator, &vm.globals, name, peek(0))) {
                    _ = tableDelete(&vm.globals, name);
                    runtimeError("Undefined variable '{s}'.", .{name.chars[0..name.length]});
                    return .runtime_error;
                }
            },
            .op_get_upvalue => {
                const slot = READ_BYTE(frame);
                push(frame.closure.upvalues.?[slot].?.location.*);
            },
            .op_set_upvalue => {
                const slot = READ_BYTE(frame);
                frame.closure.upvalues.?[slot].?.location.* = peek(0);
            },
            .op_get_property => {
                if (!IS_INSTANCE(peek(0))) {
                    runtimeError("Only instances have properties.", .{});
                    return .runtime_error;
                }

                const instance = AS_INSTANCE(peek(0));
                const name = READ_STRING(frame);

                var value: Value = undefined;
                if (tableGet(&instance.fields, name, &value)) {
                    _ = pop();
                    push(value);
                } else if (!bindMethod(allocator, instance.klass, name)) {
                    return .runtime_error;
                }
            },
            .op_set_property => {
                if (!IS_INSTANCE(peek(1))) {
                    runtimeError("Only instances have fields.", .{});
                    return .runtime_error;
                }

                const instance = AS_INSTANCE(peek(1));
                _ = tableSet(allocator, &instance.fields, READ_STRING(frame), peek(0));
                const value = pop();
                _ = pop();
                push(value);
            },
            .op_get_super => {
                const name = READ_STRING(frame);
                const superclass = AS_CLASS(pop());

                if (!bindMethod(allocator, superclass, name)) {
                    return .runtime_error;
                }
            },
            .op_equal => {
                const b = pop();
                const a = pop();
                push(BOOL_VAL(valuesEqual(a, b)));
            },
            .op_greater => {
                if (!IS_NUMBER(peek(0)) or !IS_NUMBER(peek(1))) {
                    runtimeError("Operands must be numbers.", .{});
                    return .runtime_error;
                }
                const b = AS_NUMBER(pop());
                const a = AS_NUMBER(pop());
                push(BOOL_VAL(a > b));
            },
            .op_less => {
                if (!IS_NUMBER(peek(0)) or !IS_NUMBER(peek(1))) {
                    runtimeError("Operands must be numbers.", .{});
                    return .runtime_error;
                }
                const b = AS_NUMBER(pop());
                const a = AS_NUMBER(pop());
                push(BOOL_VAL(a < b));
            },
            .op_add => {
                if (IS_STRING(peek(0)) and IS_STRING(peek(1))) {
                    concatenate(allocator);
                } else if (IS_NUMBER(peek(0)) and IS_NUMBER(peek(1))) {
                    const b = AS_NUMBER(pop());
                    const a = AS_NUMBER(pop());
                    push(NUMBER_VAL(a + b));
                } else {
                    runtimeError("Operands must be numbers.", .{});
                    return .runtime_error;
                }
            },
            .op_subtract => {
                if (!IS_NUMBER(peek(0)) or !IS_NUMBER(peek(1))) {
                    runtimeError("Operands must be numbers.", .{});
                    return .runtime_error;
                }
                const b = AS_NUMBER(pop());
                const a = AS_NUMBER(pop());
                push(NUMBER_VAL(a - b));
            },
            .op_multiply => {
                if (!IS_NUMBER(peek(0)) or !IS_NUMBER(peek(1))) {
                    runtimeError("Operands must be numbers.", .{});
                    return .runtime_error;
                }
                const b = AS_NUMBER(pop());
                const a = AS_NUMBER(pop());
                push(NUMBER_VAL(a * b));
            },
            .op_divide => {
                if (!IS_NUMBER(peek(0)) or !IS_NUMBER(peek(1))) {
                    runtimeError("Operands must be numbers.", .{});
                    return .runtime_error;
                }
                const b = AS_NUMBER(pop());
                const a = AS_NUMBER(pop());
                push(NUMBER_VAL(a / b));
            },
            .op_not => push(BOOL_VAL(isFalsey(pop()))),
            .op_negate => {
                if (!IS_NUMBER(peek(0))) {
                    runtimeError("Operand must be a number.", .{});
                    return .runtime_error;
                }
                push(NUMBER_VAL(-AS_NUMBER(pop())));
            },
            .op_print => {
                try printValue(pop());
                try stdout.writeByte('\n');
            },
            .op_jump => {
                const offset = READ_SHORT(frame);
                frame.ip += offset;
            },
            .op_jump_if_false => {
                const offset = READ_SHORT(frame);
                if (isFalsey(peek(0))) frame.ip += offset;
            },
            .op_loop => {
                const offset = READ_SHORT(frame);
                frame.ip -= offset;
            },
            .op_call => {
                const arg_count = READ_BYTE(frame);
                if (!callValue(allocator, peek(arg_count), arg_count)) {
                    return .runtime_error;
                }
                frame = &vm.frames[vm.frame_count - 1];
            },
            .op_class => {
                push(OBJ_VAL(&newClass(allocator, READ_STRING(frame)).obj));
            },
            .op_inherit => {
                const superclass = peek(1);
                if (!IS_CLASS(superclass)) {
                    runtimeError("Superclass must be a class.", .{});
                    return .runtime_error;
                }

                const subclass = AS_CLASS(peek(0));
                tableAddAll(allocator, &AS_CLASS(superclass).methods, &subclass.methods);
                _ = pop();
            },
            .op_method => {
                defineMethod(allocator, READ_STRING(frame));
            },
            .op_invoke => {
                const method = READ_STRING(frame);
                const arg_count = READ_BYTE(frame);
                if (!invoke(allocator, method, arg_count)) {
                    return .runtime_error;
                }
                frame = &vm.frames[vm.frame_count - 1];
            },
            .op_closure => {
                const function = AS_FUNCTION(READ_CONSTANT(frame));
                const closure = newClosure(allocator, function);
                push(OBJ_VAL(&closure.obj));
                var i: usize = 0;
                while (i < closure.upvalue_count) : (i += 1) {
                    const is_local = READ_BYTE(frame);
                    const index = READ_BYTE(frame);
                    if (is_local == 1) {
                        closure.upvalues.?[i] = captureUpvalue(allocator, @ptrCast(*Value, frame.slots + index));
                    } else {
                        closure.upvalues.?[i] = frame.closure.upvalues.?[index];
                    }
                }
            },
            .op_close_upvalue => {
                closeUpvalues(@ptrCast(*Value, vm.stack_top - 1));
                _ = pop();
            },
            .op_return => {
                const result = pop();
                closeUpvalues(&frame.slots[0]);
                vm.frame_count -= 1;
                if (vm.frame_count == 0) {
                    _ = pop();
                    return .ok;
                }

                vm.stack_top = frame.slots;
                push(result);
                frame = &vm.frames[vm.frame_count - 1];
            },
        }
    }
}

pub fn interpret(allocator: Allocator, source: []const u8) !InterpretResult {
    const function = compile(allocator, source) orelse return InterpretResult.compile_error;

    push(OBJ_VAL(&function.obj));
    const closure = newClosure(allocator, function);
    _ = pop();
    push(OBJ_VAL(&closure.obj));
    _ = call(closure, 0);

    return run(allocator);
}

pub fn push(value: Value) void {
    vm.stack_top[0] = value;
    vm.stack_top += 1;
}

pub fn pop() Value {
    vm.stack_top -= 1;
    return vm.stack_top[0];
}

fn peek(distance: usize) Value {
    const ptr = vm.stack_top - 1 - distance;
    return ptr[0];
}

fn call(closure: *ObjClosure, arg_count: u8) bool {
    if (arg_count != closure.function.arity) {
        runtimeError("Expected {d} arguments but got {d}.", .{ closure.function.arity, arg_count });
        return false;
    }

    if (vm.frame_count == FRAMES_MAX) {
        runtimeError("Stack overflow.", .{});
        return false;
    }

    const frame = &vm.frames[vm.frame_count];
    vm.frame_count += 1;
    frame.closure = closure;
    frame.ip = closure.function.chunk.code.?.ptr;
    frame.slots = vm.stack_top - arg_count - 1;
    return true;
}

fn callValue(allocator: Allocator, callee: Value, arg_count: u8) bool {
    if (IS_OBJ(callee)) {
        switch (OBJ_TYPE(callee)) {
            .bound_method => {
                const bound = AS_BOUND_METHOD(callee);
                const stack_pos = vm.stack_top - arg_count - 1;
                stack_pos[0] = bound.receiver;
                return call(bound.method, arg_count);
            },
            .class => {
                const klass = AS_CLASS(callee);
                const stack_pos = vm.stack_top - arg_count - 1;
                stack_pos[0] = OBJ_VAL(&newInstance(allocator, klass).obj);
                var initializer: Value = undefined;
                if (tableGet(&klass.methods, vm.init_string.?, &initializer)) {
                    return call(AS_CLOSURE(initializer), arg_count);
                } else if (arg_count != 0) {
                    runtimeError("Expected 0 arguments but got {d}.", .{arg_count});
                    return false;
                }
                return true;
            },
            .closure => {
                return call(AS_CLOSURE(callee), arg_count);
            },
            .native => {
                const native = AS_NATIVE(callee);
                const result = native(arg_count, vm.stack_top - arg_count);
                vm.stack_top -= arg_count + 1;
                push(result);
                return true;
            },
            else => {},
        }
    }
    runtimeError("Can only call functions and classes.", .{});
    return false;
}

fn invokeFromClass(klass: *ObjClass, name: *ObjString, arg_count: u8) bool {
    var method: Value = undefined;
    if (!tableGet(&klass.methods, name, &method)) {
        runtimeError("Undefined property '{s}'.", .{name.chars[0..name.length]});
        return false;
    }
    return call(AS_CLOSURE(method), arg_count);
}

fn invoke(allocator: Allocator, name: *ObjString, arg_count: u8) bool {
    const receiver = peek(arg_count);

    if (!IS_INSTANCE(receiver)) {
        runtimeError("Only instances have methods.", .{});
        return false;
    }

    const instance = AS_INSTANCE(receiver);

    var value: Value = undefined;
    if (tableGet(&instance.fields, name, &value)) {
        const stack_pos = vm.stack_top - arg_count - 1;
        stack_pos[0] = value;
        return callValue(allocator, value, arg_count);
    }

    return invokeFromClass(instance.klass, name, arg_count);
}

fn bindMethod(allocator: Allocator, klass: *ObjClass, name: *ObjString) bool {
    var method: Value = undefined;
    if (!tableGet(&klass.methods, name, &method)) {
        runtimeError("Undefined property '{s}'.", .{name.chars[0..name.length]});
        return false;
    }

    const bound = newBoundMethod(allocator, peek(0), AS_CLOSURE(method));
    _ = pop();
    push(OBJ_VAL(&bound.obj));
    return true;
}

fn captureUpvalue(allocator: Allocator, local: *Value) *ObjUpvalue {
    var prev_upvalue: ?*ObjUpvalue = null;
    var upvalue = vm.open_upvalues;
    while (upvalue != null and @ptrToInt(upvalue.?.location) > @ptrToInt(local)) : (upvalue = upvalue.?.next) {
        prev_upvalue = upvalue;
    }

    if (upvalue != null and upvalue.?.location == local) {
        return upvalue.?;
    }

    const created_upvalue = newUpvalue(allocator, local);

    if (prev_upvalue == null) {
        vm.open_upvalues = created_upvalue;
    } else {
        prev_upvalue.?.next = created_upvalue;
    }
    return created_upvalue;
}

fn closeUpvalues(last_: *Value) void {
    var last = last_;
    while (vm.open_upvalues != null and @ptrToInt(vm.open_upvalues.?.location) >= @ptrToInt(last)) {
        const upvalue = @ptrCast(*ObjUpvalue, vm.open_upvalues.?);
        upvalue.closed = upvalue.location.*;
        upvalue.location = &upvalue.closed;
        vm.open_upvalues = upvalue.next;
    }
}

fn defineMethod(allocator: Allocator, name: *ObjString) void {
    const method = peek(0);
    const klass = AS_CLASS(peek(1));
    _ = tableSet(allocator, &klass.methods, name, method);
    _ = pop();
}

fn isFalsey(value: Value) bool {
    return IS_NIL(value) or (IS_BOOL(value) and !AS_BOOL(value));
}

fn concatenate(allocator: Allocator) void {
    const b = AS_STRING(peek(0));
    const a = AS_STRING(peek(1));

    const length = a.length + b.length;
    const chars = ALLOCATE(allocator, u8, length).?;
    std.mem.copy(u8, chars[0..a.length], a.chars[0..a.length]);
    std.mem.copy(u8, chars[a.length..], b.chars[0..b.length]);

    const result = takeString(allocator, chars.ptr, length);
    _ = pop();
    _ = pop();
    push(OBJ_VAL(&result.obj));
}
