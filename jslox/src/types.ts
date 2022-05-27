import type { Callable } from './callable.ts';

export type PlainObject = boolean | number | string | null;

export type LoxObject = PlainObject | Callable;
