package lox

import "core:fmt"

print_ast :: proc(expr: Expr) {
	switch e in expr {
	case ^Binary:
		print_ast(e.left)
		fmt.printf(" %s ", e.operator.lexeme)
		print_ast(e.right)
	case ^Grouping:
		fmt.print("( ")
		print_ast(e.expression)
		fmt.print(" )")
	case ^Literal:
		fmt.print(e.value)
	case ^Unary:
		fmt.print(e.operator.lexeme)
		print_ast(e.expression)
	case:
		return
	}
}
