package lox

import "core:testing"

@(test)
test_make_string_basic :: proc(t: ^testing.T) {
	scanner := init_scanner(`"hello"`)
	defer destroy_scanner(&scanner)

	scan_tokens(&scanner)

	testing.expect_value(t, len(scanner.tokens), 2) // STRING + EOF
	testing.expect_value(t, scanner.tokens[0].lexeme, "hello")
	testing.expect_value(t, scanner.tokens[0].token_type, TokenType.STRING)
	testing.expect_value(t, scanner.tokens[0].line, 1)
}

@(test)
test_make_string_empty :: proc(t: ^testing.T) {
	scanner := init_scanner(`""`)
	defer destroy_scanner(&scanner)

	scan_tokens(&scanner)

	testing.expect_value(t, len(scanner.tokens), 2) // STRING + EOF
	testing.expect_value(t, scanner.tokens[0].lexeme, "")
	testing.expect_value(t, scanner.tokens[0].token_type, TokenType.STRING)
	testing.expect_value(t, scanner.tokens[0].line, 1)
}

@(test)
test_make_string_multiline :: proc(t: ^testing.T) {
	scanner := init_scanner("\"hello\nworld\"")
	defer destroy_scanner(&scanner)

	scan_tokens(&scanner)

	testing.expect_value(t, len(scanner.tokens), 2) // STRING + EOF
	testing.expect_value(t, scanner.tokens[0].lexeme, "hello\nworld")
	testing.expect_value(t, scanner.tokens[0].token_type, TokenType.STRING)
	testing.expect_value(t, scanner.tokens[0].line, 2)
}

@(test)
test_make_string_multiple_newlines :: proc(t: ^testing.T) {
	scanner := init_scanner("\"\nhello\nworld\"")
	defer destroy_scanner(&scanner)

	scan_tokens(&scanner)

	testing.expect_value(t, len(scanner.tokens), 2) // STRING + EOF
	testing.expect_value(t, scanner.tokens[0].lexeme, "\nhello\nworld")
	testing.expect_value(t, scanner.tokens[0].token_type, TokenType.STRING)
	testing.expect_value(t, scanner.tokens[0].line, 3)
}

@(test)
test_make_string_unterminated :: proc(t: ^testing.T) {
	scanner := init_scanner(`"unterminated`)
	defer destroy_scanner(&scanner)

	scan_tokens(&scanner)

	testing.expect_value(t, len(scanner.tokens), 1) // Only EOF
	testing.expect_value(t, len(scanner.errors), 1)
	testing.expect_value(t, scanner.errors[0].kind, ScannerErrorKind.UNTERMINATED_STRING)
}

@(test)
test_make_string_unterminated_with_newlines :: proc(t: ^testing.T) {
	scanner := init_scanner("\"unterminated\nunterminated_line")
	defer destroy_scanner(&scanner)

	scan_tokens(&scanner)

	testing.expect_value(t, len(scanner.tokens), 1) // Only EOF
	testing.expect_value(t, len(scanner.errors), 1)
	testing.expect_value(t, scanner.errors[0].kind, ScannerErrorKind.UNTERMINATED_STRING)
}

@(test)
test_add_number_token_integer :: proc(t: ^testing.T) {
	scanner := init_scanner("123")
	defer destroy_scanner(&scanner)

	add_number_token(&scanner)

	testing.expect_value(t, len(scanner.tokens), 1)
	testing.expect_value(t, scanner.tokens[0].lexeme, "123")
	testing.expect_value(t, scanner.tokens[0].token_type, TokenType.NUMBER)
	testing.expect_value(t, scanner.tokens[0].line, 1)
}

@(test)
test_add_number_token_decimal :: proc(t: ^testing.T) {
	scanner := init_scanner("123.456")
	defer destroy_scanner(&scanner)

	add_number_token(&scanner)

	testing.expect_value(t, len(scanner.tokens), 1)
	testing.expect_value(t, scanner.tokens[0].lexeme, "123.456")
	testing.expect_value(t, scanner.tokens[0].token_type, TokenType.NUMBER)
	testing.expect_value(t, scanner.tokens[0].line, 1)
}

@(test)
test_add_number_token_single_digit :: proc(t: ^testing.T) {
	scanner := init_scanner("0")
	defer destroy_scanner(&scanner)

	add_number_token(&scanner)

	testing.expect_value(t, len(scanner.tokens), 1)
	testing.expect_value(t, scanner.tokens[0].lexeme, "0")
	testing.expect_value(t, scanner.tokens[0].token_type, TokenType.NUMBER)
	testing.expect_value(t, scanner.tokens[0].line, 1)
}

