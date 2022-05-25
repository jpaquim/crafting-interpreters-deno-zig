import { Scanner } from './scanner.ts';

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

  for (const token of tokens) {
    console.log(String(token));
  }
}

export function error(line: number, message: string): void {
  report(line, '', message);
}

function report(line: number, where: string, message: string): void {
  console.error(`[line ${line}] Error${where}: ${message}`);
  hadError = true;
}
