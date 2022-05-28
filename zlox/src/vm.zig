const std = @import("std");
const chk = @import("./chunk.zig");
const Chunk = chk.Chunk;
const OpCode = chk.OpCode;
const DEBUG_TRACE_EXECUTION = @import("./common.zig").DEBUG_TRACE_EXECUTION;
const disassembleInstruction = @import("./debug.zig").disassembleInstruction;
const v = @import("./value.zig");
const Value = v.Value;
const printValue = v.printValue;

pub const VM = struct {
    chunk: *Chunk,
    ip: *u8,
};

const InterpretResult = enum {
    ok,
    compile_error,
    runtime_error,
};

var vm: VM = undefined;

pub fn initVM() void {}

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
            _ = try disassembleInstruction(vm.chunk, @ptrToInt(vm.ip) - @ptrToInt(vm.chunk.code.?.ptr));
        }

        const instruction = @intToEnum(OpCode, READ_BYTE());
        switch (instruction) {
            .op_constant => {
                const constant = READ_CONSTANT();
                try printValue(constant);
                try stdout.writeByte('\n');
            },
            .op_return => return .ok,
        }
    }
}

pub fn interpret(chunk: *Chunk) !InterpretResult {
    vm.chunk = chunk;
    vm.ip = @ptrCast(*u8, vm.chunk.code.?.ptr);
    return run();
}
