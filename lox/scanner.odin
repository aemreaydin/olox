package lox

import "core:fmt"
import "core:strconv"

ScannerErrorKind :: enum {
	UNTERMINATED_STRING,
	UNTERMINATED_BLOCK_COMMENT,
	UNEXPECTED_CHARACTER,
	INVALID_NUMBER,
}

ScannerError :: struct {
	kind:    ScannerErrorKind,
	line:    int,
	column:  int,
	message: string,
}

Scanner :: struct {
	source:  string,
	tokens:  [dynamic]Token,
	errors:  [dynamic]ScannerError,
	start:   int,
	current: int,
	line:    int,
	column:  int,
}

init_scanner :: proc(source: string) -> (scanner: Scanner) {
	scanner.source = source
	scanner.tokens = make([dynamic]Token)
	scanner.errors = make([dynamic]ScannerError)
	scanner.start = 0
	scanner.current = 0
	scanner.line = 1
	scanner.column = 1
	return scanner
}

destroy_scanner :: proc(scanner: ^Scanner) {
	delete(scanner.tokens)
	delete(scanner.errors)
}

has_error :: proc(scanner: ^Scanner) -> bool {
	return len(scanner.errors) > 0
}

scan_tokens :: proc(scanner: ^Scanner) -> [dynamic]Token {
	for !is_eof(scanner) {
		scan_token(scanner)
	}
	scanner.start = scanner.current
	add_token(scanner, .EOF)
	return scanner.tokens
}

@(private = "file")
scan_token :: proc(scanner: ^Scanner) {
	scanner.start = scanner.current
	char := advance(scanner)
	switch char {
	case '(':
		add_token(scanner, TokenType.LEFT_PAREN)
	case ')':
		add_token(scanner, TokenType.RIGHT_PAREN)
	case '{':
		add_token(scanner, TokenType.LEFT_BRACE)
	case '}':
		add_token(scanner, TokenType.RIGHT_BRACE)
	case ',':
		add_token(scanner, TokenType.COMMA)
	case '.':
		add_token(scanner, TokenType.DOT)
	case '-':
		add_token(scanner, TokenType.MINUS)
	case '+':
		add_token(scanner, TokenType.PLUS)
	case ';':
		add_token(scanner, TokenType.SEMICOLON)
	case '?':
		add_token(scanner, TokenType.QUESTION)
	case ':':
		add_token(scanner, TokenType.COLON)
	case '*':
		add_token(scanner, TokenType.STAR)
	case '!':
		if match(scanner, '=') {
			add_token(scanner, TokenType.BANG_EQUAL)
		} else {
			add_token(scanner, TokenType.BANG)
		}
	case '=':
		if match(scanner, '=') {
			add_token(scanner, TokenType.EQUAL_EQUAL)
		} else {
			add_token(scanner, TokenType.EQUAL)
		}
	case '<':
		if match(scanner, '=') {
			add_token(scanner, TokenType.LESS_EQUAL)
		} else {
			add_token(scanner, TokenType.LESS)
		}
	case '>':
		if match(scanner, '=') {
			add_token(scanner, TokenType.GREATER_EQUAL)
		} else {
			add_token(scanner, TokenType.GREATER)
		}
	case '/':
		if peek(scanner) == '/' {
			skip_comment(scanner)
		} else if peek(scanner) == '*' {
			skip_block_comment(scanner)
		} else {
			add_token(scanner, TokenType.SLASH)
		}
	case '"':
		add_string_token(scanner)
	case '0' ..= '9':
		add_number_token(scanner)
	case 'a' ..= 'z', 'A' ..= 'Z', '_':
		add_identifier_token(scanner)
	case ' ', '\r', '\t', '\n':
	// Whitespace - do nothing, already advanced
	case:
		add_error(scanner, .UNEXPECTED_CHARACTER)
	}
}

@(private)
add_token :: proc(scanner: ^Scanner, token_type: TokenType) {
	lexeme := scanner.source[scanner.start:scanner.current]
	token := Token {
		token_type = token_type,
		lexeme     = lexeme,
		line       = scanner.line,
	}
	append(&scanner.tokens, token)
}

@(private)
add_string_token :: proc(scanner: ^Scanner) {
	for peek(scanner) != '"' && !is_eof(scanner) {
		advance(scanner)
	}

	if is_eof(scanner) {
		add_error(scanner, .UNTERMINATED_STRING)
		return
	}

	lexeme := scanner.source[scanner.start + 1:scanner.current]
	token := Token {
		token_type = .STRING,
		lexeme     = lexeme,
		line       = scanner.line,
		value      = lexeme,
	}

	append(&scanner.tokens, token)
	advance(scanner)
}