@(test)
test_add_number_token_decimal_part_only :: proc(t: ^testing.T) {
	scanner := init_scanner("0.5")
	defer destroy_scanner(&scanner)

	add_number_token(&scanner)

	testing.expect_value(t, len(scanner.tokens), 1)
	testing.expect_value(t, scanner.tokens[0].lexeme, "0.5")
	testing.expect_value(t, scanner.tokens[0].token_type, TokenType.NUMBER)
	testing.expect_value(t, scanner.tokens[0].line, 1)
}

@(test)
test_add_number_token_trailing_dot :: proc(t: ^testing.T) {
	// A number followed by a dot with no digits should only consume the integer part
	scanner := init_scanner("123.abc")
	defer destroy_scanner(&scanner)

	add_number_token(&scanner)

	testing.expect_value(t, len(scanner.tokens), 1)
	testing.expect_value(t, scanner.tokens[0].lexeme, "123")
	testing.expect_value(t, scanner.tokens[0].token_type, TokenType.NUMBER)
}

@(test)
test_add_number_token_with_trailing_content :: proc(t: ^testing.T) {
	// Number followed by other content should only consume the number
	scanner := init_scanner("42 + 5")
	defer destroy_scanner(&scanner)

	add_number_token(&scanner)

	testing.expect_value(t, len(scanner.tokens), 1)
	testing.expect_value(t, scanner.tokens[0].lexeme, "42")
	testing.expect_value(t, scanner.tokens[0].token_type, TokenType.NUMBER)
}

@(test)
test_add_identifier_token_basic :: proc(t: ^testing.T) {
	scanner := init_scanner("foo")
	defer destroy_scanner(&scanner)

	add_identifier_token(&scanner)

	testing.expect_value(t, len(scanner.tokens), 1)
	testing.expect_value(t, scanner.tokens[0].lexeme, "foo")
	testing.expect_value(t, scanner.tokens[0].token_type, TokenType.IDENT)
	testing.expect_value(t, scanner.tokens[0].line, 1)
}

@(test)
test_add_identifier_token_single_char :: proc(t: ^testing.T) {
	scanner := init_scanner("x")
	defer destroy_scanner(&scanner)

	add_identifier_token(&scanner)

	testing.expect_value(t, len(scanner.tokens), 1)
	testing.expect_value(t, scanner.tokens[0].lexeme, "x")
	testing.expect_value(t, scanner.tokens[0].token_type, TokenType.IDENT)
}

@(test)
test_add_identifier_token_with_digits :: proc(t: ^testing.T) {
	scanner := init_scanner("foo123")
	defer destroy_scanner(&scanner)

	add_identifier_token(&scanner)

	testing.expect_value(t, len(scanner.tokens), 1)
	testing.expect_value(t, scanner.tokens[0].lexeme, "foo123")
	testing.expect_value(t, scanner.tokens[0].token_type, TokenType.IDENT)
}

@(test)
test_add_identifier_token_mixed_case :: proc(t: ^testing.T) {
	scanner := init_scanner("FooBar")
	defer destroy_scanner(&scanner)

	add_identifier_token(&scanner)

	testing.expect_value(t, len(scanner.tokens), 1)
	testing.expect_value(t, scanner.tokens[0].lexeme, "FooBar")
	testing.expect_value(t, scanner.tokens[0].token_type, TokenType.IDENT)
}

@(test)
test_add_identifier_token_keyword_and :: proc(t: ^testing.T) {
	scanner := init_scanner("and")
	defer destroy_scanner(&scanner)

	add_identifier_token(&scanner)

	testing.expect_value(t, len(scanner.tokens), 1)
	testing.expect_value(t, scanner.tokens[0].lexeme, "and")
	testing.expect_value(t, scanner.tokens[0].token_type, TokenType.AND)
}

@(test)
test_add_identifier_token_keyword_class :: proc(t: ^testing.T) {
	scanner := init_scanner("class")
	defer destroy_scanner(&scanner)

	add_identifier_token(&scanner)

	testing.expect_value(t, len(scanner.tokens), 1)
	testing.expect_value(t, scanner.tokens[0].lexeme, "class")
	testing.expect_value(t, scanner.tokens[0].token_type, TokenType.CLASS)
}

