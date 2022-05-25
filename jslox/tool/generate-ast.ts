const args = Deno.args;

if (args.length != 1) {
  console.error('Usage: generate_ast <output directory>');
  Deno.exit(64);
}
const outputDir = args[0];
defineAst(outputDir, 'Expr', [
  'Binary   : left: Expr, operator: Token, right: Expr',
  'Grouping : expression: Expr',
  'Literal  : value: LiteralObject',
  'Unary    : operator: Token, right: Expr',
]);

function defineAst(outputDir: string, baseName: string, types: string[]): void {
  const path = `${outputDir}/${baseName.toLowerCase()}.ts`;
  const file = Deno.openSync(path, { write: true, create: true });
  const writer = file.writable.getWriter();
  const encoder = new TextEncoder();

  writer.write(
    encoder.encode(
      `import { LiteralObject, Token } from '../src/token.ts';\n\n`,
    ),
  );
  writer.write(encoder.encode(`export abstract class ${baseName} {\n`));

  for (const type of types) {
    const separatorIndex = type.indexOf(':');
    const className = type.slice(0, separatorIndex).trim();
    const fields = type.slice(separatorIndex + 1).trim();
    defineType(writer, baseName, className, fields);
  }

  writer.write(encoder.encode('}\n'));
  writer.close();
}

function defineType(
  writer: WritableStreamDefaultWriter,
  baseName: string,
  className: string,
  fieldList: string,
) {
  const encoder = new TextEncoder();

  writer.write(
    encoder.encode(
      `  static ${className} = class ${className} extends ${baseName} {\n`,
    ),
  );

  writer.write(encoder.encode(`    constructor(${fieldList}) {\n`));
  writer.write(encoder.encode('      super();\n'));

  const fields = fieldList.split(', ');
  for (const field of fields) {
    const name = field.split(':')[0];
    writer.write(encoder.encode(`      this.${name} = ${name};\n`));
  }

  writer.write(encoder.encode('    }\n'));

  writer.write(encoder.encode('\n'));
  for (const field of fields) {
    writer.write(encoder.encode(`    ${field};\n`));
  }

  writer.write(encoder.encode('  };\n'));
}
