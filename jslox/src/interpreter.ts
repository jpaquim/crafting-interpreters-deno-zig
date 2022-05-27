import {
  Binary,
  Expr,
  Grouping,
  Literal,
  Ternary,
  Unary,
  Visitor,
} from './expr.ts';
import { runtimeError } from './mod.ts';
import { RuntimeError } from './runtime-error.ts';
import { Token } from './token.ts';
import { TokenType } from './token-type.ts';
import type { PlainObject } from './types.ts';

const T = TokenType;

export class Interpreter implements Visitor<PlainObject> {
  interpret(expression: Expr) {
    try {
      const value = this.evaluate(expression);
      console.log(this.stringify(value));
    } catch (error) {
      if (error instanceof RuntimeError) return runtimeError(error);
      throw error;
    }
  }

  visitBinaryExpr(expr: Binary): PlainObject {
    const left = this.evaluate(expr.left);
    const right = this.evaluate(expr.right);

    switch (expr.operator.type) {
      case T.BANG_EQUAL:
        return !this.isEqual(left, right);
      case T.EQUAL_EQUAL:
        return this.isEqual(left, right);
      case T.GREATER:
        this.checkNumberOperands(expr.operator, left, right);
        return (left as number) > (right as number);
      case T.GREATER_EQUAL:
        this.checkNumberOperands(expr.operator, left, right);
        return (left as number) >= (right as number);
      case T.LESS:
        this.checkNumberOperands(expr.operator, left, right);
        return (left as number) < (right as number);
      case T.LESS_EQUAL:
        this.checkNumberOperands(expr.operator, left, right);
        return (left as number) <= (right as number);
      case T.MINUS:
        this.checkNumberOperands(expr.operator, left, right);
        return (left as number) - (right as number);
      case T.PLUS:
        // TODO: replace with left + right and just use JS semantics?
        if (typeof left == 'number' && typeof right == 'number') {
          return left + right;
        }

        if (typeof left == 'string') {
          return left.concat(String(right));
        }

        if (typeof right == 'string') {
          return String(left).concat(right);
        }

        throw new RuntimeError(
          expr.operator,
          'Operands must be two numbers or two strings.',
        );
      case T.SLASH:
        this.checkNumberOperands(expr.operator, left, right);
        if (right === 0) {
          throw new RuntimeError(expr.operator, 'Attempted to divide by zero.');
        }
        return (left as number) / (right as number);
      case T.STAR:
        this.checkNumberOperands(expr.operator, left, right);
        return (left as number) * (right as number);
      case T.COMMA:
        return right;
    }

    throw new Error('unreachable');
  }

  visitGroupingExpr(expr: Grouping): PlainObject {
    return this.evaluate(expr.expression);
  }

  visitLiteralExpr(expr: Literal): PlainObject {
    return expr.value;
  }

  visitTernaryExpr(expr: Ternary): PlainObject {
    if (this.isTruthy(this.evaluate(expr.predicate))) {
      return this.evaluate(expr.left);
    } else {
      return this.evaluate(expr.right);
    }
  }

  visitUnaryExpr(expr: Unary): PlainObject {
    const right = this.evaluate(expr.right);

    switch (expr.operator.type) {
      case T.BANG:
        return !this.isTruthy(right);
      case T.MINUS:
        this.checkNumberOperand(expr.operator, right);
        return -Number(right);
    }

    throw new Error('unreachable');
  }

  checkNumberOperand(operator: Token, operand: PlainObject): void {
    if (typeof operand === 'number') return;
    throw new RuntimeError(operator, 'Operand must be a number.');
  }

  checkNumberOperands(
    operator: Token,
    left: PlainObject,
    right: PlainObject,
  ): void {
    if (typeof left === 'number' && typeof right === 'number') return;

    throw new RuntimeError(operator, 'Operands must be a number.');
  }

  evaluate(expr: Expr): PlainObject {
    return expr.accept(this);
  }

  isTruthy(object: PlainObject): boolean {
    if (object === null) return false;
    if (typeof object === 'boolean') return object;
    return true;
  }

  isEqual(a: PlainObject, b: PlainObject): boolean {
    if (a === null && b === null) return true;
    if (a === null) return false;

    return a === b;
  }

  stringify(object: PlainObject): string {
    if (object === null) return 'nil';

    if (typeof object === 'number') {
      let text = String(object);
      if (text.endsWith('.0')) {
        text = text.slice(0, -2);
      }
      return text;
    }

    return String(object);
  }
}
