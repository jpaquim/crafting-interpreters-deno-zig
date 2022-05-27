import {
  Assign,
  Binary,
  Expr,
  Grouping,
  Literal,
  Ternary,
  Unary,
  Variable,
} from './expr.ts';
import { error } from './mod.ts';
import { Expression, Print, Stmt, Var } from './stmt.ts';
import { Token } from './token.ts';
import { TokenType } from './token-type.ts';

const T = TokenType;

export class Parser {
  tokens: Token[];
  current = 0;

  constructor(tokens: Token[]) {
    this.tokens = tokens;
  }

  parse(): Stmt[] {
    const statements: Stmt[] = [];
    while (!this.isAtEnd()) {
      statements.push(this.declaration() as Stmt);
    }

    return statements;
  }

  declaration(): Stmt | null {
    try {
      if (this.match(T.VAR)) return this.varDeclaration();

      return this.statement();
    } catch (error) {
      if (error instanceof ParseError) {
        this.synchronize();
        return null;
      } else throw error;
    }
  }

  statement(): Stmt {
    if (this.match(T.PRINT)) return this.printStatement();

    return this.expressionStatement();
  }

  expressionStatement(): Stmt {
    const value = this.comma();
    this.consume(T.SEMICOLON, "Expect ';' after expression.");
    return new Expression(value);
  }

  printStatement(): Stmt {
    const value = this.expression();
    this.consume(T.SEMICOLON, "Expect ';' after value.");
    return new Print(value);
  }

  varDeclaration(): Stmt {
    const name = this.consume(T.IDENTIFIER, 'Expect variable name.');

    let initializer = null;
    if (this.match(T.EQUAL)) {
      initializer = this.expression();
    }

    this.consume(T.SEMICOLON, "Expect ';' after variable declaration.");
    return new Var(name, initializer);
  }

  comma(): Expr {
    let expr = this.expression();
    while (this.match(T.COMMA)) {
      const operator = this.previous();
      const right = this.expression();
      expr = new Binary(expr, operator, right);
    }

    return expr;
  }

  expression(): Expr {
    return this.assignment();
  }

  assignment(): Expr {
    const expr = this.ternary();

    if (this.match(T.EQUAL)) {
      const equals = this.previous();
      const value = this.assignment();

      if (expr instanceof Variable) {
        const name = expr.name;
        return new Assign(name, value);
      }

      this.error(equals, 'Invalid assignment target.');
    }

    return expr;
  }

  ternary(): Expr {
    const expr = this.equality();
    if (this.match(T.QUESTION)) {
      const left = this.equality();
      this.consume(T.COLON, "Expect ':' after '?' left expression");
      const right = this.ternary();
      return new Ternary(expr, left, right);
    }
    return expr;
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

    if (this.match(T.IDENTIFIER)) {
      return new Variable(this.previous());
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
    return this.peek().type === type;
  }

  advance(): Token {
    if (!this.isAtEnd()) this.current++;
    return this.previous();
  }

  isAtEnd(): boolean {
    return this.peek().type === T.EOF;
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
      if (this.previous().type === T.SEMICOLON) return;

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
