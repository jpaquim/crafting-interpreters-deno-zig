import type { LoxCallable } from './lox-callable.ts';
import type { LoxClass } from './lox-class.ts';
import type { LoxInstance } from './lox-instance.ts';

export type PlainObject = boolean | number | string | null;

export type LoxObject = LoxCallable | LoxClass | LoxInstance | PlainObject;
