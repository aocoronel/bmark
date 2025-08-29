# bmark: A simple bookmark manager

A simple bookmark manager that aims to be simple, while not keeping in your way in the long-term.

`bmark` is inspired by similar tools like [buku](https://github.com/jarun/buku) and [bmm](https://github.com/dhth/bmm). It also uses SQLite as the backend.

This tool was created, because I feel both `buku` and `bmm` offer unnecessary features. So I made `bmark` with the bare minimum features you would expect a bookmark manager to have.

## Features

- Add bookmarks
  - Include title, tag and notes
- Delete bookmarks or tags
- Edit bookmarks or tags
- Import from or export to HTML format (compatible with Firefox bookmarks)
- List bookmarks with queries
- List only URL

This tool follows the UNIX philosophy. Extra functionalities like opening in the browser or piping to `fzf` and `rofi` may be done by the user.

## Requirements

- `sqlite3`

## Installation

```bash
git clone https://github.com/aocoronel/bmark
chmod +x bmark/src/bmark bmark/src/bmark-bulk.py
mv bmark/src/bmark ~/.local/bin/bmarkk
mv bmark/src/bmark-bulk.py ~/.local/bin/bmark-bulk.py
```

## Usage

```
A simple bookmark manager

Usage:
  bmark FLAG <FLAG_INPUT> COMMAND INPUT
  bmark -h | bmark help

Commands:
  bulk                                  Edit the database using an EDITOR
  delete ID, URL or TAG                 Delete a bookmark or tag
  edit FIELD=VALUE URL TAG TITLE NOTES  Edit a bookmark
  export                                Export bookmarks to HTML file
  import FILE                           Import bookmarks from HTML file
  insert URL TAG TITLE NOTES            Insert a new bookmark
  list URL TAG TITLE NOTES              List all bookmarks
  setup                                 Manually create a new database
  version                               Display current version

Flags:
  --note <NOTE>        Query for NOTE
  --tag <TAG>          Query for TAG
  --title <TITLE>      Query for TITLE
  --url <URL>          Query for URL
  -d DATABASE          Use an alternative database
  -h, --help           Displays this message and exits
  -r                   List only the URL
  -s                   List will strictly match given query

Examples:
  bmark insert URL TAG TITLE NOTES
  bmark --tag "TAG" --note "NOTE" list URL TITLE
```

### Scripting

Pipe URLs to fzf and open in the browser

```bash
bmark -r list | fzf -m | xargs -I {} xdg-open "{}"
```

## Notes

This script has been tested exclusively on a Linux machine.

## License

This repository is licensed under the MIT License, allowing for extensive use, modification, copying, and distribution.
