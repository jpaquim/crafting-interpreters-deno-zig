import { RuntimeError } from './runtime-error.ts';
import type { Token } from './token.ts';
import type { PlainObject } from './types.ts';

export class Environment {
  enclosing: Environment | null;
  values = new Map<string, PlainObject>();

  constructor(enclosing?: Environment | null) {
    this.enclosing = enclosing ?? null;
  }

  define(name: string, value: PlainObject): void {
    this.values.set(name, value);
  }

  get(name: Token): PlainObject {
    if (this.values.has(name.lexeme)) {
      return this.values.get(name.lexeme);
    }

    if (this.enclosing !== null) return this.enclosing.get(name);

    throw new RuntimeError(name, `Undefined variable '${name.lexeme}'.`);
  }

  assign(name: Token, value: PlainObject): void {
    if (this.values.has(name.lexeme)) {
      this.values.set(name.lexeme, value);
      return;
    }

    if (this.enclosing !== null) {
      this.enclosing.assign(name, value);
      return;
    }

    throw new RuntimeError(name, `Undefined variable '${name.lexeme}'.`);
  }
}
