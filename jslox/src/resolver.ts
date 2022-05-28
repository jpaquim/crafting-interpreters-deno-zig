import { Interpreter } from './interpreter.ts';
import { error } from './mod.ts';
import type {
  Assign,
  Binary,
  Call,
  Expr,
  Function as ExprFunction,
  Grouping,
  Literal,
  Logical,
  Ternary,
  Unary,
  Variable,
  Visitor as ExprVisitor,
} from './expr.ts';
import type {
  Block,
  Break,
  Continue,
  Expression,
  Function as StmtFunction,
  If,
  Print,
  Return as StmtReturn,
  Stmt,
  Var,
  Visitor as StmtVisitor,
  While,
} from './stmt.ts';
import type { Token } from './token.ts';

enum FunctionType {
  NONE,
  FUNCTION,
}

export class Resolver implements ExprVisitor<void>, StmtVisitor<void> {
  interpreter: Interpreter;
  scopes: Map<string, boolean>[] = [];
  currentFunction = FunctionType.NONE;

  constructor(interpreter: Interpreter) {
    this.interpreter = interpreter;
  }

  resolve(stmts_or_stmt_or_expr: Stmt[] | Stmt | Expr): void {
    if (Array.isArray(stmts_or_stmt_or_expr)) {
      const statements = stmts_or_stmt_or_expr;
      for (const statement of statements) {
        this.resolve(statement);
      }
    } else {
      const stmt_or_expr = stmts_or_stmt_or_expr;
      stmt_or_expr.accept(this);
    }
  }

  resolveFunction(fn: StmtFunction | ExprFunction, type: FunctionType): void {
    const enclosingFunction = this.currentFunction;
    this.currentFunction = type;

    this.beginScope();
    for (const param of fn.params) {
      this.declare(param);
      this.define(param);
    }
    this.resolve(fn.body);
    this.endScope();
    this.currentFunction = enclosingFunction;
  }

  beginScope(): void {
    this.scopes.push(new Map<string, boolean>());
  }

  endScope(): void {
    this.scopes.pop();
  }

  declare(name: Token): void {
    if (this.scopes.length === 0) return;

    const scope = this.scopes[this.scopes.length - 1];
    if (scope.has(name.lexeme)) {
      error(name, 'Already a variable with this name in this scope.');
    }

    scope.set(name.lexeme, false);
  }

  define(name: Token): void {
    if (this.scopes.length === 0) return;
    this.scopes[this.scopes.length - 1].set(name.lexeme, true);
  }

  resolveLocal(expr: Expr, name: Token): void {
    for (let i = this.scopes.length - 1; i >= 0; --i) {
      if (this.scopes[i].has(name.lexeme)) {
        this.interpreter.resolve(expr, this.scopes.length - i - 1);
        return;
      }
    }
  }

  visitBlockStmt(stmt: Block): void {
    this.beginScope();
    this.resolve(stmt.statements);
    this.endScope();
  }

  visitBreakStmt(_stmt: Break): void {}

  visitContinueStmt(_stmt: Continue): void {}

  visitExpressionStmt(stmt: Expression): void {
    this.resolve(stmt.expression);
  }

  visitFunctionStmt(stmt: StmtFunction) {
    this.declare(stmt.name);
    this.define(stmt.name);

    this.resolveFunction(stmt, FunctionType.FUNCTION);
  }

  visitIfStmt(stmt: If): void {
    this.resolve(stmt.condition);
    this.resolve(stmt.thenBranch);
    if (stmt.elseBranch !== undefined) this.resolve(stmt.elseBranch);
  }

  visitPrintStmt(stmt: Print): void {
    this.resolve(stmt.expression);
  }

  visitReturnStmt(stmt: StmtReturn): void {
    if (this.currentFunction === FunctionType.NONE) {
      error(stmt.keyword, "Can't return from top-level code.");
    }

    if (stmt.value !== undefined) {
      this.resolve(stmt.value);
    }
  }

  visitVarStmt(stmt: Var): void {
    this.declare(stmt.name);
    if (stmt.initializer !== undefined) {
      this.resolve(stmt.initializer);
    }
    this.define(stmt.name);
  }

  visitWhileStmt(stmt: While): void {
    this.resolve(stmt.condition);
    this.resolve(stmt.body);
  }

  visitAssignExpr(expr: Assign): void {
    this.resolve(expr.value);
    this.resolveLocal(expr, expr.name);
  }

  visitBinaryExpr(expr: Binary): void {
    this.resolve(expr.left);
    this.resolve(expr.right);
  }

  visitCallExpr(expr: Call): void {
    this.resolve(expr.callee);

    for (const argument of expr.args) {
      this.resolve(argument);
    }
  }

  visitFunctionExpr(expr: ExprFunction) {
    if (expr.name !== undefined) {
      this.declare(expr.name);
      this.define(expr.name);
    }

    this.resolveFunction(expr, FunctionType.FUNCTION);
  }

  visitGroupingExpr(expr: Grouping): void {
    this.resolve(expr.expression);
  }

  visitLiteralExpr(_expr: Literal): void {}

  visitLogicalExpr(expr: Logical): void {
    this.resolve(expr.left);
    this.resolve(expr.right);
  }

  visitTernaryExpr(expr: Ternary): void {
    this.resolve(expr.predicate);
    this.resolve(expr.left);
    this.resolve(expr.right);
  }

  visitUnaryExpr(expr: Unary): void {
    this.resolve(expr.right);
  }

  visitVariableExpr(expr: Variable): void {
    if (
      this.scopes.length > 0 &&
      this.scopes[this.scopes.length - 1].get(expr.name.lexeme) == false
    ) {
      error(expr.name, "Can't read local variable in its own initializer.");
    }

    this.resolveLocal(expr, expr.name);
  }
}