@(private)
add_number_token :: proc(scanner: ^Scanner) {
	for is_digit(peek(scanner)) {
		advance(scanner)
	}

	if peek(scanner) == '.' && is_digit(peek_next(scanner)) {
		advance(scanner)
		for is_digit(peek(scanner)) {
			advance(scanner)
		}
	}

	lexeme := scanner.source[scanner.start:scanner.current]
	value, ok := strconv.parse_f64(lexeme)
	if !ok {
		add_error(scanner, .INVALID_NUMBER)
		return
	}

	token := Token {
		token_type = .NUMBER,
		lexeme     = lexeme,
		line       = scanner.line,
		value      = value,
	}
	append(&scanner.tokens, token)
}

@(private)
add_identifier_token :: proc(scanner: ^Scanner) {
	for is_alpha_or_underscore(peek(scanner)) || is_digit(peek(scanner)) {
		advance(scanner)
	}

	lexeme := scanner.source[scanner.start:scanner.current]
	token_type := get_identifier_type(lexeme)

	value: Value

	#partial switch token_type {
	case .TRUE:
		value = true
	case .FALSE:
		value = false
	case .NIL:
		value = Nil{}
	}

	token := Token {
		token_type = token_type,
		lexeme     = lexeme,
		line       = scanner.line,
		value      = value,
	}
	append(&scanner.tokens, token)
}

@(private)
skip_comment :: proc(scanner: ^Scanner) {
	for peek(scanner) != '\n' && !is_eof(scanner) {
		advance(scanner)
	}
}

@(private)
skip_block_comment :: proc(scanner: ^Scanner) {
	depth := 1

	advance(scanner)
	advance(scanner)

	for depth != 0 {
		if peek(scanner) == '*' && peek_next(scanner) == '/' {
			depth -= 1
			advance(scanner)
		} else if peek(scanner) == '/' && peek_next(scanner) == '*' {
			depth += 1
			advance(scanner)
		}

		if is_eof(scanner) {
			add_error(scanner, .UNTERMINATED_BLOCK_COMMENT)
			return
		}

		advance(scanner)
	}
}

@(private = "file")
add_error :: proc(scanner: ^Scanner, kind: ScannerErrorKind) {
	message: string
	switch kind {
	case .UNTERMINATED_STRING:
		message = "Unterminated string"
	case .UNTERMINATED_BLOCK_COMMENT:
		message = "Unterminated block comment"
	case .UNEXPECTED_CHARACTER:
		message = fmt.tprintf("Unexpected character '%r'", peek(scanner))
	case .INVALID_NUMBER:
		message = "Invalid number literal"
	}

	error := ScannerError {
		kind    = kind,
		line    = scanner.line,
		column  = scanner.column,
		message = message,
	}
	append(&scanner.errors, error)
}

@(private = "file")
is_eof :: proc(scanner: ^Scanner) -> bool {
	return scanner.current >= len(scanner.source)
}

@(private = "file")
advance :: proc(scanner: ^Scanner) -> rune {
	ch := peek(scanner)
	scanner.current += 1
	if ch == '\n' {
		scanner.line += 1
		scanner.column = 1
	} else {
		scanner.column += 1
	}
	return ch
}

@(private = "file")
peek :: proc(scanner: ^Scanner) -> rune {
	if is_eof(scanner) {
		return 0
	}
	return rune(scanner.source[scanner.current])
}

@(private = "file")
match :: proc(scanner: ^Scanner, expected: rune) -> bool {
	if is_eof(scanner) {
		return false
	}
	if rune(scanner.source[scanner.current]) != expected {
		return false
	}
	scanner.current += 1
	scanner.column += 1
	return true
}

@(private = "file")
peek_next :: proc(scanner: ^Scanner) -> rune {
	if scanner.current + 1 >= len(scanner.source) {
		return 0
	}
	return rune(scanner.source[scanner.current + 1])
}

@(private = "file")
is_alpha_or_underscore :: proc(r: rune) -> bool {
	return (r >= 'a' && r <= 'z') || (r >= 'A' && r <= 'Z') || r == '_'
}

@(private = "file")
is_digit :: proc(r: rune) -> bool {
	return r >= '0' && r <= '9'
}

@(private = "file")
get_identifier_type :: proc(ident: string) -> TokenType {
	switch ident {
	case "and":
		return .AND
	case "class":
		return .CLASS
	case "else":
		return .ELSE
	case "false":
		return .FALSE
	case "for":
		return .FOR
	case "fn":
		return .FN
	case "if":
		return .IF
	case "nil":
		return .NIL
	case "or":
		return .OR
	case "print":
		return .PRINT
	case "return":
		return .RETURN
	case "super":
		return .SUPER
	case "this":
		return .THIS
	case "true":
		return .TRUE
	case "var":
		return .VAR
	case "while":
		return .WHILE
	case:
		return .IDENT
	}
}
