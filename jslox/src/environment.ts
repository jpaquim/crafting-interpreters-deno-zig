import { RuntimeError } from './runtime-error.ts';
import type { Token } from './token.ts';
import type { PlainObject } from './types.ts';

export class Environment {
  values = new Map<string, PlainObject>();

  define(name: string, value: PlainObject): void {
    this.values.set(name, value);
  }

  get(name: Token): PlainObject {
    if (this.values.has(name.lexeme)) {
      return this.values.get(name.lexeme) as PlainObject;
    }

    throw new RuntimeError(name, `Undefined variable '${name.lexeme}'.`);
  }

  assign(name: Token, value: PlainObject): void {
    if (this.values.has(name.lexeme)) {
      this.values.set(name.lexeme, value);
      return;
    }

    throw new RuntimeError(name, `Undefined variable '${name.lexeme}'.`);
  }
}
