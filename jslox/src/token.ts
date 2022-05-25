import { TokenType } from './token-type.ts';
import type { PlainObject } from './types.ts';

export class Token {
  type: TokenType;
  lexeme: string;
  literal: PlainObject;
  line: number;

  constructor(
    type: TokenType,
    lexeme: string,
    literal: PlainObject,
    line: number,
  ) {
    this.type = type;
    this.lexeme = lexeme;
    this.literal = literal;
    this.line = line;
  }

  toString(): string {
    return [TokenType[this.type], this.lexeme, this.literal].join(' ');
  }
}
