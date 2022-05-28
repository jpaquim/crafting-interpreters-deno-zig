import type { LoxCallable } from './lox-callable.ts';
import type { LoxClass } from './lox-class.ts';

export type PlainObject = boolean | number | string | null;

export type LoxObject = LoxCallable | LoxClass | PlainObject;
