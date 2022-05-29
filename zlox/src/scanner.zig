const TokenType = enum {
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

const Token = struct {
    t_type: TokenType,
    start: *const u8,
    length: usize,
    line: usize,
};

const Scanner = struct {
    start: *const u8,
    current: *const u8,
    line: usize,
};

var scanner: Scanner = undefined;

pub fn initScanner(source: []const u8) void {
    scanner.start = &source[0];
    scanner.current = &source[0];
    scanner.line = 1;
}

fn isAtEnd() bool {
    return scanner.current == null;
    // return scanner.current == '\0';
}

fn advance() u8 {
    const current = scanner.current;
    scanner.current = @intToPtr(*u8, @ptrToInt(current) + 1);
    return current.*;
}

fn match(expected: u8) bool {
    if (isAtEnd()) return false;
    if (scanner.current.* != expected) return false;
    scanner.current = @intToPtr(*u8, @ptrToInt(current) + 1);
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
        .start = &message[0],
        .length = message.len,
        .line = scanner.line,
    };
}

fn scanToken() Token {
    scanner.start = scanner.current;

    if (isAtEnd()) return makeToken(.EOF);

    const c = advance();

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
    }

    return errorToken("Unexpected character.");
}
