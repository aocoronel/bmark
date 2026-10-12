package main

import "core:fmt"
import "core:unicode"

Diff_Op :: enum {
	Delete,
	Append,
	Replace,
}

Diff :: struct {
	old: [2]int,
	new: [2]int,
	op:  Diff_Op,
}

Scanner :: struct {
	pos:  int,
	buff: string,
}

Token :: struct {
	text: string,
	kind: Token_Kind,
}

Token_Kind :: enum {
	Ident,
	Integer,
	Comma,
	EOF,
}

scan :: proc(s: ^Scanner) -> Token {
	if s.pos >= len(s.buff) do return {kind = .EOF}
	c := cast(rune)s.buff[s.pos]
	if unicode.is_letter(c) {
		s.pos += 1
		return {text = s.buff[s.pos - 1:s.pos], kind = .Ident}
	}
	if c == ',' {
		s.pos += 1
		return {text = ",", kind = .Comma}
	}
	if unicode.is_digit(c) {
		size: int
		for i in s.pos ..< len(s.buff) {
			c := cast(rune)s.buff[i]
			if !unicode.is_digit(c) {
				break
			}
			size += 1
		}
		s.pos += size
		return {text = s.buff[s.pos - size:s.pos], kind = .Integer}
	}
	fmt.panicf("illegal rune: %c", c)
}

diffparse :: proc(t: ^Scanner) -> (diff: Diff, ok: bool) {
	diff.old = {-1, -1}
	diff.new = {-1, -1}

	token := scan(t)
	if token.kind == .EOF do return
	assert(token.kind == .Integer)
	diff.old[0], _ = parse_int(token.text)

	get_op :: proc(c: u8) -> Diff_Op {
		switch c {
		case 'a':
			return .Append
		case 'd':
			return .Delete
		case 'c':
			return .Replace
		case:
			fmt.panicf("illegal rune from diff: %c", c)
		}
	}

	token = scan(t)
	#partial switch token.kind {
	case .Ident:
		diff.op = get_op(token.text[0])
	case .Comma:
		token = scan(t)
		assert(token.kind == .Integer)
		diff.old[1], _ = parse_int(token.text)
		token = scan(t)
		assert(token.kind == .Ident)
		diff.op = get_op(token.text[0])
		break
	}

	token = scan(t)
	assert(token.kind == .Integer)
	diff.new[0], _ = parse_int(token.text)

	token = scan(t)
	#partial switch token.kind {
	case .EOF:
		break
	case .Comma:
		token = scan(t)
		assert(token.kind == .Integer)
		diff.new[1], _ = parse_int(token.text)
	}
	return diff, true
}
