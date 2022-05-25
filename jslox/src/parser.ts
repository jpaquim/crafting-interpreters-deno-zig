import { Binary, Expr, Grouping, Literal, Unary } from './expr.ts';
import { error } from './mod.ts';
import { Token } from './token.ts';
import { TokenType } from './token-type.ts';

const T = TokenType;

export class Parser {
  tokens: Token[];
  current = 0;

  constructor(tokens: Token[]) {
    this.tokens = tokens;
  }

  parse(): Expr | null {
    try {
      return this.expression();
    } catch (error) {
      if (error instanceof ParseError) return null;
      throw error;
    }
  }

  expression(): Expr {
    return this.equality();
  }

  equality(): Expr {
    let expr = this.comparison();
    while (this.match(T.BANG_EQUAL, T.EQUAL_EQUAL)) {
      const operator = this.previous();
      const right = this.comparison();
      expr = new Binary(expr, operator, right);
    }

    return expr;
  }

  comparison(): Expr {
    let expr = this.term();
    while (this.match(T.GREATER, T.GREATER_EQUAL, T.LESS, T.LESS_EQUAL)) {
      const operator = this.previous();
      const right = this.term();
      expr = new Binary(expr, operator, right);
    }

    return expr;
  }

  term(): Expr {
    let expr = this.factor();
    while (this.match(T.MINUS, T.PLUS)) {
      const operator = this.previous();
      const right = this.factor();
      expr = new Binary(expr, operator, right);
    }

    return expr;
  }

  factor(): Expr {
    let expr = this.unary();
    while (this.match(T.SLASH, T.STAR)) {
      const operator = this.previous();
      const right = this.unary();
      expr = new Binary(expr, operator, right);
    }

    return expr;
  }

  unary(): Expr {
    if (this.match(T.BANG, T.MINUS)) {
      const operator = this.previous();
      const right = this.unary();
      return new Unary(operator, right);
    }

    return this.primary();
  }

  primary(): Expr {
    if (this.match(T.FALSE)) return new Literal(false);
    if (this.match(T.TRUE)) return new Literal(true);
    if (this.match(T.NIL)) return new Literal(null);

    if (this.match(T.NUMBER, T.STRING)) {
      return new Literal(this.previous().literal);
    }

    if (this.match(T.LEFT_PAREN)) {
      const expr = this.expression();
      this.consume(T.RIGHT_PAREN, "Expect ')' after expression");
      return new Grouping(expr);
    }

    throw this.error(this.peek(), 'Expect expression.');
  }

  match(...types: TokenType[]): boolean {
    for (const type of types) {
      if (this.check(type)) {
        this.advance();
        return true;
      }
    }

    return false;
  }

  consume(type: TokenType, message: string): Token {
    if (this.check(type)) return this.advance();
    throw this.error(this.peek(), message);
  }

  check(type: TokenType): boolean {
    if (this.isAtEnd()) return false;
    return this.peek().type == type;
  }

  advance(): Token {
    if (!this.isAtEnd()) this.current++;
    return this.previous();
  }

  isAtEnd(): boolean {
    return this.peek().type == T.EOF;
  }

  peek(): Token {
    return this.tokens[this.current];
  }

  previous(): Token {
    return this.tokens[this.current - 1];
  }

  error(token: Token, message: string): ParseError {
    error(token, message);
    return new ParseError();
  }

  synchronize(): void {
    this.advance();

    while (!this.isAtEnd()) {
      if (this.previous().type == T.SEMICOLON) return;

      switch (this.peek().type) {
        case T.CLASS:
        case T.FUN:
        case T.VAR:
        case T.FOR:
        case T.IF:
        case T.WHILE:
        case T.PRINT:
        case T.RETURN:
          return;
      }

      this.advance();
    }
  }
}

class ParseError extends Error {}
