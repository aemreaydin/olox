package lox

import "core:fmt"
import "core:mem/virtual"

ParserErrorKind :: enum {
	NONE,
	UNEXPECTED_TOKEN,
	EXPECTED_EXPRESSION,
}

ParserError :: struct {
	kind:    ParserErrorKind,
	token:   Token,
	message: string,
}

Parser :: struct {
	tokens:  [dynamic]Token,
	current: int,
	arena:   virtual.Arena,
}

init_parser :: proc(tokens: [dynamic]Token) -> Parser {
	arena: virtual.Arena
	if err := virtual.arena_init_growing(&arena); err != nil {
		panic(fmt.tprintf("parser arena_init_growing failed with %v", err))
	}
	return Parser{tokens = tokens, current = 0, arena = arena}
}

parse :: proc(using parser: ^Parser) -> (Expr, ParserError) {
	context.allocator = virtual.arena_allocator(&arena)
	return consume_expression(parser)
}

destroy_parser :: proc(using parser: ^Parser) {
	// TODO: Check how to properly know what/who owns what - tokens
	virtual.arena_destroy(&arena)
}

consume_expression :: proc(using parser: ^Parser) -> (Expr, ParserError) {
	return consume_comma(parser)
}

consume_comma :: proc(using parser: ^Parser) -> (Expr, ParserError) {
	left, left_err := consume_ternary(parser)
	if left_err.kind != .NONE {
		return {}, left_err
	}

	for match(parser, .COMMA) {
		operator := advance(parser)
		right, right_err := consume_ternary(parser)
		if right_err.kind != .NONE {
			return {}, right_err
		}

		left = new_clone(Binary{left = left, operator = operator, right = right})
	}

	return left, {}
}

consume_ternary :: proc(using parser: ^Parser) -> (Expr, ParserError) {
	left, err := consume_equality(parser)
	if err.kind != .NONE {
		return {}, err
	}

	for match(parser, .QUESTION) {
		operator := advance(parser)
		then_expr, then_err := consume_expression(parser)
		if then_err.kind != .NONE {
			return {}, then_err
		}

		_, consume_err := consume(parser, .COLON)
		if consume_err.kind != .NONE {
			return {}, consume_err
		}

		else_expr, else_err := consume_ternary(parser)
		if else_err.kind != .NONE {
			return {}, else_err
		}

		left = new_clone(
			Condition{expression = left, then_expression = then_expr, else_expression = else_expr},
		)
	}
	return left, {}
}

consume_equality :: proc(using parser: ^Parser) -> (Expr, ParserError) {
	left, err := consume_comparison(parser)
	if err.kind != .NONE {
		return {}, err
	}

	for match(parser, .EQUAL_EQUAL, .BANG_EQUAL) {
		operator := advance(parser)
		right, right_err := consume_comparison(parser)
		if right_err.kind != .NONE {
			return {}, right_err
		}

		left = new_clone(Binary{left = left, operator = operator, right = right})
	}

	return left, {}
}

consume_comparison :: proc(using parser: ^Parser) -> (Expr, ParserError) {
	left, err := consume_term(parser)
	if err.kind != .NONE {
		return {}, err
	}

	for match(parser, .GREATER, .GREATER_EQUAL, .LESS, .LESS_EQUAL) {
		operator := advance(parser)
		right, right_err := consume_term(parser)
		if right_err.kind != .NONE {
			return {}, right_err
		}

		left = new_clone(Binary{left = left, operator = operator, right = right})
	}
	return left, {}
}

consume_term :: proc(using parser: ^Parser) -> (Expr, ParserError) {
	left, err := consume_factor(parser)
	if err.kind != .NONE {
		return {}, err
	}

	for match(parser, .MINUS, .PLUS) {
		operator := advance(parser)
		right, right_err := consume_factor(parser)
		if right_err.kind != .NONE {
			return {}, right_err
		}

		left = new_clone(Binary{left = left, operator = operator, right = right})
	}
	return left, {}
}

consume_factor :: proc(using parser: ^Parser) -> (Expr, ParserError) {
	left, err := consume_unary(parser)
	if err.kind != .NONE {
		return {}, err
	}

	for match(parser, .SLASH, .STAR) {
		operator := advance(parser)
		right, right_err := consume_unary(parser)
		if right_err.kind != .NONE {
			return {}, right_err
		}

		left = new_clone(Binary{left = left, operator = operator, right = right})
	}
	return left, {}
}

consume_unary :: proc(using parser: ^Parser) -> (Expr, ParserError) {
	for match(parser, .MINUS, .BANG) {
		operator := advance(parser)
		unary, err := consume_unary(parser)
		if err.kind != .NONE {
			return {}, err
		}

		return new_clone(Unary{expression = unary, operator = operator}), {}
	}
	return consume_primary(parser)
}

consume_primary :: proc(using parser: ^Parser) -> (Expr, ParserError) {
	token := advance(parser)
	#partial switch token.token_type {
	case .FALSE, .TRUE, .NUMBER, .STRING, .NIL:
		return new_clone(Literal{value = token.value}), {}
	case .LEFT_PAREN:
		expr, err := consume_expression(parser)
		if err.kind != .NONE {
			return {}, err
		}

		_, err = consume(parser, .RIGHT_PAREN)
		if err.kind != .NONE {
			return {}, err
		}

		return new_clone(Grouping{expression = expr}), {}
	}
	return {}, ParserError{kind = .EXPECTED_EXPRESSION, token = token, message = fmt.tprintf("Expected expression but got '%v'", token.token_type)}
}

synchronize :: proc(using parser: ^Parser) {
	advance(parser)
	for !is_eof(parser) {
		if previous(parser).token_type == .SEMICOLON {
			return
		}

		#partial switch peek(parser).token_type {
		case .CLASS, .FOR, .FN, .IF, .PRINT, .RETURN, .VAR, .WHILE:
			return
		}

		advance(parser)
	}
}

@(private = "file")
match :: proc(parser: ^Parser, tokens: ..TokenType) -> bool {
	if is_eof(parser) {
		return false
	}

	for token in tokens {
		if token == peek(parser).token_type {
			return true
		}
	}
	return false
}

@(private = "file")
consume :: proc(parser: ^Parser, expected: TokenType) -> (Token, ParserError) {
	if peek(parser).token_type == expected {
		return advance(parser), {}
	}
	return {}, ParserError{kind = .UNEXPECTED_TOKEN, token = peek(parser), message = fmt.tprintf("Expected '%v' but got '%v'", expected, peek(parser).token_type)}
}

@(private = "file")
advance :: proc(using parser: ^Parser) -> Token {
	current += 1
	return previous(parser)
}

@(private = "file")
peek :: proc(using parser: ^Parser) -> Token {
	if current >= len(tokens) {
		return tokens[len(tokens) - 1]
	}
	return tokens[current]
}

@(private = "file")
is_eof :: proc(using parser: ^Parser) -> bool {
	return peek(parser).token_type == .EOF
}

@(private = "file")
previous :: proc(using parser: ^Parser) -> Token {
	if current == 0 {
		return tokens[0]
	}
	return tokens[current - 1]
}