@(test)
test_add_identifier_token_keyword_if :: proc(t: ^testing.T) {
	scanner := init_scanner("if")
	defer destroy_scanner(&scanner)

	add_identifier_token(&scanner)

	testing.expect_value(t, len(scanner.tokens), 1)
	testing.expect_value(t, scanner.tokens[0].lexeme, "if")
	testing.expect_value(t, scanner.tokens[0].token_type, TokenType.IF)
}

@(test)
test_add_identifier_token_keyword_fn :: proc(t: ^testing.T) {
	scanner := init_scanner("fn")
	defer destroy_scanner(&scanner)

	add_identifier_token(&scanner)

	testing.expect_value(t, len(scanner.tokens), 1)
	testing.expect_value(t, scanner.tokens[0].lexeme, "fn")
	testing.expect_value(t, scanner.tokens[0].token_type, TokenType.FN)
}

@(test)
test_add_identifier_token_keyword_var :: proc(t: ^testing.T) {
	scanner := init_scanner("var")
	defer destroy_scanner(&scanner)

	add_identifier_token(&scanner)

	testing.expect_value(t, len(scanner.tokens), 1)
	testing.expect_value(t, scanner.tokens[0].lexeme, "var")
	testing.expect_value(t, scanner.tokens[0].token_type, TokenType.VAR)
}

@(test)
test_add_identifier_token_keyword_while :: proc(t: ^testing.T) {
	scanner := init_scanner("while")
	defer destroy_scanner(&scanner)

	add_identifier_token(&scanner)

	testing.expect_value(t, len(scanner.tokens), 1)
	testing.expect_value(t, scanner.tokens[0].lexeme, "while")
	testing.expect_value(t, scanner.tokens[0].token_type, TokenType.WHILE)
}

@(test)
test_add_identifier_token_keyword_nil :: proc(t: ^testing.T) {
	scanner := init_scanner("nil")
	defer destroy_scanner(&scanner)

	add_identifier_token(&scanner)

	testing.expect_value(t, len(scanner.tokens), 1)
	testing.expect_value(t, scanner.tokens[0].lexeme, "nil")
	testing.expect_value(t, scanner.tokens[0].token_type, TokenType.NIL)
}

@(test)
test_add_identifier_token_keyword_true :: proc(t: ^testing.T) {
	scanner := init_scanner("true")
	defer destroy_scanner(&scanner)

	add_identifier_token(&scanner)

	testing.expect_value(t, len(scanner.tokens), 1)
	testing.expect_value(t, scanner.tokens[0].lexeme, "true")
	testing.expect_value(t, scanner.tokens[0].token_type, TokenType.TRUE)
}

@(test)
test_add_identifier_token_keyword_false :: proc(t: ^testing.T) {
	scanner := init_scanner("false")
	defer destroy_scanner(&scanner)

	add_identifier_token(&scanner)

	testing.expect_value(t, len(scanner.tokens), 1)
	testing.expect_value(t, scanner.tokens[0].lexeme, "false")
	testing.expect_value(t, scanner.tokens[0].token_type, TokenType.FALSE)
}

@(test)
test_add_identifier_token_keyword_return :: proc(t: ^testing.T) {
	scanner := init_scanner("return")
	defer destroy_scanner(&scanner)

	add_identifier_token(&scanner)

	testing.expect_value(t, len(scanner.tokens), 1)
	testing.expect_value(t, scanner.tokens[0].lexeme, "return")
	testing.expect_value(t, scanner.tokens[0].token_type, TokenType.RETURN)
}

@(test)
test_add_identifier_token_keyword_prefix :: proc(t: ^testing.T) {
	// "andy" starts with "and" but should be an identifier, not a keyword
	scanner := init_scanner("andy")
	defer destroy_scanner(&scanner)

	add_identifier_token(&scanner)

	testing.expect_value(t, len(scanner.tokens), 1)
	testing.expect_value(t, scanner.tokens[0].lexeme, "andy")
	testing.expect_value(t, scanner.tokens[0].token_type, TokenType.IDENT)
}

@(test)
test_add_identifier_token_with_trailing_content :: proc(t: ^testing.T) {
	scanner := init_scanner("foo + bar")
	defer destroy_scanner(&scanner)

	add_identifier_token(&scanner)

	testing.expect_value(t, len(scanner.tokens), 1)
	testing.expect_value(t, scanner.tokens[0].lexeme, "foo")
	testing.expect_value(t, scanner.tokens[0].token_type, TokenType.IDENT)
}

