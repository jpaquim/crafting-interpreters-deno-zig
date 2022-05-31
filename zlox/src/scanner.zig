const std = @import("std");

pub const TokenType = enum(u8) {
    // Single-character tokens.
    LEFT_PAREN,
    RIGHT_PAREN,
    LEFT_BRACE,
    RIGHT_BRACE,
    COMMA,
    DOT,
    MINUS,
    PLUS,
    SEMICOLON,
    SLASH,
    STAR,
    // One or two character tokens.
    BANG,
    BANG_EQUAL,
    EQUAL,
    EQUAL_EQUAL,
    GREATER,
    GREATER_EQUAL,
    LESS,
    LESS_EQUAL,
    // Literals.
    IDENTIFIER,
    STRING,
    NUMBER,
    // Keywords.
    AND,
    CLASS,
    ELSE,
    FALSE,
    FOR,
    FUN,
    IF,
    NIL,
    OR,
    PRINT,
    RETURN,
    SUPER,
    THIS,
    TRUE,
    VAR,
    WHILE,

    ERROR,
    EOF,
};

pub const Token = struct {
    t_type: TokenType,
    start: [*]const u8,
    length: usize,
    line: usize,
};

const Scanner = struct {
    start: [*]const u8,
    current: [*]const u8,
    end: [*]const u8,
    length: usize,
    line: usize,
};

var scanner: Scanner = undefined;

pub fn initScanner(source: []const u8) void {
    scanner = .{
        .start = source.ptr,
        .current = source.ptr,
        .end = source.ptr[source.len..source.len].ptr,
        .length = source.len,
        .line = 1,
    };
}

fn isAlpha(c: u8) bool {
    return ((c >= 'a' and c <= 'z') or (c >= 'A' and c <= 'Z') or c == '_');
}

fn isDigit(c: u8) bool {
    return c >= '0' and c <= '9';
}

fn isAtEnd() bool {
    return scanner.current == scanner.end;
}

fn advance() u8 {
    const value = scanner.current[0];
    scanner.current += 1;
    return value;
}

fn peek() u8 {
    return scanner.current[0];
}

fn peekNext() u8 {
    if (isAtEnd()) return '\x00';
    return scanner.current[1];
}

fn match(expected: u8) bool {
    if (isAtEnd()) return false;
    if (scanner.current[0] != expected) return false;
    scanner.current += 1;
    return true;
}

fn makeToken(t_type: TokenType) Token {
    return .{
        .t_type = t_type,
        .start = scanner.start,
        .length = @ptrToInt(scanner.current) - @ptrToInt(scanner.start),
        .line = scanner.line,
    };
}

fn errorToken(message: []const u8) Token {
    return .{
        .t_type = .ERROR,
        .start = message.ptr,
        .length = message.len,
        .line = scanner.line,
    };
}

fn skipWhitespace() void {
    while (!isAtEnd()) {
        const c = peek();
        switch (c) {
            ' ', '\r', '\t' => _ = advance(),
            '\n' => {
                scanner.line += 1;
                _ = advance();
            },
            '/' => {
                if (peekNext() == '/') {
                    while (peek() != '\n' and !isAtEnd()) _ = advance();
                } else return;
            },
            else => return,
        }
    }
}

fn checkKeyword(start: usize, length: usize, rest: []const u8, t_type: TokenType) TokenType {
    if (scanner.start + start + length == scanner.current and std.mem.eql(u8, scanner.start[start .. start + length], rest[0..length])) {
        return t_type;
    }

    return .IDENTIFIER;
}

fn identifierType() TokenType {
    switch (scanner.start.*) {
        'a' => return checkKeyword(1, 2, "nd", .AND),
        'c' => return checkKeyword(1, 4, "lass", .CLASS),
        'e' => return checkKeyword(1, 3, "lse", .ELSE),
        'f' => {
            if (@ptrToInt(scanner.current) > @ptrToInt(scanner.start + 1)) {
                switch (scanner.start[1]) {
                    'a' => return checkKeyword(2, 3, "lse", .FALSE),
                    'o' => return checkKeyword(2, 1, "r", .FOR),
                    'u' => return checkKeyword(2, 1, "n", .FUN),
                    else => {},
                }
            }
        },
        'i' => return checkKeyword(1, 1, "f", .IF),
        'n' => return checkKeyword(1, 2, "il", .NIL),
        'o' => return checkKeyword(1, 1, "r", .OR),
        'p' => return checkKeyword(1, 4, "rint", .PRINT),
        'r' => return checkKeyword(1, 5, "eturn", .RETURN),
        's' => return checkKeyword(1, 4, "uper", .SUPER),
        't' => {
            if (@ptrToInt(scanner.current) > @ptrToInt(scanner.start + 1)) {
                switch (scanner.start[1]) {
                    'h' => return checkKeyword(2, 2, "is", .THIS),
                    'r' => return checkKeyword(2, 2, "ue", .TRUE),
                    else => {},
                }
            }
        },
        'v' => return checkKeyword(1, 2, "ar", .VAR),
        'w' => return checkKeyword(1, 4, "hile", .WHILE),
        else => {},
    }
    return .IDENTIFIER;
}

fn identifier() Token {
    while (isAlpha(peek()) or isDigit(peek())) _ = advance();
    return makeToken(identifierType());
}

fn number() Token {
    while (isDigit(peek())) _ = advance();

    if (peek() == '.' and isDigit(peekNext())) {
        _ = advance();

        while (isDigit(peek())) _ = advance();
    }

    return makeToken(.NUMBER);
}

fn string() Token {
    while (peek() != '"' and !isAtEnd()) {
        if (peek() == '\n') scanner.line += 1;
        _ = advance();
    }

    if (isAtEnd()) return errorToken("Unterminated string.");

    _ = advance();
    return makeToken(.STRING);
}

pub fn scanToken() Token {
    skipWhitespace();
    scanner.start = scanner.current;

    if (isAtEnd()) return makeToken(.EOF);

    const c = advance();
    if (isAlpha(c)) return identifier();
    if (isDigit(c)) return number();

    switch (c) {
        '(' => return makeToken(.LEFT_PAREN),
        ')' => return makeToken(.RIGHT_PAREN),
        '{' => return makeToken(.LEFT_BRACE),
        '}' => return makeToken(.RIGHT_BRACE),
        ';' => return makeToken(.SEMICOLON),
        ',' => return makeToken(.COMMA),
        '.' => return makeToken(.DOT),
        '-' => return makeToken(.MINUS),
        '+' => return makeToken(.PLUS),
        '/' => return makeToken(.SLASH),
        '*' => return makeToken(.STAR),
        '!' => return makeToken(if (match('=')) .BANG_EQUAL else .BANG),
        '=' => return makeToken(if (match('=')) .EQUAL_EQUAL else .EQUAL),
        '<' => return makeToken(if (match('=')) .LESS_EQUAL else .LESS),
        '>' => return makeToken(if (match('=')) .GREATER_EQUAL else .GREATER),
        '"' => return string(),
        else => {},
    }

    return errorToken("Unexpected character.");
}
