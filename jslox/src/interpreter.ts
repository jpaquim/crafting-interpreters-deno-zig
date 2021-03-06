import { Environment } from './environment.ts';
import { LoxCallable } from './lox-callable.ts';
import { LoxClass } from './lox-class.ts';
import { LoxFunction } from './lox-function.ts';
import { LoxInstance } from './lox-instance.ts';
import { runtimeError } from './mod.ts';
import { Return } from './return.ts';
import { RuntimeError } from './runtime-error.ts';
import type {
  Assign,
  Binary,
  Call,
  Expr,
  Function as ExprFunction,
  Get,
  Grouping,
  Literal,
  Logical,
  Set as ExprSet,
  Super,
  Ternary,
  This,
  Unary,
  Variable,
  Visitor as ExprVisitor,
} from './expr.ts';
import type {
  Block,
  Break,
  Continue,
  Class,
  Expression,
  Function,
  If,
  Print,
  Return as StmtReturn,
  Stmt,
  Var,
  Visitor as StmtVisitor,
  While,
} from './stmt.ts';
import type { Token } from './token.ts';
import { TokenType } from './token-type.ts';
import type { LoxObject } from './types.ts';

const T = TokenType;

export class Interpreter implements ExprVisitor<LoxObject>, StmtVisitor<void> {
  globals = new Environment();
  environment = this.globals;
  locals = new Map<Expr, number>();

  constructor() {
    this.globals.define(
      'clock',
      new (class extends LoxCallable {
        override arity(): number {
          return 0;
        }

        override call(
          _interpreter: Interpreter,
          _args: LoxObject[],
        ): LoxObject {
          return Date.now() / 1000;
        }

        override toString(): string {
          return '<native fn>';
        }
      })(),
    );
  }

  interpret(statements: Stmt[]) {
    try {
      for (const statement of statements) {
        this.execute(statement);
      }
    } catch (error) {
      if (error instanceof RuntimeError) return runtimeError(error);
      throw error;
    }
  }

