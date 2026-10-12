# Minimalistic bookmark manager

A simple bookmark manager that aims to be simple, while not keeping in your way in the long-term.

`bmark` is inspired by similar tools like [buku](https://github.com/jarun/buku) and [bmm](https://github.com/dhth/bmm). It also uses SQLite as the backend.

This tool was created, because I feel both `buku` and `bmm` offer unnecessary features. So I made `bmark` with the bare minimum features you would expect a bookmark manager to have.

## Features

- Insert, edit, rename and delete bookmarks
- Import from or export to HTML format (compatible with Firefox and Chrome)
- Highly customizable printing
- Execute arbitrary SQLite code
- Searchable help

## Requirements

- [odd](https://github.com/aocoronel/odd)
- [odin-sqlite3](https://github.com/aocoronel/odin-sqlite3)

## Compiling from source

```bash
git clone --depth 1 https://github.com/aocoronel/bmark
odin run . -- release -local
```

## Usage

```
Usage:
	bmark [cmd] [url] [tag] [title] [note] [-append] [-dry] [-file] [-force] [-id] [-print] [-separator] [-verbose]
Flags:
	-cmd:<string>
		Command to run
		Accepts:
		list,tag,edit,insert,delete,export,
		import,bulk,version,search,help,sql
	-url:<string>      | Bookmark URL
	-tag:<string>      | Tag, comma separated
	-title:<string>    | Bookmark title
	-note:<string>     | Bookmark note
	                   |
	-append:<string>   | Append extra SQLite query
	-dry               | Dry mode
	-file:<string>
		Pass alternative database
		You can also set the BMARK_FILE environment variable
	-force             | Force operation. See insert command
	-id:<string>       | Database ID
	-print:<string>
		Fields to print, comma separated
		Accepts: id,url,tag,title,note
		This affects the print order as well
	-separator:<rune>  | Separator while printing. Defaults to ' '
	-verbose           | Enable verbosity
```

### Scripting

Pipe URLs to fzf and open in the browser

```bash
bmark -print:"url" list | fzf -m | xargs -I {} xdg-open "{}"
```

## Notes

This script has been tested exclusively on a Linux machine.

## License

This repository is licensed under the MIT License, allowing for extensive use, modification, copying, and distribution.
