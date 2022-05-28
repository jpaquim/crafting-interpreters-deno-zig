import type { Interpreter } from './interpreter.ts';
import { LoxCallable } from './lox-callable.ts';
import type { LoxFunction } from './lox-function.ts';
import { LoxInstance } from './lox-instance.ts';
import type { LoxObject } from './types.ts';

export class LoxClass extends LoxCallable {
  name: string;
  methods: Map<string, LoxFunction>;

  constructor(name: string, methods: Map<string, LoxFunction>) {
    super();
    this.name = name;
    this.methods = methods;
  }

  findMethod(name: string): LoxFunction | undefined {
    if (this.methods.has(name)) {
      return this.methods.get(name);
    }
  }

  toString(): string {
    return this.name;
  }

  override call(interpreter: Interpreter, args: LoxObject[]): LoxObject {
    const instance = new LoxInstance(this);
    const initializer = this.findMethod('init');
    if (initializer !== undefined) {
      initializer.bind(instance).call(interpreter, args);
    }

    return instance;
  }

  override arity(): number {
    const initializer = this.findMethod('init');
    if (initializer === undefined) return 0;
    return initializer.arity();
  }
}
