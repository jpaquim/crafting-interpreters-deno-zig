import { Binary, Expr, Grouping, Literal, Unary, Visitor } from './expr.ts';
import { Token } from './token.ts';
import { TokenType } from './token-type.ts';

export class AstPrinter implements Visitor<string> {
  print(expr: Expr): string {
    return expr.accept(this);
  }

  visitBinaryExpr(expr: Binary): string {
    return this.parenthesize(expr.operator.lexeme, expr.left, expr.right);
  }

  visitGroupingExpr(expr: Grouping): string {
    return this.parenthesize('group', expr.expression);
  }

  visitLiteralExpr(expr: Literal): string {
    if (expr.value == null) return 'nil';
    return String(expr.value);
  }

  visitUnaryExpr(expr: Unary): string {
    return this.parenthesize(expr.operator.lexeme, expr.right);
  }

  parenthesize(name: string, ...exprs: Expr[]): string {
    let result = `(${name}`;
    for (const expr of exprs) {
      result = result.concat(` ${expr.accept(this)}`);
    }
    return result + ')';
  }
}

const expression = new Binary(
  new Unary(new Token(TokenType.MINUS, '-', null, 1), new Literal(123)),
  new Token(TokenType.STAR, '*', null, 1),
  new Grouping(new Literal(45.67)),
);

console.log(new AstPrinter().print(expression));
