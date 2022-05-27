import type { Token } from '../src/token.ts';
import type { PlainObject } from '../src/types.ts';

export abstract class Expr {
  abstract accept<R>(visitor: Visitor<R>): R;
}

export interface Visitor<R> {
  visitAssignExpr(expr: Assign): R;
  visitBinaryExpr(expr: Binary): R;
  visitGroupingExpr(expr: Grouping): R;
  visitLiteralExpr(expr: Literal): R;
  visitLogicalExpr(expr: Logical): R;
  visitTernaryExpr(expr: Ternary): R;
  visitUnaryExpr(expr: Unary): R;
  visitVariableExpr(expr: Variable): R;
}

export class Assign extends Expr {
  constructor(name: Token, value: Expr) {
    super();
    this.name = name;
    this.value = value;
  }

  override accept<R>(visitor: Visitor<R>): R {
    return visitor.visitAssignExpr(this);
  }

  name: Token;
  value: Expr;
}

export class Binary extends Expr {
  constructor(left: Expr, operator: Token, right: Expr) {
    super();
    this.left = left;
    this.operator = operator;
    this.right = right;
  }

  override accept<R>(visitor: Visitor<R>): R {
    return visitor.visitBinaryExpr(this);
  }

  left: Expr;
  operator: Token;
  right: Expr;
}

export class Grouping extends Expr {
  constructor(expression: Expr) {
    super();
    this.expression = expression;
  }

  override accept<R>(visitor: Visitor<R>): R {
    return visitor.visitGroupingExpr(this);
  }

  expression: Expr;
}

export class Literal extends Expr {
  constructor(value: PlainObject) {
    super();
    this.value = value;
  }

  override accept<R>(visitor: Visitor<R>): R {
    return visitor.visitLiteralExpr(this);
  }

  value: PlainObject;
}

export class Logical extends Expr {
  constructor(left: Expr, operator: Token, right: Expr) {
    super();
    this.left = left;
    this.operator = operator;
    this.right = right;
  }

  override accept<R>(visitor: Visitor<R>): R {
    return visitor.visitLogicalExpr(this);
  }

  left: Expr;
  operator: Token;
  right: Expr;
}

export class Ternary extends Expr {
  constructor(predicate: Expr, left: Expr, right: Expr) {
    super();
    this.predicate = predicate;
    this.left = left;
    this.right = right;
  }

  override accept<R>(visitor: Visitor<R>): R {
    return visitor.visitTernaryExpr(this);
  }

  predicate: Expr;
  left: Expr;
  right: Expr;
}

export class Unary extends Expr {
  constructor(operator: Token, right: Expr) {
    super();
    this.operator = operator;
    this.right = right;
  }

  override accept<R>(visitor: Visitor<R>): R {
    return visitor.visitUnaryExpr(this);
  }

  operator: Token;
  right: Expr;
}

export class Variable extends Expr {
  constructor(name: Token) {
    super();
    this.name = name;
  }

  override accept<R>(visitor: Visitor<R>): R {
    return visitor.visitVariableExpr(this);
  }

  name: Token;
}
