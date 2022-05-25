import { TokenType } from './token-type.ts';

export type LiteralObject = number | string | null;

export class Token {
  type: TokenType;
  lexeme: string;
  literal: LiteralObject;
  line: number;

  constructor(
    type: TokenType,
    lexeme: string,
    literal: LiteralObject,
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
