const args = Deno.args;

if (args.length != 1) {
  console.error('Usage: generate_ast <output directory>');
  Deno.exit(64);
}
const outputDir = args[0];
defineAst(outputDir, 'Expr', [
  'Assign   : name: Token, value: Expr',
  'Binary   : left: Expr, operator: Token, right: Expr',
  'Call     : callee: Expr, paren: Token, args: Expr[]',
  'Grouping : expression: Expr',
  'Literal  : value: PlainObject',
  'Logical  : left: Expr, operator: Token, right: Expr',
  'Ternary  : predicate: Expr, left: Expr, right: Expr',
  'Unary    : operator: Token, right: Expr',
  'Variable : name: Token',
]);

defineAst(outputDir, 'Stmt', [
  'Block      : statements: Stmt[]',
  'Break      : ',
  'Continue   : ',
  'Expression : expression: Expr',
  'Function   : name: Token, params: Token[], body: Stmt[]',
  'If         : condition: Expr, thenBranch: Stmt, elseBranch?: Stmt',
  'Print      : expression: Expr',
  'Return     : keyword: Token, value?: Expr',
  'Var        : name: Token, initializer?: Expr',
  'While      : condition: Expr, body: Stmt',
]);

function defineAst(outputDir: string, baseName: string, types: string[]): void {
  const path = `${outputDir}/${baseName.toLowerCase()}.ts`;
  const file = Deno.openSync(path, { write: true, create: true });
  const writer = file.writable.getWriter();
  const encoder = new TextEncoder();

  defineTypeImports(writer, baseName, types);

  writer.write(encoder.encode('\n'));

  writer.write(
    encoder.encode(`export abstract class ${baseName} {
  abstract accept<R>(visitor: Visitor<R>): R;\n}\n\n`),
  );

  defineVisitor(writer, baseName, types);

  for (const type of types) {
    writer.write(encoder.encode('\n'));
    const separatorIndex = type.indexOf(':');
    const className = type.slice(0, separatorIndex).trim();
    const fields = type.slice(separatorIndex + 1).trim();
    defineType(writer, baseName, className, fields);
  }

  writer.close();
}

function defineType(
  writer: WritableStreamDefaultWriter,
  baseName: string,
  className: string,
  fieldList: string,
): void {
  const encoder = new TextEncoder();

  writer.write(
    encoder.encode(`export class ${className} extends ${baseName} {\n`),
  );

  if (fieldList.length > 0) {
    // fields
    const fields = fieldList.split(', ');
    for (const field of fields) {
      writer.write(encoder.encode(`  ${field};\n`));
    }
    writer.write(encoder.encode('\n'));
    writer.write(encoder.encode(`  constructor(${fieldList}) {\n`));
    writer.write(encoder.encode('    super();\n'));
    for (const field of fields) {
      const name = field.split(':')[0].split('?')[0];
      writer.write(encoder.encode(`    this.${name} = ${name};\n`));
    }

    writer.write(encoder.encode('  }\n'));
  }

  // visitor pattern
  writer.write(encoder.encode('\n'));
  writer.write(
    encoder.encode('  override accept<R>(visitor: Visitor<R>): R {\n'),
  );
  writer.write(
    encoder.encode(`    return visitor.visit${className}${baseName}(this);\n`),
  );
  writer.write(encoder.encode('  }\n'));
  writer.write(encoder.encode('}\n'));
}

function defineVisitor(
  writer: WritableStreamDefaultWriter,
  baseName: string,
  types: string[],
): void {
  const encoder = new TextEncoder();

  writer.write(encoder.encode('export interface Visitor<R> {\n'));

  for (const type of types) {
    const typeName = type.split(':')[0].trim();

    writer.write(
      encoder.encode(
        `  visit${typeName}${baseName}(${baseName.toLowerCase()}: ${typeName}): R;\n`,
      ),
    );
  }

  writer.write(encoder.encode('}\n'));
}

function defineTypeImports(
  writer: WritableStreamDefaultWriter,
  baseName: string,
  types: string[],
): void {
  const typeImports: Record<string, string> = {
    Expr: '../src/expr.ts',
    Token: '../src/token.ts',
    PlainObject: '../src/types.ts',
  };

  const encoder = new TextEncoder();

  const imports = [
    ...types.reduce((importsSet, type) => {
      const separatorIndex = type.indexOf(':');
      const fields = type
        .slice(separatorIndex + 1)
        .split(', ')
        .map(
          field =>
            field.split(':')[1]?.split('|')[0].split('[')[0].trim() ?? null,
        );
      for (const field of fields.filter(
        field => field !== null && field !== baseName,
      )) {
        importsSet.add(field);
      }
      return importsSet;
    }, new Set<string>()),
  ];

  for (const type of imports) {
    if (!typeImports[type]) throw new Error(`Unknown type: ${type}`);
    writer.write(
      encoder.encode(`import type { ${type} } from '${typeImports[type]}';\n`),
    );
  }
}
