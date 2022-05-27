import type { Expr } from '../src/expr.ts';
import type { Token } from '../src/token.ts';

export abstract class Stmt {
  abstract accept<R>(visitor: Visitor<R>): R;
}

export interface Visitor<R> {
  visitBlockStmt(stmt: Block): R;
  visitBreakStmt(stmt: Break): R;
  visitContinueStmt(stmt: Continue): R;
  visitExpressionStmt(stmt: Expression): R;
  visitFunctionStmt(stmt: Function): R;
  visitIfStmt(stmt: If): R;
  visitPrintStmt(stmt: Print): R;
  visitVarStmt(stmt: Var): R;
  visitWhileStmt(stmt: While): R;
}

export class Block extends Stmt {
  statements: Stmt[];

  constructor(statements: Stmt[]) {
    super();
    this.statements = statements;
  }

  override accept<R>(visitor: Visitor<R>): R {
    return visitor.visitBlockStmt(this);
  }
}

export class Break extends Stmt {

  override accept<R>(visitor: Visitor<R>): R {
    return visitor.visitBreakStmt(this);
  }
}

export class Continue extends Stmt {

  override accept<R>(visitor: Visitor<R>): R {
    return visitor.visitContinueStmt(this);
  }
}

export class Expression extends Stmt {
  expression: Expr;

  constructor(expression: Expr) {
    super();
    this.expression = expression;
  }

  override accept<R>(visitor: Visitor<R>): R {
    return visitor.visitExpressionStmt(this);
  }
}

export class Function extends Stmt {
  name: Token;
  params: Token[];
  body: Stmt[];

  constructor(name: Token, params: Token[], body: Stmt[]) {
    super();
    this.name = name;
    this.params = params;
    this.body = body;
  }

  override accept<R>(visitor: Visitor<R>): R {
    return visitor.visitFunctionStmt(this);
  }
}

export class If extends Stmt {
  condition: Expr;
  thenBranch: Stmt;
  elseBranch?: Stmt;

  constructor(condition: Expr, thenBranch: Stmt, elseBranch?: Stmt) {
    super();
    this.condition = condition;
    this.thenBranch = thenBranch;
    this.elseBranch = elseBranch;
  }

  override accept<R>(visitor: Visitor<R>): R {
    return visitor.visitIfStmt(this);
  }
}

export class Print extends Stmt {
  expression: Expr;

  constructor(expression: Expr) {
    super();
    this.expression = expression;
  }

  override accept<R>(visitor: Visitor<R>): R {
    return visitor.visitPrintStmt(this);
  }
}

export class Var extends Stmt {
  name: Token;
  initializer?: Expr;

  constructor(name: Token, initializer?: Expr) {
    super();
    this.name = name;
    this.initializer = initializer;
  }

  override accept<R>(visitor: Visitor<R>): R {
    return visitor.visitVarStmt(this);
  }
}

export class While extends Stmt {
  condition: Expr;
  body: Stmt;

  constructor(condition: Expr, body: Stmt) {
    super();
    this.condition = condition;
    this.body = body;
  }

  override accept<R>(visitor: Visitor<R>): R {
    return visitor.visitWhileStmt(this);
  }
}
