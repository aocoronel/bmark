package build

/// BEGIN build.odin

/*
Lightweight mini library for Odin build system.
*/

import "base:runtime"
import "core:fmt"
import "core:log"
import "core:os"

Option :: struct {
	name: string,
	var:  any,
}

tprintf :: fmt.tprintf
SHARED :: "./shared"

/*
Check os.error and log error
*/
_os_error :: proc(err: os.Error, loc := #caller_location) -> bool {
	if err != nil {
		log.error(os.error_string(err), location = loc)
		return false
	}
	return true
}

/*
Executes a command
*/
sh :: proc(commands: []string, working_dir := "") -> bool {
	fmt.print("| ")
	for cmd in commands {
		fmt.print(cmd)
		fmt.print(' ')
	}
	fmt.print('\n')
	process, perr := os.process_start(
		{
			stderr = os.stderr,
			stdout = os.stdout,
			stdin = os.stdin,
			command = commands,
			working_dir = working_dir,
		},
	)
	_os_error(perr) or_return
	state, werr := os.process_wait(process)
	_os_error(werr) or_return
	return state.exit_code == 0
}

/*
Symlink
*/
ln :: proc(src, dst: string) -> (err: os.Error) {
	absolute_src := os.get_absolute_path(src, context.temp_allocator) or_return
	os.make_directory_all(os.dir(dst))
	return os.symlink(absolute_src, dst)
}

/*
Clone a git repository
*/
clone :: proc(repo: string) -> bool {
	return sh({"git", "clone", "--depth", "1", repo, tprintf("%s/%s-git", SHARED, os.base(repo))})
}

/*
Pull a git repository
*/
pull :: proc(repo: string) -> bool {
	return sh({"git", "-C", tprintf("%s/%s-git", SHARED, os.base(repo)), "pull", "--depth", "1"})
}

/*
Pull a git repository
*/
odin :: proc(cmd, path: string, args: ..[]string) -> bool {
	cmds := make([dynamic]string, allocator = context.temp_allocator)
	append(&cmds, "odin", cmd, path)
	for flags in args {
		idx := len(cmds)
		resize(&cmds, len(cmds) + len(flags))
		copy(cmds[idx:], flags)
	}
	return sh(cmds[:])
}

/*
Lightweight RTTI flag parser
*/
parse_flags :: proc(opts: []Option, help: string) {
	is_opt :: proc(arg: string) -> bool {return !(arg[0] == '-')}
	i: int

	for arg in os.args {
		if len(arg) < 2 do continue
		switch arg[1:] {
		case "h", "help":
			fmt.println(help)
			os.exit(0)
		}
	}

	for ; i < len(os.args); i += 1 {
		arg := os.args[i]

		for &opt in opts {
			if len(arg) < 2 do continue
			if arg[1:] != opt.name do continue

			switch v in opt.var {
			case ^bool:
				v^ = !v^
			case ^string:
				if i + 1 >= len(os.args) do return
				value := os.args[i + 1]
				is_opt(value) or_continue
				v^ = value
			}
			break
		}
	}
	return
}
/// END build.odin

HELP :: `Usage: (debug,release) [-force] [-local]
Options:
	-force     | Force rebuild
	-local     | Use local dependencies`

main :: proc() {
	context.logger = log.create_console_logger(
		opt = {.Level, .Terminal_Color, .Short_File_Path, .Line},
	)
	defer log.destroy_console_logger(context.logger)

	mode: string
	force, local: bool
	parse_flags({{"mode", &mode}, {"local", &local}, {"force", &force}}, HELP)

	if mode == "" {
		log.errorf("mode isn't set. Valid values: debug, release")
		return
	}

	os.make_directory("bin")

	if force || !os.exists("./bin/generator") {
		odin("build", "./tools/generator.odin", {"-out:bin/generator", "-file"})
	}
	sh({"./bin/generator", "./src/", "./src/doc.cmd"})

	if local {
		if !os.exists("./shared/odd-git") {
			clone("https://github.com/aocoronel/odd")
		}
		if !os.exists("./shared/odd") {
			err := ln("./shared/odd-git/odd/", "./shared/odd")
			if err != nil {
				log.error(os.error_string(err))
			}
		}
		if !os.exists("./shared/odin-sqlite3-git") {
			clone("https://github.com/aocoronel/odin-sqlite3")
		}
		if !os.exists("./shared/odin-sqlite3") {
			err := ln("./shared/odin-sqlite3-git/sqlite3/", "./shared/sqlite3")
			if err != nil {
				log.error(os.error_string(err))
			}
		}
	}

	source_code :: "./src"
	deps := "-collection:shared=shared/" if local else ""

	ODIN_FLAGS :: []string{"-show-timings", "-custom-attribute:command", "-out:bin/bmark"}

	switch mode {
	case "debug":
		odin("build", source_code, ODIN_FLAGS, {deps, "-debug"})
	case "release":
		odin("build", source_code, ODIN_FLAGS, {deps, "-o:speed"})
	case:
		log.errorf("Invalid mode: %q", mode)
	}
}
