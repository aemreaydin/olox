package main

import "core:bufio"
import "core:fmt"
import "core:log"
import "core:mem"
import "core:os"
import "core:strings"

import "lox"

run :: proc(source: string) -> bool {
	scanner := lox.make_scanner(source)
	defer lox.destroy_scanner(&scanner)

	lox.scan_tokens(&scanner)

	if lox.has_error(&scanner) {
		for err in scanner.errors {
			fmt.eprintf("Error: %s\n", err)
		}
		return false
	}

	for token in scanner.tokens {
		fmt.printf("%v\n", token)
	}
	return true
}

runFile :: proc(file_path: string) {
	bytes, success := os.read_entire_file_from_filename(file_path)
	defer delete(bytes)
	if !success {
		fmt.eprintln("Could not read file:", file_path)
		return
	}
	source, err := strings.clone_from_bytes(bytes)
	if err != nil {
		return
	}
	defer delete(source)

	if !run(source) {
		os.exit(65)
	}
}

runPrompt :: proc() {
	r: bufio.Reader
	buffer := make([dynamic]byte, 2048)
	defer delete(buffer)
	bufio.reader_init_with_buf(&r, os.stream_from_handle(os.stdin), buffer[:])
	defer bufio.reader_destroy(&r)

	for {
		fmt.print("> ")
		line, err := bufio.reader_read_string(&r, '\n')
		defer delete(line)
		if err != nil {
			break
		}

		line = strings.trim_right(line, "\r\n")
		run(line)
	}
}

main :: proc() {
	logger := log.create_console_logger()
	context.logger = logger
	defer log.destroy_console_logger(logger)

	when ODIN_DEBUG {
		track: mem.Tracking_Allocator
		mem.tracking_allocator_init(&track, context.allocator)
		context.allocator = mem.tracking_allocator(&track)

		defer {
			if len(track.allocation_map) > 0 {
				fmt.eprintf("=== %v allocations not freed: ===\n", len(track.allocation_map))
				for _, entry in track.allocation_map {
					fmt.eprintf("- %v bytes @ %v\n", entry.size, entry.location)
				}
			}
			mem.tracking_allocator_destroy(&track)
		}
	}

	switch args := os.args; len(args) {
	case 2:
		runFile(args[1])
	case 1:
		runPrompt()
	case:
		fmt.println("[Usage]: olox [script_file]")
	}
}
