const std = @import("std");
const Allocator = std.mem.Allocator;

const chk = @import("./chunk.zig");
const Chunk = chk.Chunk;
const OpCode = chk.OpCode;
const addConstant = chk.addConstant;
const writeChunk = chk.writeChunk;

const DEBUG_PRINT_CODE = @import("./common.zig").DEBUG_PRINT_CODE;
const debug = @import("./debug.zig");
const disassembleChunk = debug.disassembleChunk;

const scanner = @import("./scanner.zig");
const Token = scanner.Token;
const TokenType = scanner.TokenType;
const initScanner = scanner.initScanner;
const scanToken = scanner.scanToken;

const v = @import("./value.zig");
const Value = v.Value;
const NUMBER_VAL = v.NUMBER_VAL;

const stdout = std.io.getStdOut().writer();
const stderr = std.io.getStdErr().writer();

const Parser = struct {
    current: Token,
    previous: Token,
    had_error: bool,
    panic_mode: bool,
};

const Precedence = enum {
    NONE,
    ASSIGNMENT, // =
    OR, // or
    AND, // and
    EQUALITY, // == !=
    COMPARISON, // < > <= >=
    TERM, // + -
    FACTOR, // * /
    UNARY, // ! -
    CALL, // . ()
    PRIMARY,
};

const ParseFn = fn (allocator: Allocator) void;

const ParseRule = struct {
    prefix: ?ParseFn = null,
    infix: ?ParseFn = null,
    precedence: Precedence,
};

var parser: Parser = undefined;
var compiling_chunk: *Chunk = undefined;

fn currentChunk() *Chunk {
    return compiling_chunk;
}

fn errorAt(token: *Token, message: []const u8) void {
    if (parser.panic_mode) return;
    parser.panic_mode = true;
    stderr.print("[line {d}] Error", .{token.line}) catch unreachable;

    if (token.t_type == .EOF) {
        stderr.writeAll(" at end") catch unreachable;
    } else if (token.t_type == .ERROR) {} else {
        stderr.print(" at '{s}'", .{token.start[0..token.length]}) catch unreachable;
    }

    stderr.print(": {s}\n", .{message}) catch unreachable;
    parser.had_error = true;
}

fn err(message: []const u8) void {
    errorAt(&parser.previous, message);
}

fn errorAtCurrent(message: []const u8) void {
    errorAt(&parser.current, message);
}

fn advance() void {
    parser.previous = parser.current;

    while (true) {
        parser.current = scanToken();
        if (parser.current.t_type != .ERROR) break;

        errorAtCurrent(parser.current.start[0..parser.current.length]);
    }
}

fn consume(t_type: TokenType, message: []const u8) void {
    if (parser.current.t_type == t_type) {
        advance();
        return;
    }

    errorAtCurrent(message);
}

fn emitByte(allocator: Allocator, byte: u8) void {
    writeChunk(allocator, currentChunk(), byte, parser.previous.line);
}

fn emitBytes(allocator: Allocator, byte1: u8, byte2: u8) void {
    emitByte(allocator, byte1);
    emitByte(allocator, byte2);
}

fn emitReturn(allocator: Allocator) void {
    emitByte(allocator, @enumToInt(OpCode.op_return));
}

fn makeConstant(allocator: Allocator, value: Value) u8 {
    const constant = addConstant(allocator, currentChunk(), value);
    if (constant > std.math.maxInt(u8)) {
        err("Too many constants in one chunk.");
        return 0;
    }

    return @intCast(u8, constant);
}

fn emitConstant(allocator: Allocator, value: Value) void {
    emitBytes(allocator, @enumToInt(OpCode.op_constant), makeConstant(allocator, value));
}

fn endCompiler(allocator: Allocator) !void {
    emitReturn(allocator);
    if (DEBUG_PRINT_CODE) {
        try disassembleChunk(currentChunk(), "code");
    }
}

fn binary(allocator: Allocator) void {
    const operator_type = parser.previous.t_type;
    const rule = getRule(operator_type);
    parsePrecedence(allocator, @intToEnum(Precedence, @enumToInt(rule.precedence) + 1));

    switch (operator_type) {
        .PLUS => emitByte(allocator, @enumToInt(OpCode.op_add)),
        .MINUS => emitByte(allocator, @enumToInt(OpCode.op_subtract)),
        .STAR => emitByte(allocator, @enumToInt(OpCode.op_multiply)),
        .SLASH => emitByte(allocator, @enumToInt(OpCode.op_divide)),
        else => unreachable,
    }
}

