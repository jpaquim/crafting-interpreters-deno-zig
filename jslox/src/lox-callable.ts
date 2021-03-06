import type { Interpreter } from './interpreter.ts';
import type { LoxObject } from './types.ts';

export abstract class LoxCallable {
  abstract arity(): number;
  abstract call(interpreter: Interpreter, args: LoxObject[]): LoxObject;
}
