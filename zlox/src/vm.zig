const std = @import("std");
const chk = @import("./chunk.zig");
const Chunk = chk.Chunk;
const OpCode = chk.OpCode;
const DEBUG_TRACE_EXECUTION = @import("./common.zig").DEBUG_TRACE_EXECUTION;
const disassembleInstruction = @import("./debug.zig").disassembleInstruction;
const v = @import("./value.zig");
const Value = v.Value;
const printValue = v.printValue;

const STACK_MAX = 256;

pub const VM = struct {
    chunk: *Chunk,
    ip: *u8,
    stack: [STACK_MAX]Value,
    stack_top: *Value,
};

const InterpretResult = enum {
    ok,
    compile_error,
    runtime_error,
};

var vm: VM = undefined;

fn resetStack() void {
    vm.stack_top = &vm.stack[0];
}

pub fn initVM() void {
    resetStack();
}

pub fn freeVM() void {}

fn READ_BYTE() u8 {
    const instruction = vm.ip.*;
    vm.ip = @intToPtr(*u8, @ptrToInt(vm.ip) + 1);
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
            var slot = &vm.stack[0];
            while (@ptrToInt(slot) < @ptrToInt(vm.stack_top)) : (slot = @intToPtr(*Value, @ptrToInt(slot) + 8)) {
                try stdout.writeAll("[ ");
                try printValue(slot.*);
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
            .op_negate => push(-pop()),
            .op_return => {
                try printValue(pop());
                try stdout.writeByte('\n');
                return .ok;
            },
        }
    }
}

pub fn interpret(chunk: *Chunk) !InterpretResult {
    vm.chunk = chunk;
    vm.ip = @ptrCast(*u8, vm.chunk.code.?.ptr);
    return run();
}

fn push(value: Value) void {
    vm.stack_top.* = value;
    vm.stack_top = @intToPtr(*Value, @ptrToInt(vm.stack_top) + 8);
}

fn pop() Value {
    vm.stack_top = @intToPtr(*Value, @ptrToInt(vm.stack_top) - 8);
    return vm.stack_top.*;
}
