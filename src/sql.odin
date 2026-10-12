package main

/*
Extra abstractions for the SQLite bindings
*/

import odin "base:runtime"
import "core:fmt"
import "core:log"
import sqlite "shared:odin-sqlite3"

print_row :: proc(rows: [dynamic]sqlite.SQLite_Types, ctx: rawptr) {
	for row in rows {
		fmt.printf("%v%c", row, SEPARATOR)
	}
	fmt.print("\n")
}

sql_error :: #force_inline proc(
	db: ^sqlite.SQLite3,
	status: sqlite.Status,
	loc := #caller_location,
) {
	log.errorf("status %d: %s", status, sqlite.errmsg(db), location = loc)
}

begin_transaction :: #force_inline proc(db: ^sqlite.SQLite3) -> bool {
	execute(db, "BEGIN TRANSACTION;") or_return
	return true
}

rollback :: #force_inline proc(db: ^sqlite.SQLite3) -> bool {
	execute(db, "ROLLBACK;") or_return
	return true
}

commit :: #force_inline proc(db: ^sqlite.SQLite3) -> bool {
	execute(db, "COMMIT;") or_return
	return true
}

execute :: proc(db: ^sqlite.SQLite3, sql: string, args: ..any, loc := #caller_location) -> bool {
	stmt, status := sqlite.prepare(db, sql, ..args, loc = loc)
	if status != nil {
		sql_error(db, status, loc)
		return false
	}
	status = sqlite.execute(stmt)
	if status != .Done {
		sql_error(db, status, loc)
		return false
	}
	return true
}

get_id :: proc(
	db: ^sqlite.SQLite3,
	id_string, table, input_string: string,
	arg: any,
	loc := #caller_location,
) -> (
	id: int,
	ok: bool,
) {
	id = -1
	query := fmt.tprintf("SELECT %s FROM %s WHERE %s = ? LIMIT 1", id_string, table, input_string)
	stmt, status := sqlite.prepare(db, query, arg)
	if status != nil {
		log.error(sqlite.errmsg(db))
		return
	}
	rows: [dynamic]sqlite.SQLite_Types
	defer odin.delete(rows)
	for {
		rows, status = sqlite.execute(db, stmt, rows)
		if status != nil {
			if status == .Done do break
			sql_error(db, status, loc = loc)
			return
		}
		if id == -1 {
			id = cast(int)rows[0].(i64)
		}
	}
	ok = true
	return
}

execute_row :: proc(
	db: ^sqlite.SQLite3,
	sql: string,
	args: ..any,
	loop_handler := print_row,
	ctx: rawptr = nil,
	loc := #caller_location,
) -> bool {
	stmt, status := sqlite.prepare(db, sql, ..args)
	if status != nil {
		log.error(sqlite.errmsg(db))
		return false
	}
	rows: [dynamic]sqlite.SQLite_Types
	defer odin.delete(rows)
	for {
		rows, status = sqlite.execute(db, stmt, rows)
		if status != nil {
			if status == .Done do break
			sql_error(db, status, loc = loc)
			return false
		}
		loop_handler(rows, ctx)
	}
	return true
}
