import type { LoxClass } from './lox-class.ts';
import { RuntimeError } from './runtime-error.ts';
import type { LoxObject } from './types.ts';
import type { Token } from './token.ts';

export class LoxInstance {
  klass: LoxClass;
  fields = new Map<string, LoxObject>();

  constructor(klass: LoxClass) {
    this.klass = klass;
  }

  get(name: Token): LoxObject {
    if (this.fields.has(name.lexeme)) {
      return this.fields.get(name.lexeme) as LoxObject;
    }

    const method = this.klass.findMethod(name.lexeme);
    if (method !== undefined) return method;

    throw new RuntimeError(name, `Undefined property '${name.lexeme}'.`);
  }

  set(name: Token, value: LoxObject): void {
    this.fields.set(name.lexeme, value);
  }

  toString(): string {
    return `${this.klass.name} instance`;
  }
}
