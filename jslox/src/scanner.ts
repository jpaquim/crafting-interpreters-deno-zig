import { error } from './mod.ts';
import { Token } from './token.ts';
import { TokenType } from './token-type.ts';
import type { PlainObject } from './types.ts';

const T = TokenType;

export class Scanner {
  static keywords = new Map<string, TokenType>([
    ['and', T.AND],
    ['class', T.CLASS],
    ['else', T.ELSE],
    ['false', T.FALSE],
    ['for', T.FOR],
    ['fun', T.FUN],
    ['if', T.IF],
    ['nil', T.NIL],
    ['or', T.OR],
    ['print', T.PRINT],
    ['return', T.RETURN],
    ['super', T.SUPER],
    ['this', T.THIS],
    ['true', T.TRUE],
    ['var', T.VAR],
    ['while', T.WHILE],
  ]);

  source: string;
  tokens: Token[] = [];

  start = 0;
  current = 0;
  line = 1;

  constructor(source: string) {
    this.source = source;
  }

  scanTokens(): Token[] {
    while (!this.isAtEnd()) {
      this.start = this.current;
      this.scanToken();
    }

    this.tokens.push(new Token(T.EOF, '', null, this.line));
    return this.tokens;
  }

  isAtEnd(): boolean {
    return this.current >= this.source.length;
  }

  scanToken(): void {
    const c = this.advance();
    switch (c) {
      case '(':
        this.addToken(T.LEFT_PAREN);
        break;
      case ')':
        this.addToken(T.RIGHT_PAREN);
        break;
      case '{':
        this.addToken(T.LEFT_BRACE);
        break;
      case '}':
        this.addToken(T.RIGHT_BRACE);
        break;
      case ',':
        this.addToken(T.COMMA);
        break;
      case '.':
        this.addToken(T.DOT);
        break;
      case '-':
        this.addToken(T.MINUS);
        break;
      case '+':
        this.addToken(T.PLUS);
        break;
      case ';':
        this.addToken(T.SEMICOLON);
        break;
      case '*':
        this.addToken(T.STAR);
        break;
      case '?':
        this.addToken(T.QUESTION);
        break;
      case ':':
        this.addToken(T.COLON);
        break;
      case '!':
        this.addToken(this.match('=') ? T.BANG_EQUAL : T.BANG);
        break;
      case '=':
        this.addToken(this.match('=') ? T.EQUAL_EQUAL : T.EQUAL);
        break;
      case '<':
        this.addToken(this.match('=') ? T.LESS_EQUAL : T.LESS);
        break;
      case '>':
        this.addToken(this.match('=') ? T.GREATER_EQUAL : T.GREATER);
        break;
      case '/':
        if (this.match('/')) {
          while (this.peek() != '\n' && !this.isAtEnd()) this.advance();
        } else this.addToken(T.SLASH);
        break;
      case ' ':
      case '\r':
      case '\t':
        break;
      case '"':
        this.string();
        break;
      default:
        if (this.isDigit(c)) {
          this.number();
        } else if (this.isAlpha(c)) {
          this.identifier();
        } else {
          error(this.line, 'Unexpected character.');
        }
        break;
    }
  }

  identifier(): void {
    while (this.isAlphaNumeric(this.peek())) this.advance();

    const text = this.source.slice(this.start, this.current);
    const type = Scanner.keywords.get(text) ?? T.IDENTIFIER;
    this.addToken(type);
  }

  number(): void {
    while (this.isDigit(this.peek())) this.advance();

    if (this.peek() === '.' && this.isDigit(this.peekNext())) {
      this.advance();

      while (this.isDigit(this.peek())) this.advance();
    }

    this.addToken(
      T.NUMBER,
      Number.parseFloat(this.source.slice(this.start, this.current)),
    );
  }

  string(): void {
    while (this.peek() != '"' && !this.isAtEnd()) {
      if (this.peek() === '\n') this.line++;
      this.advance();
    }

    if (this.isAtEnd()) {
      error(this.line, 'Unterminated string.');
      return;
    }

    this.advance();

    const value = this.source.slice(this.start + 1, this.current - 1);
    this.addToken(T.STRING, value);
  }

  advance(): string {
    return this.source[this.current++];
  }

  addToken(type: TokenType, literal: PlainObject = null): void {
    const text = this.source.slice(this.start, this.current);
    this.tokens.push(new Token(type, text, literal, this.line));
  }

  match(expected: string): boolean {
    if (this.isAtEnd()) return false;
    if (this.source[this.current] != expected) return false;

    this.current++;
    return true;
  }

  peek(): string {
    if (this.isAtEnd()) return '\0';
    return this.source[this.current];
  }

  peekNext(): string {
    if (this.current + 1 >= this.source.length) return '\0';
    return this.source[this.current + 1];
  }

  isAlpha(c: string) {
    return (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || c === '_';
  }

  isAlphaNumeric(c: string) {
    return this.isAlpha(c) || this.isDigit(c);
  }

  isDigit(c: string): boolean {
    return c >= '0' && c <= '9';
  }
}
