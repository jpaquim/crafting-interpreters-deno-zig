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

const object = @import("./object.zig");
const copyString = object.copyString;

const scanner = @import("./scanner.zig");
const Token = scanner.Token;
const TokenType = scanner.TokenType;
const initScanner = scanner.initScanner;
const scanToken = scanner.scanToken;

const v = @import("./value.zig");
const Value = v.Value;
const NUMBER_VAL = v.NUMBER_VAL;
const OBJ_VAL = v.OBJ_VAL;

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

fn check(t_type: TokenType) bool {
    return parser.current.t_type == t_type;
}

fn match(t_type: TokenType) bool {
    if (!check(t_type)) return false;
    advance();
    return true;
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
        .BANG_EQUAL => emitBytes(allocator, @enumToInt(OpCode.op_equal), @enumToInt(OpCode.op_not)),
        .EQUAL_EQUAL => emitByte(allocator, @enumToInt(OpCode.op_equal)),
        .GREATER => emitByte(allocator, @enumToInt(OpCode.op_greater)),
        .GREATER_EQUAL => emitBytes(allocator, @enumToInt(OpCode.op_less), @enumToInt(OpCode.op_not)),
        .LESS => emitByte(allocator, @enumToInt(OpCode.op_less)),
        .LESS_EQUAL => emitBytes(allocator, @enumToInt(OpCode.op_greater), @enumToInt(OpCode.op_not)),
        .PLUS => emitByte(allocator, @enumToInt(OpCode.op_add)),
        .MINUS => emitByte(allocator, @enumToInt(OpCode.op_subtract)),
        .STAR => emitByte(allocator, @enumToInt(OpCode.op_multiply)),
        .SLASH => emitByte(allocator, @enumToInt(OpCode.op_divide)),
        else => unreachable,
    }
}

fn literal(allocator: Allocator) void {
    switch (parser.previous.t_type) {
        .FALSE => emitByte(allocator, @enumToInt(OpCode.op_false)),
        .NIL => emitByte(allocator, @enumToInt(OpCode.op_nil)),
        .TRUE => emitByte(allocator, @enumToInt(OpCode.op_true)),
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

fn varDeclaration(allocator: Allocator) void {
    const global = parseVariable(allocator, "Expect variable name.");

    if (match(.EQUAL)) {
        expression(allocator);
    } else {
        emitByte(allocator, @enumToInt(OpCode.op_nil));
    }
    consume(.SEMICOLON, "Expect ';' after variable declaration.");

    defineVariable(allocator, global);
}

fn expressionStatement(allocator: Allocator) void {
    expression(allocator);
    consume(.SEMICOLON, "Expect ';' after expression.");
    emitByte(allocator, @enumToInt(OpCode.op_pop));
}

fn printStatement(allocator: Allocator) void {
    expression(allocator);
    consume(.SEMICOLON, "Expect ';' after value.");
    emitByte(allocator, @enumToInt(OpCode.op_print));
}

fn synchronize() void {
    parser.panic_mode = false;

    while (parser.current.t_type != .EOF) {
        if (parser.previous.t_type == .SEMICOLON) return;
        switch (parser.current.t_type) {
            .CLASS, .FUN, .VAR, .FOR, .IF, .WHILE, .PRINT, .RETURN => return,
            else => {},
        }

        advance();
    }
}

fn declaration(allocator: Allocator) void {
    if (match(.VAR)) {
        varDeclaration(allocator);
    } else {
        statement(allocator);
    }

    if (parser.panic_mode) synchronize();
}

fn statement(allocator: Allocator) void {
    if (match(.PRINT)) {
        printStatement(allocator);
    } else {
        expressionStatement(allocator);
    }
}

fn number(allocator: Allocator) void {
    const value = std.fmt.parseFloat(f64, parser.previous.start[0..parser.previous.length]) catch unreachable;
    emitConstant(allocator, NUMBER_VAL(value));
}

fn string(allocator: Allocator) void {
    emitConstant(allocator, OBJ_VAL(&copyString(allocator, parser.previous.start + 1, parser.previous.length - 2).obj));
}

fn unary(allocator: Allocator) void {
    const operator_type = parser.previous.t_type;

    parsePrecedence(allocator, .UNARY);

    switch (operator_type) {
        .BANG => emitByte(allocator, @enumToInt(OpCode.op_not)),
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
    .{ .prefix = unary, .precedence = .NONE }, // BANG
    .{ .infix = binary, .precedence = .EQUALITY }, // BANG_EQUAL
    .{ .precedence = .NONE }, // EQUAL
    .{ .infix = binary, .precedence = .COMPARISON }, // EQUAL_EQUAL
    .{ .infix = binary, .precedence = .COMPARISON }, // GREATER
    .{ .infix = binary, .precedence = .COMPARISON }, // GREATER_EQUAL
    .{ .infix = binary, .precedence = .COMPARISON }, // LESS
    .{ .infix = binary, .precedence = .COMPARISON }, // LESS_EQUAL
    .{ .precedence = .NONE }, // IDENTIFIER
    .{ .prefix = string, .precedence = .NONE }, // STRING
    .{ .prefix = number, .precedence = .NONE }, // NUMBER
    .{ .precedence = .NONE }, // AND
    .{ .precedence = .NONE }, // CLASS
    .{ .precedence = .NONE }, // ELSE
    .{ .prefix = literal, .precedence = .NONE }, // FALSE
    .{ .precedence = .NONE }, // FOR
    .{ .precedence = .NONE }, // FUN
    .{ .precedence = .NONE }, // IF
    .{ .prefix = literal, .precedence = .NONE }, // NIL
    .{ .precedence = .NONE }, // OR
    .{ .precedence = .NONE }, // PRINT
    .{ .precedence = .NONE }, // RETURN
    .{ .precedence = .NONE }, // SUPER
    .{ .precedence = .NONE }, // THIS
    .{ .prefix = literal, .precedence = .NONE }, // TRUE
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

fn identifierConstant(allocator: Allocator, name: *Token) u8 {
    return makeConstant(allocator, OBJ_VAL(&copyString(allocator, name.start, name.length).obj));
}

fn parseVariable(allocator: Allocator, error_message: []const u8) u8 {
    consume(.IDENTIFIER, error_message);
    return identifierConstant(allocator, &parser.previous);
}

fn defineVariable(allocator: Allocator, global: u8) void {
    emitBytes(allocator, @enumToInt(OpCode.op_define_global), global);
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

    while (!match(.EOF)) {
        declaration(allocator);
    }

    try endCompiler(allocator);
    return !parser.had_error;
}
