import { RuntimeError } from './runtime-error.ts';
import type { Token } from './token.ts';
import type { LoxObject } from './types.ts';

export class Environment {
  enclosing: Environment | null;
  values = new Map<string, LoxObject | undefined>();

  constructor(enclosing?: Environment | null) {
    this.enclosing = enclosing ?? null;
  }

  define(name: string, value: LoxObject | undefined): void {
    this.values.set(name, value);
  }

  ancestor(distance: number): Environment {
    let environment = this as Environment;
    for (let i = 0; i < distance; ++i) {
      environment = environment.enclosing as Environment;
    }

    return environment;
  }

  getAt(distance: number, name: string): LoxObject {
    return this.ancestor(distance).values.get(name) as LoxObject;
  }

  assignAt(distance: number, name: Token, value: LoxObject): void {
    this.ancestor(distance).values.set(name.lexeme, value);
  }

  get(name: Token): LoxObject | undefined {
    if (this.values.has(name.lexeme)) {
      return this.values.get(name.lexeme);
    }

    if (this.enclosing !== null) return this.enclosing.get(name);

    throw new RuntimeError(name, `Undefined variable '${name.lexeme}'.`);
  }

  assign(name: Token, value: LoxObject): void {
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
