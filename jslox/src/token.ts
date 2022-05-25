import { TokenType } from './token-type.ts';

export type Literal = string | null;

export class Token {
  type: TokenType;
  lexeme: string;
  literal: Literal;
  line: number;

  constructor(type: TokenType, lexeme: string, literal: Literal, line: number) {
    this.type = type;
    this.lexeme = lexeme;
    this.literal = literal;
    this.line = line;
  }

  toString(): string {
    return [TokenType[this.type], this.lexeme, this.literal].join(' ');
  }
}
