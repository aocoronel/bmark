package walker

/*
This is WIP.

The goal of this program is to read a custom attribute named "command",
and gather it's information, including comments.

The idea is to provide an easy to use algorithm that gives you a single
string containing all the metadata, easily greppable, which can be used
in help search based commands.

I don't know if I leave it as a simple program, or convert it to a small
lib.
*/

import "core:flags"
import "core:fmt"
import "core:log"
import "core:odin/ast"
import parse "core:odin/parser"
import "core:os"
import "core:strings"

written_bytes: int
output: ^os.File

main :: proc() {
	log.Level_Headers = {
		0 ..< 10 = "debug: ",
		10 ..< 20 = "info: ",
		20 ..< 30 = "warn: ",
		30 ..< 40 = "error: ",
		40 ..< 50 = "fatal: ",
	}

	context.logger = log.create_console_logger(
		opt = {.Level, .Terminal_Color, .Short_File_Path, .Line},
	)
	defer log.destroy_console_logger(context.logger)

	Option :: struct {
		pkg: string `args:"pos=0,required" usage:"Package to inspect"`,
		out: string `args:"pos=1,required" usage:"Output file"`,
	}

	opt: Option
	flags.parse_or_exit(&opt, os.args)

	pkg, ok := parse.parse_package_from_path(opt.pkg)

	err: os.Error
	output, err = os.open(opt.out, {.Write, .Create, .Trunc}, os.Permissions_Default_File)
	if !os_err(err) do return
	defer os.close(output)

	files := pkg.files
	for filename, &file in files {
		walk_ast(file)
	}
}

os_err :: proc(err: os.Error) -> bool {
	if err != nil {
		log.error(os.error_string(err))
		return false
	}
	return true
}

walk_ast :: proc(file: ^ast.File) {
	visitor := ast.Visitor {
		visit = proc(v: ^ast.Visitor, node: ^ast.Node) -> ^ast.Visitor {
			ok := process_node(node)
			if !ok {
				return nil
			}
			return v
		},
	}
	ast.walk(&visitor, file)
}

process_node :: proc(node: ^ast.Node) -> (ok: bool) {
	ok = true
	if node == nil do return
	#partial switch derived in node.derived {
	case ^ast.Value_Decl:
		if !has_attribute(derived.attributes, "command") {
			return
		}

		assert(len(derived.names) == 1)
		value_name, is_ident := derived.names[0].derived.(^ast.Ident)
		if !is_ident {
			return
		}
		name := value_name.name
		if name[0] == '_' do name = name[1:]

		err: os.Error
		if derived.docs != nil {
			assert(len(derived.docs.list) == 1)
			comment := derived.docs.list[0].text

			comment = strings.trim(comment, "/*\n")

			off_begin := written_bytes + len(name) + 3

			off_end := off_begin + len(comment)

			off_begin_size := integer_length(off_begin)
			off_end_size := integer_length(off_end)

			ensure := off_begin + off_begin_size + off_end_size
			ensure_size := integer_length(ensure)

			if ensure_size != off_begin_size {
				off_begin_size = ensure_size
			}

			_off_begin := off_begin + off_begin_size
			ensure = _off_begin + len(comment)
			ensure_size = integer_length(ensure)
			if ensure_size != off_end_size {
				off_begin = off_begin + off_begin_size + ensure_size
			} else {
				off_begin = off_begin + off_begin_size + off_end_size
			}
			off_end = off_begin + len(comment)

			n: int
			n, err = os.write_string(
				output,
				fmt.tprintf("%s:%d:%d\n%s\n", name, off_begin, off_end, comment),
			)
			written_bytes += n
			os_err(err) or_return
		} else {
			n: int
			n, err = os.write_string(output, fmt.tprintf("%s\n", name))
			written_bytes += n
			os_err(err) or_return
		}
	}
	return
}

integer_length :: proc(n: int) -> (len: int) {
	len += 1
	n := n / 10

	for n != 0 {
		len += 1
		n = n / 10
	}

	return len
}

has_attribute :: proc(attributes: [dynamic]^ast.Attribute, name: string) -> bool {
	for attribute in attributes {
		for elem in attribute.elems {
			ident, is_ident := elem.derived.(^ast.Ident)
			if is_ident && ident.name == name {
				return true
			}
		}
	}
	return false
}