  visitBinaryExpr(expr: Binary): LoxObject {
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

  visitCallExpr(expr: Call): LoxObject {
    const callee = this.evaluate(expr.callee);

    const args = [];
    for (const argument of expr.args) {
      args.push(this.evaluate(argument));
    }

    if (!(callee instanceof LoxCallable)) {
      throw new RuntimeError(expr.paren, 'Can only call functions and classes');
    }

    const fn = callee as LoxCallable;

    if (args.length !== fn.arity()) {
      throw new RuntimeError(
        expr.paren,
        `Expected ${fn.arity()} arguments but got ${args.length}.`,
      );
    }

    return fn.call(this, args);
  }

  visitGetExpr(expr: Get): LoxObject {
    const object = this.evaluate(expr.object);
    if (object instanceof LoxInstance) {
      return object.get(expr.name);
    }

    throw new RuntimeError(expr.name, 'Only instances have properties.');
  }

  visitGroupingExpr(expr: Grouping): LoxObject {
    return this.evaluate(expr.expression);
  }

  visitLiteralExpr(expr: Literal): LoxObject {
    return expr.value;
  }

  visitLogicalExpr(expr: Logical): LoxObject {
    const left = this.evaluate(expr.left);

    if (expr.operator.type === T.OR) {
      if (this.isTruthy(left)) return left;
    } else {
      if (!this.isTruthy(left)) return left;
    }

    return this.evaluate(expr.right);
  }

  visitSetExpr(expr: ExprSet): LoxObject {
    const object = this.evaluate(expr.object);

    if (!(object instanceof LoxInstance)) {
      throw new RuntimeError(expr.name, 'Only instances have fields.');
    }

    const value = this.evaluate(expr.value);
    object.set(expr.name, value);
    return value;
  }

  visitSuperExpr(expr: Super): LoxObject {
    const distance = this.locals.get(expr) as number;
    const superclass = this.environment.getAt(distance, 'super') as LoxClass;

    const object = this.environment.getAt(distance - 1, 'this') as LoxInstance;

    const method = superclass.findMethod(expr.method.lexeme);

    if (method === undefined) {
      throw new RuntimeError(
        expr.method,
        `Undefined property '${expr.method.lexeme}'.`,
      );
    }

    return method.bind(object);
  }

  visitTernaryExpr(expr: Ternary): LoxObject {
    if (this.isTruthy(this.evaluate(expr.predicate))) {
      return this.evaluate(expr.left);
    } else {
      return this.evaluate(expr.right);
    }
  }

  visitThisExpr(expr: This): LoxObject {
    return this.lookUpVariable(expr.keyword, expr);
  }

  visitUnaryExpr(expr: Unary): LoxObject {
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

  visitVariableExpr(expr: Variable): LoxObject {
    return this.lookUpVariable(expr.name, expr);
  }

  lookUpVariable(name: Token, expr: Expr): LoxObject {
    const distance = this.locals.get(expr);
    if (distance !== undefined) {
      return this.environment.getAt(distance, name.lexeme);
    } else {
      return this.globals.get(name);
    }
  }

  checkNumberOperand(operator: Token, operand: LoxObject): void {
    if (typeof operand === 'number') return;
    throw new RuntimeError(operator, 'Operand must be a number.');
  }

  checkNumberOperands(
    operator: Token,
    left: LoxObject,
    right: LoxObject,
  ): void {
    if (typeof left === 'number' && typeof right === 'number') return;

    throw new RuntimeError(operator, 'Operands must be a number.');
  }

  evaluate(expr: Expr): LoxObject {
    return expr.accept(this);
  }

  execute(statement: Stmt): void {
    return statement.accept(this);
  }

  resolve(expr: Expr, depth: number): void {
    this.locals.set(expr, depth);
  }

  executeBlock(statements: Stmt[], environment: Environment) {
    const previous = this.environment;
    try {
      this.environment = environment;

      for (const statement of statements) {
        this.execute(statement);
      }
    } finally {
      this.environment = previous;
    }
  }

  visitBlockStmt(stmt: Block): void {
    this.executeBlock(stmt.statements, new Environment(this.environment));
  }

  visitBreakStmt(_stmt: Break): void {
    throw new BreakError();
  }

  visitContinueStmt(_stmt: Continue): void {
    throw new ContinueError();
  }

  visitClassStmt(stmt: Class): void {
    let superclass;
    if (stmt.superclass !== undefined) {
      superclass = this.evaluate(stmt.superclass);
      if (!(superclass instanceof LoxClass)) {
        throw new RuntimeError(
          stmt.superclass.name,
          'Superclass must be a class.',
        );
      }
    }

    this.environment.define(stmt.name.lexeme, null);

    if (stmt.superclass !== undefined) {
      this.environment = new Environment(this.environment);
      this.environment.define('super', superclass as LoxClass);
    }

    const methods = new Map<string, LoxFunction>();
    for (const method of stmt.methods) {
      const fn = new LoxFunction(
        method,
        this.environment,
        method.name.lexeme === 'init',
      );
      methods.set(method.name.lexeme, fn);
    }

    const klass = new LoxClass(stmt.name.lexeme, methods, superclass);

    if (superclass !== undefined) {
      this.environment = this.environment.enclosing as Environment;
    }

    this.environment.assign(stmt.name, klass);
  }

  visitExpressionStmt(stmt: Expression): void {
    this.evaluate(stmt.expression);
  }

  visitFunctionStmt(stmt: Function): void {
    const fn = new LoxFunction(stmt, this.environment, false);
    this.environment.define(stmt.name.lexeme, fn);
  }

  visitIfStmt(stmt: If): void {
    if (this.isTruthy(this.evaluate(stmt.condition))) {
      this.execute(stmt.thenBranch);
    } else if (stmt.elseBranch) {
      this.execute(stmt.elseBranch);
    }
  }

  visitPrintStmt(stmt: Print): void {
    const value = this.evaluate(stmt.expression);
    console.log(this.stringify(value));
  }

  visitReturnStmt(stmt: StmtReturn): void {
    let value;
    if (stmt.value !== undefined) value = this.evaluate(stmt.value);

    throw new Return(value);
  }

  visitVarStmt(stmt: Var): void {
    let value = null;
    const initializer = stmt.initializer;
    if (initializer !== undefined) {
      value = this.evaluate(initializer);
    }

    this.environment.define(stmt.name.lexeme, value);
  }

  visitWhileStmt(stmt: While): void {
    while (this.isTruthy(this.evaluate(stmt.condition))) {
      try {
        this.execute(stmt.body);
      } catch (error) {
        if (error instanceof BreakError) {
          break;
        } else if (error instanceof ContinueError) {
          continue;
        } else throw error;
      }
    }
  }

  visitAssignExpr(expr: Assign): LoxObject {
    const value = this.evaluate(expr.value);

    const distance = this.locals.get(expr);
    if (distance !== undefined) {
      this.environment.assignAt(distance, expr.name, value);
    } else {
      this.globals.assign(expr.name, value);
    }

    return value;
  }

  visitFunctionExpr(expr: ExprFunction): LoxObject {
    if (expr.name) {
      const environment = new Environment(this.environment);
      const fn = new LoxFunction(expr, environment, false);
      environment.define(expr.name.lexeme, fn);
      return fn;
    }
    const fn = new LoxFunction(expr, this.environment, false);
    return fn;
  }

  isTruthy(object: LoxObject): boolean {
    if (object === null) return false;
    if (typeof object === 'boolean') return object;
    return true;
  }

  isEqual(a: LoxObject, b: LoxObject): boolean {
    if (a === null && b === null) return true;
    if (a === null) return false;

    return a === b;
  }

  stringify(object: LoxObject): string {
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

class BreakError extends Error {}

class ContinueError extends Error {}
