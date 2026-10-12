package build

import "core:flags"
import "core:log"
import "core:os"
import "shared:odd/pipe"

main :: proc() {
	Pipe :: pipe.Pipe
	sh :: pipe.run_command

	context.logger = log.create_console_logger()
	defer log.destroy_console_logger(context.logger)

	Option :: struct {
		mode:  string `args:"pos=0,required" usage:"debug,release"`,
		force: bool `usage:"Force rebuild"`,
	}
	opt: Option
	flags.parse_or_exit(&opt, os.args)

	os.make_directory("bin")

	if opt.force || !os.exists("./bin/generator") {
		sh({"env", "odin", "build", "./tools/generator.odin", "-out:bin/generator", "-file"})
	}
	sh({"./bin/generator", "./src/", "./src/doc.cmd"})

	if opt.mode == "debug" {
		sh(
			{
				"env",
				"odin",
				"build",
				"./src/",
				"-debug",
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
				"./src/",
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
