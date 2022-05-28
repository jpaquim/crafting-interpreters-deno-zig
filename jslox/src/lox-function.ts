import { Environment } from './environment.ts';
import type { Function as ExprFunction } from './expr.ts';
import { Interpreter } from './interpreter.ts';
import { LoxCallable } from './lox-callable.ts';
import { Return } from './return.ts';
import type { Function as StmtFunction } from './stmt.ts';
import type { LoxObject } from './types.ts';

export class LoxFunction extends LoxCallable {
  declaration: StmtFunction | ExprFunction;
  closure: Environment;

  constructor(declaration: StmtFunction | ExprFunction, closure: Environment) {
    super();
    this.closure = closure;
    this.declaration = declaration;
  }

  override call(interpreter: Interpreter, args: LoxObject[]): LoxObject {
    const environment = new Environment(this.closure);
    for (let i = 0; i < this.declaration.params.length; ++i) {
      environment.define(this.declaration.params[i].lexeme, args[i]);
    }

    try {
      interpreter.executeBlock(this.declaration.body, environment);
    } catch (error) {
      if (error instanceof Return) {
        return error.value ?? null;
      } else throw error;
    }
    return null;
  }

  override arity() {
    return this.declaration.params.length;
  }

  override toString(): string {
    return `<fn ${this.declaration.name?.lexeme ?? 'anonymous'}>`;
  }
}
