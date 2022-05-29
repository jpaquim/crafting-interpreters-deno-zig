const std = @import("std");
const Allocator = std.mem.Allocator;

const chk = @import("./chunk.zig");
const Chunk = chk.Chunk;
const OpCode = chk.OpCode;
const freeChunk = chk.freeChunk;
const initChunk = chk.initChunk;

const compile = @import("./compiler.zig").compile;
const DEBUG_TRACE_EXECUTION = @import("./common.zig").DEBUG_TRACE_EXECUTION;
const disassembleInstruction = @import("./debug.zig").disassembleInstruction;

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
const NIL_VAL = v.NIL_VAL;
const NUMBER_VAL = v.NUMBER_VAL;

const STACK_MAX = 256;

pub const VM = struct {
    chunk: *Chunk,
    ip: [*]u8,
    stack: [STACK_MAX]Value,
    stack_top: [*]Value,
};

const InterpretResult = enum {
    ok,
    compile_error,
    runtime_error,
};

var vm: VM = undefined;

fn resetStack() void {
    vm.stack_top = &vm.stack;
}

const stderr = std.io.getStdErr().writer();

fn runtimeError(comptime format: []const u8, args: anytype) void {
    stderr.print(format, args) catch unreachable;
    stderr.writeByte('\n') catch unreachable;

    const instruction = @ptrToInt(vm.ip) - @ptrToInt(vm.chunk.code.?.ptr) - 1;
    const line = vm.chunk.lines.?[instruction];
    stderr.print("[line {d}] in script\n", .{line}) catch unreachable;
    resetStack();
}

pub fn initVM() void {
    resetStack();
}

pub fn freeVM() void {}

fn READ_BYTE() u8 {
    const instruction = vm.ip[0];
    vm.ip += 1;
    return instruction;
}

fn READ_CONSTANT() Value {
    return vm.chunk.constants.values.?[READ_BYTE()];
}

fn run() !InterpretResult {
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
            _ = try disassembleInstruction(vm.chunk, @ptrToInt(vm.ip) - @ptrToInt(vm.chunk.code.?.ptr));
        }

        const instruction = @intToEnum(OpCode, READ_BYTE());
        switch (instruction) {
            .op_constant => {
                const constant = READ_CONSTANT();
                push(constant);
            },
            .op_nil => push(NIL_VAL),
            .op_true => push(BOOL_VAL(true)),
            .op_false => push(BOOL_VAL(false)),
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
                if (!IS_NUMBER(peek(0)) or !IS_NUMBER(peek(1))) {
                    runtimeError("Operands must be numbers.", .{});
                    return .runtime_error;
                }
                const b = AS_NUMBER(pop());
                const a = AS_NUMBER(pop());
                push(NUMBER_VAL(a + b));
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
            .op_return => {
                try printValue(pop());
                try stdout.writeByte('\n');
                return .ok;
            },
        }
    }
}

pub fn interpret(allocator: Allocator, source: []const u8) !InterpretResult {
    var chunk: Chunk = undefined;
    initChunk(&chunk);

    defer freeChunk(allocator, &chunk);

    if (!try compile(allocator, source, &chunk)) return .compile_error;

    vm.chunk = &chunk;
    vm.ip = vm.chunk.code.?.ptr;

    const result = try run();

    return result;
}

fn push(value: Value) void {
    vm.stack_top[0] = value;
    vm.stack_top += 1;
}

fn pop() Value {
    vm.stack_top -= 1;
    return vm.stack_top[0];
}

fn peek(distance: usize) Value {
    const ptr = vm.stack_top - 1 - distance;
    return ptr[0];
}

fn isFalsey(value: Value) bool {
    return IS_NIL(value) or (IS_BOOL(value) and !AS_BOOL(value));
}
