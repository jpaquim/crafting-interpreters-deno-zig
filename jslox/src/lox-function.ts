import { Callable } from './callable.ts';
import { Environment } from './environment.ts';
import { Interpreter } from './interpreter.ts';
import type * as Stmt from './stmt.ts';
import type { LoxObject } from './types.ts';

export class LoxFunction extends Callable {
  declaration: Stmt.Function;
  constructor(declaration: Stmt.Function) {
    super();
    this.declaration = declaration;
  }

  override call(interpreter: Interpreter, args: LoxObject[]): LoxObject {
    const environment = new Environment(interpreter.globals);
    for (let i = 0; i < this.declaration.params.length; ++i) {
      environment.define(this.declaration.params[i].lexeme, args[i]);
    }

    interpreter.executeBlock(this.declaration.body, environment);
    return null;
  }

  override arity() {
    return this.declaration.params.length;
  }

  override toString(): string {
    return `<fn ${this.declaration.name.lexeme}>`;
  }
}
