import type { Expr } from '../src/expr.ts';

export abstract class Stmt {
  abstract accept<R>(visitor: Visitor<R>): R;
}

export interface Visitor<R> {
  visitExpressionStmt(stmt: Expression): R;
  visitPrintStmt(stmt: Print): R;
}

export class Expression extends Stmt {
  constructor(expression: Expr) {
    super();
    this.expression = expression;
  }

  override accept<R>(visitor: Visitor<R>): R {
    return visitor.visitExpressionStmt(this);
  }

  expression: Expr;
}

export class Print extends Stmt {
  constructor(expression: Expr) {
    super();
    this.expression = expression;
  }

  override accept<R>(visitor: Visitor<R>): R {
    return visitor.visitPrintStmt(this);
  }

  expression: Expr;
}
