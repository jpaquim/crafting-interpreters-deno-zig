import type { LoxClass } from './lox-class.ts';

export class LoxInstance {
  klass: LoxClass;

  constructor(klass: LoxClass) {
    this.klass = klass;
  }

  toString(): string {
    return `${this.klass.name} instance`;
  }
}
