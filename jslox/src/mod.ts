import { AstPrinter } from './ast-printer.ts';
import { Parser } from './parser.ts';
import { Scanner } from './scanner.ts';
import { Token } from './token.ts';
import { TokenType as T } from './token-type.ts';

let hadError = false;

const args = Deno.args;

if (args.length > 1) {
  console.log('Usage: jslox [script]');
  Deno.exit(64);
} else if (args.length == 1) {
  await runFile(args[0]);
} else {
  runPrompt();
}

function runFile(path: string): void {
  const decoder = new TextDecoder('utf-8');
  const bytes = Deno.readFileSync(path);
  run(decoder.decode(bytes));

  if (hadError) Deno.exit(65);
}

function runPrompt(): void {
  while (true) {
    const line = prompt('> ');
    if (line == null) break;
    run(line);
    hadError = false;
  }
}

function run(source: string): void {
  const scanner = new Scanner(source);
  const tokens = scanner.scanTokens();
  const parser = new Parser(tokens);
  const expression = parser.parse();

  if (hadError) return;

  if (expression == null) throw new Error();

  console.log(new AstPrinter().print(expression));
}

export function error(line_or_token: number | Token, message: string): void {
  if (typeof line_or_token == 'number') report(line_or_token, '', message);
  else if (line_or_token.type == T.EOF) {
    report(line_or_token.line, ' at end', message);
  } else {
    report(line_or_token.line, ` at '${line_or_token.lexeme}'`, message);
  }
}

function report(line: number, where: string, message: string): void {
  console.error(`[line ${line}] Error${where}: ${message}`);
  hadError = true;
}
