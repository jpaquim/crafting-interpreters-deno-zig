import { error } from './mod.ts';
import { Token } from './token.ts';
import { TokenType } from './token-type.ts';

const T = TokenType;

export class Scanner {
  source: string;
  tokens: Token[] = [];

  start = 0;
  current = 0;
  line = 1;

  constructor(source: string) {
    this.source = source;
  }

  scanTokens(): Token[] {
    while (!this.isAtEnd()) {
      this.start = this.current;
      this.scanToken();
    }

    this.tokens.push(new Token(T.EOF, '', null, this.line));
    return this.tokens;
  }

  isAtEnd(): boolean {
    return this.current >= this.source.length;
  }

  scanToken(): void {
    const c = this.advance();
    switch (c) {
      case '(':
        this.addToken(T.LEFT_PAREN);
        break;
      case ')':
        this.addToken(T.RIGHT_PAREN);
        break;
      case '{':
        this.addToken(T.LEFT_BRACE);
        break;
      case '}':
        this.addToken(T.RIGHT_BRACE);
        break;
      case ',':
        this.addToken(T.COMMA);
        break;
      case '.':
        this.addToken(T.DOT);
        break;
      case '-':
        this.addToken(T.MINUS);
        break;
      case '+':
        this.addToken(T.PLUS);
        break;
      case ';':
        this.addToken(T.SEMICOLON);
        break;
      case '*':
        this.addToken(T.STAR);
        break;
      default:
        error(this.line, 'Unexpected character.');
        break;
    }
  }

  advance(): string {
    return this.source[this.current++];
  }

  addToken(type: TokenType, literal: object | null = null): void {
    const text = this.source.substring(this.start, this.current);
    this.tokens.push(new Token(type, text, literal, this.line));
  }
}
