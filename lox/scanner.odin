package lox

import "core:strconv"
import "core:strings"
import "core:unicode"
import "core:unicode/utf8/utf8string"

ScannerError :: enum {
	UNTERMINATED_STRING,
	UNTERMINATED_BLOCK_COMMENT,
	UNEXPECTED_CHARACTER,
	INVALID_NUMBER,
}

Scanner :: struct {
	source:  utf8string.String,
	tokens:  [dynamic]Token,
	errors:  [dynamic]ScannerError,
	start:   int,
	current: int,
	line:    int,
}

make_scanner :: proc(source: string) -> (scanner: Scanner) {
	utf8string.init(&scanner.source, source)
	scanner.tokens = make([dynamic]Token)
	scanner.errors = make([dynamic]ScannerError)
	scanner.start = 0
	scanner.current = 0
	scanner.line = 1
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
	return scanner.tokens
}

@(private = "file")
scan_token :: proc(scanner: ^Scanner) {
	scanner.start = scanner.current
	char := peek(scanner)
	switch (char) {
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
	case '*':
		add_token(scanner, TokenType.STAR)
	case '!':
		if peek_next(scanner) == '=' {
			add_token(scanner, TokenType.BANG_EQUAL)
			advance(scanner)
		} else {
			add_token(scanner, TokenType.BANG)
		}
	case '=':
		if peek_next(scanner) == '=' {
			add_token(scanner, TokenType.EQUAL_EQUAL)
			advance(scanner)
		} else {
			add_token(scanner, TokenType.EQUAL)
		}
	case '<':
		if peek_next(scanner) == '=' {
			add_token(scanner, TokenType.LESS_EQUAL)
			advance(scanner)
		} else {
			add_token(scanner, TokenType.LESS)
		}
	case '>':
		if peek_next(scanner) == '=' {
			add_token(scanner, TokenType.GREATER_EQUAL)
			advance(scanner)
		} else {
			add_token(scanner, TokenType.GREATER)
		}
	case '/':
		if peek_next(scanner) == '/' {
			add_comment_token(scanner)
		} else if peek_next(scanner) == '*' {
			add_block_comment_token(scanner)
		} else {
			add_token(scanner, TokenType.SLASH)
		}
	case '"':
		add_string_token(scanner)
	case '0' ..= '9':
		add_number_token(scanner)
	case 'a' ..= 'z', 'A' ..= 'Z':
		add_identifier_token(scanner)
	case ' ', '\r', '\t':
		advance(scanner)
	case '\n':
		advance(scanner)
		scanner.line += 1
	case:
		add_error(scanner, .UNEXPECTED_CHARACTER)
	}
}

@(private)
add_token :: proc(scanner: ^Scanner, token_type: TokenType) {
	token := Token {
		token_type = token_type,
		lexeme     = utf8string.slice(&scanner.source, scanner.start, scanner.current),
		line       = scanner.line,
	}
	append(&scanner.tokens, token)
	advance(scanner)
}

@(private)
add_string_token :: proc(scanner: ^Scanner) {
	advance(scanner)

	for peek(scanner) != '"' && !is_eof(scanner) {
		if (peek(scanner) == '\n') {
			scanner.line += 1
		}
		advance(scanner)
	}

	if is_eof(scanner) {
		add_error(scanner, .UNTERMINATED_STRING)
		return
	}

	lexeme := utf8string.slice(&scanner.source, scanner.start + 1, scanner.current)
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
	for unicode.is_digit(peek(scanner)) {
		advance(scanner)
	}

	if peek(scanner) == '.' && unicode.is_digit(peek_next(scanner)) {
		advance(scanner)
		for unicode.is_digit(peek(scanner)) {
			advance(scanner)
		}
	}

	lexeme := utf8string.slice(&scanner.source, scanner.start, scanner.current)
	value, ok := strconv.parse_f64(lexeme)
	if !ok {
		add_error(scanner, .INVALID_NUMBER)
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
	for unicode.is_alpha(peek(scanner)) || unicode.is_digit(peek(scanner)) {
		advance(scanner)
	}

	lexeme := utf8string.slice(&scanner.source, scanner.start, scanner.current)
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
	}
	append(&scanner.tokens, token)
}

@(private)
add_comment_token :: proc(scanner: ^Scanner) {
	for peek(scanner) != '\n' && !is_eof(scanner) {
		advance(scanner)
	}

	lexeme := utf8string.slice(&scanner.source, scanner.start + 2, scanner.current)
	lexeme = strings.trim_left(lexeme, " ")
	token := Token {
		token_type = .COMMENT,
		lexeme     = lexeme,
		line       = scanner.line,
	}
	append(&scanner.tokens, token)
}

@(private)
add_block_comment_token :: proc(scanner: ^Scanner) {
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

		if peek(scanner) == '\n' {
			scanner.line += 1
		}

		if is_eof(scanner) {
			add_error(scanner, .UNTERMINATED_BLOCK_COMMENT)
			return
		}

		advance(scanner)
	}

	lexeme := utf8string.slice(&scanner.source, scanner.start + 2, scanner.current - 2)
	lexeme = strings.trim_left(lexeme, " ")
	lexeme = strings.trim_right(lexeme, " ")

	token := Token {
		token_type = .COMMENT,
		lexeme     = lexeme,
		line       = scanner.line,
	}
	append(&scanner.tokens, token)
}

@(private = "file")
add_error :: proc(scanner: ^Scanner, error: ScannerError) {
	append(&scanner.errors, error)
}

@(private = "file")
is_eof :: proc(scanner: ^Scanner) -> bool {
	return scanner.current >= utf8string.len(&scanner.source)
}

@(private = "file")
advance :: proc(scanner: ^Scanner) -> rune {
	defer scanner.current += 1
	return peek(scanner)
}

@(private = "file")
peek :: proc(scanner: ^Scanner) -> rune {
	if is_eof(scanner) {
		return 0
	}
	return utf8string.at(&scanner.source, scanner.current)
}

@(private = "file")
peek_next :: proc(scanner: ^Scanner) -> rune {
	if scanner.current + 1 == utf8string.len(&scanner.source) {
		return 0
	}
	return utf8string.at(&scanner.source, scanner.current + 1)
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
