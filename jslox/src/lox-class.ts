import type { Interpreter } from './interpreter.ts';
import { LoxCallable } from './lox-callable.ts';
import { LoxInstance } from './lox-instance.ts';
import type { LoxObject } from './types.ts';

export class LoxClass extends LoxCallable {
  name: string;

  constructor(name: string) {
    super();
    this.name = name;
  }

  toString(): string {
    return this.name;
  }

  override call(_interpreter: Interpreter, args: LoxObject[]): LoxObject {
    const instance = new LoxInstance(this);
    return instance;
  }

  override arity(): number {
    return 0;
  }
}
