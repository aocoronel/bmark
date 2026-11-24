package main

/*
Extra abstractions for the SQLite bindings
*/

import rt "base:runtime"
import "core:fmt"
import "core:log"
import sqlite "shared:sqlite3"

print_row :: proc(rows: []sqlite.SQLite_Types, ctx: rawptr) {
	for row in rows {
		fmt.printf("%v%c", row, SEPARATOR)
	}
	fmt.print("\n")
}

sql_error :: #force_inline proc(
	db: ^sqlite.SQLite3,
	status: sqlite.Result_Code,
	loc := #caller_location,
) {
	when ODIN_DEBUG {
		log.errorf("status %d: %s", status, sqlite.errmsg(db), location = loc)
	} else {
		log.errorf("%s", sqlite.errmsg(db), location = loc)
	}
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
		fmt.print(sqlite.shell_error_context(db, sql))
		return false
	}
	status = sqlite.exec(stmt)
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
	stmt, rc := sqlite.prepare(db, query, arg)
	if rc != nil {
		sql_error(db, rc, loc)
		return
	}
	rows: []sqlite.SQLite_Types
	defer rt.delete(rows)
	for {
		rc = sqlite.step(stmt)
		if rc != .Row {
			if rc == .Done do break
			sql_error(db, rc, loc = loc)
			return
		}
		rows = sqlite.exec_dynamic(stmt)
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
	stmt, rc := sqlite.prepare(db, sql, ..args)
	if rc != nil {
		sql_error(db, rc, loc)
		fmt.print(sqlite.shell_error_context(db, sql))
		return false
	}
	rows: []sqlite.SQLite_Types
	defer rt.delete(rows)
	for {
		rc = sqlite.step(stmt)
		if rc != .Row do break
		rows = sqlite.exec_dynamic(stmt)
		loop_handler(rows, ctx)
		rt.delete(rows)
	}
	rc = sqlite.finalize(stmt)
	if rc != nil {
		sql_error(db, rc, loc = loc)
		return false
	}
	return true
}
