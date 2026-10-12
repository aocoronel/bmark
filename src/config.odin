package main

import "core:log"
import "core:os"
import "core:strconv"

get_env :: proc {
	get_string_env,
	get_int_env,
	get_double_env,
	get_bool_env,
}

get_string_env :: proc(name, default: string, allocator := context.allocator) -> string {
	env := os.get_env(name, allocator)
	if len(env) == 0 do return default
	return env
}

get_int_env :: proc(
	name: string,
	default: int,
	verbose := false,
	allocator := context.allocator,
) -> int {
	env := os.get_env(name, allocator)
	if len(env) == 0 {
		return default
	}
	value, ok := strconv.parse_int(env)
	if !ok && verbose {
		log.infof("%s: failed to parse integer: '%s', falling back to '%d'", name, env, default)
		return default
	}
	return value
}

get_double_env :: proc(
	name: string,
	default: f64,
	verbose := false,
	allocator := context.allocator,
) -> f64 {
	env := os.get_env(name, allocator)
	if len(env) == 0 {
		return default
	}
	value, ok := strconv.parse_f64(env)
	if !ok && verbose {
		log.infof("%s: failed to parse double: '%s', falling back to '%d'", name, env, default)
		return default
	}
	return value
}

get_bool_env :: proc(
	name: string,
	default: bool,
	verbose := false,
	allocator := context.allocator,
) -> bool {
	env := os.get_env(name, allocator)
	if len(env) == 0 {
		return default
	}
	value, ok := strconv.parse_bool(env)
	if !ok && verbose {
		log.infof("%s: failed to parse bool: '%s', falling back to '%d'", name, env, default)
		return default
	}
	return value
}
