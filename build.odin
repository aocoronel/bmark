package build

import "core:log"
import "core:os"
import "shared:odd/pipe"

main :: proc() {
	Pipe :: pipe.Pipe
	sh :: pipe.run_command

	context.logger = log.create_console_logger()
	defer log.destroy_console_logger(context.logger)

	os.make_directory("bin")

	if !os.exists("./bin/generator") {
		sh({"env", "odin", "build", "./tools/generator.odin", "-out:bin/generator", "-file"})
	}
	sh({"./bin/generator", "./src/", "./src/doc.cmd"})
	sh({"env", "odin", "build", "./src/", "-custom-attribute:command", "-out:bin/bmark"})
}
