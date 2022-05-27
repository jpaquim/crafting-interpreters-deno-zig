import type { LoxObject } from './types.ts';

export class Return extends Error {
  value?: LoxObject;

  constructor(value?: LoxObject) {
    super();
    this.value = value;
  }
}
