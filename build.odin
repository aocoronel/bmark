package build

import "core:flags"
import "core:log"
import "core:os"
import "shared:odd/pipe"

Pipe :: pipe.Pipe
sh :: pipe.run_command

Option :: struct {
	mode:  string `args:"pos=0,required" usage:"debug,release"`,
	force: bool `usage:"Force rebuild"`,
	local: bool `usage:"Use local dependencies"`,
}

ln :: proc(src, dst: string) -> (err: os.Error) {
	absolute_src := os.get_absolute_path(src, context.temp_allocator) or_return

	os.make_directory_all(os.dir(dst))
	err = os.symlink(absolute_src, dst)
	if err != nil do return

	return
}

get_deps :: proc(opt: ^Option) {
	if !opt.local do return
	if !os.exists("./shared/odd-git") {
		sh(
			{
				"git",
				"clone",
				"--depth",
				"1",
				"https://github.com/aocoronel/odd",
				"./shared/odd-git",
			},
		)
	}
	if !os.exists("./shared/odd") {
		err := ln("./shared/odd-git/odd/", "./shared/odd")
		if err != nil {
			log.error(os.error_string(err))
		}
	}
	if !os.exists("./shared/odin-sqlite3-git") {
		sh(
			{
				"git",
				"clone",
				"--depth",
				"1",
				"https://github.com/aocoronel/odin-sqlite3",
				"./shared/odin-sqlite3-git",
			},
		)

	}
	if !os.exists("./shared/odin-sqlite3") {
		err := ln("./shared/odin-sqlite3-git/bindings/", "./shared/odin-sqlite3")
		if err != nil {
			log.error(os.error_string(err))
		}
	}
}

main :: proc() {
	context.logger = log.create_console_logger()
	defer log.destroy_console_logger(context.logger)

	opt: Option
	flags.parse_or_exit(&opt, os.args)

	os.make_directory("bin")

	if opt.force || !os.exists("./bin/generator") {
		sh({"env", "odin", "build", "./tools/generator.odin", "-out:bin/generator", "-file"})
	}
	sh({"./bin/generator", "./src/", "./src/doc.cmd"})

	get_deps(&opt)

	source_code :: "./src"
	deps := "-collection:shared=shared/" if opt.local else ""
	if opt.mode == "debug" {
		sh(
			{
				"env",
				"odin",
				"build",
				source_code,
				"-debug",
				deps,
				"-show-timings",
				"-custom-attribute:command",
				"-out:bin/bmark",
			},
		)
	} else if opt.mode == "release" {
		sh(
			{
				"env",
				"odin",
				"build",
				source_code,
				deps,
				"-o:speed",
				"-show-timings",
				"-custom-attribute:command",
				"-out:bin/bmark",
			},
		)
	} else {
		log.errorf("Invalid mode: %q", opt.mode)
	}
}
