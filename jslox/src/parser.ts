import {
  Assign,
  Binary,
  Expr,
  Grouping,
  Literal,
  Logical,
  Ternary,
  Unary,
  Variable,
} from './expr.ts';
import { error } from './mod.ts';
import {
  Block,
  Break,
  Continue,
  Expression,
  If,
  Print,
  Stmt,
  Var,
  While,
} from './stmt.ts';
import { Token } from './token.ts';
import { TokenType } from './token-type.ts';

const T = TokenType;

export class Parser {
  tokens: Token[];
  current = 0;

  repl: boolean;
  loop = false;

  constructor(tokens: Token[], repl: boolean) {
    this.tokens = tokens;
    this.repl = repl;
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
    if (this.match(T.BREAK)) return this.breakStatement();
    if (this.match(T.CONTINUE)) return this.continueStatement();
    if (this.match(T.FOR)) return this.forStatement();
    if (this.match(T.IF)) return this.ifStatement();
    if (this.match(T.PRINT)) return this.printStatement();
    if (this.match(T.WHILE)) return this.whileStatement();
    if (this.match(T.LEFT_BRACE)) return new Block(this.block());

    return this.expressionStatement();
  }

  breakStatement(): Stmt {
    if (!this.loop)
      this.error(
        this.previous(),
        "'break' only allowed inside for or while loop.",
      );
    this.consume(T.SEMICOLON, "Expect ';' after break.");
    return new Break();
  }

  continueStatement(): Stmt {
    if (!this.loop)
      this.error(
        this.previous(),
        "'continue' only allowed inside for or while loop.",
      );
    this.consume(T.SEMICOLON, "Expect ';' after continue.");
    return new Continue();
  }

  forStatement(): Stmt {
    this.consume(T.LEFT_PAREN, "Expect '(' after 'for'.");

    let initializer;
    if (this.match(T.SEMICOLON)) {
      initializer = null;
    } else if (this.match(T.VAR)) {
      initializer = this.varDeclaration();
    } else {
      initializer = this.expressionStatement();
    }

    let condition = null;
    if (!this.check(T.SEMICOLON)) {
      condition = this.expression();
    }
    this.consume(T.SEMICOLON, "Expect ';' after loop condition.");

    let increment = null;
    if (!this.check(T.RIGHT_PAREN)) {
      increment = this.expression();
    }
    this.consume(T.RIGHT_PAREN, "Expect ')' after for clauses.");

    this.loop = true;
    let body = this.statement();
    this.loop = false;

    if (increment !== null) {
      body = new Block([body, new Expression(increment)]);
    }

    if (condition === null) condition = new Literal(true);
    body = new While(condition, body);

    if (initializer !== null) {
      body = new Block([initializer, body]);
    }

    return body;
  }

  ifStatement(): Stmt {
    this.consume(T.LEFT_PAREN, "Expect '(' after 'if'.");
    const condition = this.expression();
    this.consume(T.RIGHT_PAREN, "Expect ')' after if condition.");

    const thenBranch = this.statement();
    let elseBranch;
    if (this.match(T.ELSE)) {
      elseBranch = this.statement();
    }

    return new If(condition, thenBranch, elseBranch);
  }

  expressionStatement(): Stmt {
    const value = this.comma();

    if (this.repl && !this.check(T.SEMICOLON)) {
      return new Print(value);
    }

    this.consume(T.SEMICOLON, "Expect ';' after expression.");
    return new Expression(value);
  }

  block(): Stmt[] {
    const statements = [];
    while (!this.check(T.RIGHT_BRACE) && !this.isAtEnd()) {
      statements.push(this.declaration() as Stmt);
    }

    this.consume(T.RIGHT_BRACE, "Expect '}' after block");
    return statements;
  }

  printStatement(): Stmt {
    const value = this.expression();
    this.consume(T.SEMICOLON, "Expect ';' after value.");
    return new Print(value);
  }

  varDeclaration(): Stmt {
    const name = this.consume(T.IDENTIFIER, 'Expect variable name.');

    let initializer;
    if (this.match(T.EQUAL)) {
      initializer = this.expression();
    }

    this.consume(T.SEMICOLON, "Expect ';' after variable declaration.");
    return new Var(name, initializer);
  }

  whileStatement(): Stmt {
    this.consume(T.LEFT_PAREN, "Expect '(' after 'while'.");
    const condition = this.expression();
    this.consume(T.RIGHT_PAREN, "Expect ')' after condition.");

    this.loop = true;
    const body = this.statement();
    this.loop = false;

    return new While(condition, body);
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
    const expr = this.or();
    if (this.match(T.QUESTION)) {
      const left = this.or();
      this.consume(T.COLON, "Expect ':' after '?' left expression");
      const right = this.ternary();
      return new Ternary(expr, left, right);
    }
    return expr;
  }

  or(): Expr {
    let expr = this.and();

    while (this.match(T.OR)) {
      const operator = this.previous();
      const right = this.and();
      expr = new Logical(expr, operator, right);
    }

    return expr;
  }

  and(): Expr {
    let expr = this.equality();

    while (this.match(T.AND)) {
      const operator = this.previous();
      const right = this.equality();
      expr = new Logical(expr, operator, right);
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