fn grouping(allocator: Allocator) void {
    expression(allocator);
    consume(.RIGHT_PAREN, "Expect ')' after expression.");
}

fn expression(allocator: Allocator) void {
    parsePrecedence(allocator, .ASSIGNMENT);
}

fn number(allocator: Allocator) void {
    const value = std.fmt.parseFloat(f64, parser.previous.start[0..parser.previous.length]) catch unreachable;
    emitConstant(allocator, NUMBER_VAL(value));
}

fn unary(allocator: Allocator) void {
    const operator_type = parser.previous.t_type;

    parsePrecedence(allocator, .UNARY);

    switch (operator_type) {
        .MINUS => emitByte(allocator, @enumToInt(OpCode.op_negate)),
        else => unreachable,
    }
}

const rules = [_]ParseRule{
    .{ .prefix = grouping, .precedence = .NONE }, // LEFT_PAREN
    .{ .precedence = .NONE }, // RIGHT_PAREN
    .{ .precedence = .NONE }, // LEFT_BRACE
    .{ .precedence = .NONE }, // RIGHT_BRACE
    .{ .precedence = .NONE }, // COMMA
    .{ .precedence = .NONE }, // DOT
    .{ .prefix = unary, .infix = binary, .precedence = .TERM }, // MINUS
    .{ .infix = binary, .precedence = .TERM }, // PLUS
    .{ .precedence = .NONE }, // SEMICOLON
    .{ .infix = binary, .precedence = .FACTOR }, // SLASH
    .{ .infix = binary, .precedence = .FACTOR }, // STAR
    .{ .precedence = .NONE }, // BANG
    .{ .precedence = .NONE }, // BANG_EQUAL
    .{ .precedence = .NONE }, // EQUAL
    .{ .precedence = .NONE }, // EQUAL_EQUAL
    .{ .precedence = .NONE }, // GREATER
    .{ .precedence = .NONE }, // GREATER_EQUAL
    .{ .precedence = .NONE }, // LESS
    .{ .precedence = .NONE }, // LESS_EQUAL
    .{ .precedence = .NONE }, // IDENTIFIER
    .{ .precedence = .NONE }, // STRING
    .{ .prefix = number, .precedence = .NONE }, // NUMBER
    .{ .precedence = .NONE }, // AND
    .{ .precedence = .NONE }, // CLASS
    .{ .precedence = .NONE }, // ELSE
    .{ .precedence = .NONE }, // FALSE
    .{ .precedence = .NONE }, // FOR
    .{ .precedence = .NONE }, // FUN
    .{ .precedence = .NONE }, // IF
    .{ .precedence = .NONE }, // NIL
    .{ .precedence = .NONE }, // OR
    .{ .precedence = .NONE }, // PRINT
    .{ .precedence = .NONE }, // RETURN
    .{ .precedence = .NONE }, // SUPER
    .{ .precedence = .NONE }, // THIS
    .{ .precedence = .NONE }, // TRUE
    .{ .precedence = .NONE }, // VAR
    .{ .precedence = .NONE }, // WHILE
    .{ .precedence = .NONE }, // ERROR
    .{ .precedence = .NONE }, // EOF
};

fn parsePrecedence(allocator: Allocator, precedence: Precedence) void {
    advance();
    const prefix_rule = getRule(parser.previous.t_type).prefix;
    if (prefix_rule == null) {
        err("Expect expression.");
        return;
    }

    prefix_rule.?(allocator);

    while (@enumToInt(precedence) <= @enumToInt(getRule(parser.current.t_type).precedence)) {
        advance();
        const infix_rule = getRule(parser.previous.t_type).infix;
        infix_rule.?(allocator);
    }
}

fn getRule(t_type: TokenType) *const ParseRule {
    return &rules[@enumToInt(t_type)];
}

pub fn compile(allocator: Allocator, source: []const u8, chunk: *Chunk) !bool {
    initScanner(source);
    compiling_chunk = chunk;

    parser.had_error = false;
    parser.panic_mode = false;

    advance();
    expression(allocator);
    consume(.EOF, "Expect end of expression.");
    try endCompiler(allocator);
    return !parser.had_error;
}
