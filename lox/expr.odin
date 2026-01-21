package lox

Expr :: union {
	^Binary,
	^Grouping,
	^Literal,
	^Unary,
	^Condition,
}

Binary :: struct {
	left:     Expr,
	operator: Token,
	right:    Expr,
}

Grouping :: struct {
	expression: Expr,
}

Literal :: struct {
	value: Value,
}

Unary :: struct {
	operator:   Token,
	expression: Expr,
}

Condition :: struct {
	expression:      Expr,
	then_expression: Expr,
	else_expression: Expr,
}
