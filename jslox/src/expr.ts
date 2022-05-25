import { LiteralObject, Token } from '../src/token.ts';

export abstract class Expr {
  static Binary = class Binary extends Expr {
    constructor(left: Expr, operator: Token, right: Expr) {
      super();
      this.left = left;
      this.operator = operator;
      this.right = right;
    }

    left: Expr;
    operator: Token;
    right: Expr;
  };
  static Grouping = class Grouping extends Expr {
    constructor(expression: Expr) {
      super();
      this.expression = expression;
    }

    expression: Expr;
  };
  static Literal = class Literal extends Expr {
    constructor(value: LiteralObject) {
      super();
      this.value = value;
    }

    value: LiteralObject;
  };
  static Unary = class Unary extends Expr {
    constructor(operator: Token, right: Expr) {
      super();
      this.operator = operator;
      this.right = right;
    }

    operator: Token;
    right: Expr;
  };
}
