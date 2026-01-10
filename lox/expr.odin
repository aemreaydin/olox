package lox

Expr :: union {
	^Binary,
	^Grouping,
	^Literal,
	^Unary,
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
