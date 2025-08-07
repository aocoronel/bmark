#compdef bmark

BMARK_DB_DIR=${BMARK_DB_DIR:-$HOME/.local/share/bookmarks}
BMARK_FILE=${BMARK_FILE:-bookmark.db}

_bmark() {
  local -a subcommands edit_options

  subcommands=(
    "insert:Add a new bookmark"
    "delete:Remove a bookmark"
    "edit:Modify an existing bookmark"
    "import:Import bookmarks from a file"
    "export:Export bookmarks to a file"
    "list:List all bookmarks"
    "setup:Set up the bookmark database"
    "version:Display the version information"
  )

  _arguments -C \
    '1:command:->subcmds' \
    '--tag=[Filter by a specific tag]:tag:_bmark_get_tag' \
    '--note=[Search by a note]' \
    '--title=[Search by a title]' \
    '--url=[Search by a URL]' \
    '-s[Sort the output]' \
    '-r[Reverse the sort order]' \
    '-d=[Specify a different database file]:file:_bmark_get_db' \
    '-h[Display help message]' \
    '--help[Display help message]' \
    '*::args:->command_args'

  case $state in
  subcmds)
    _describe 'command' subcommands
    return
    ;;
  command_args)
    case $words[1] in
    insert | delete | list | setup | version)
      return
      ;;
    edit)
      _values 'edit fields' \
        'tag[Edit tag]:tag:_bmark_get_tag' \
        'title[Edit title]' \
        'note[Edit note]' \
        'url[Edit URL]' \
        'id[Edit ID]'
      ;;
    import | export)
      _arguments '1:filename:_files'
      ;;
    esac
    ;;
  esac
}

_bmark_get_tag() {
  local tags i dbfile
  for (( i=2; i<=$#words; i++ )); do
    case "${words[i]}" in
      -d)
        (( i++ ))
        dbfile="${words[i]}"
        ;;
      --database=*)
        dbfile="${words[i]#--database=}"
        ;;
    esac
  done
  [ -n "$dbfile" ] && BMARK_FILE="$dbfile.db"
  tags=(${(f)"$(sqlite3 "$BMARK_DB_DIR/$BMARK_FILE" "SELECT tag FROM tags LIMIT 100;" 2>/dev/null)"})
  compadd -Q -a tags
}

_bmark_get_db() {
  local files=()
  local db_dir="${BMARK_DB_DIR:-${HOME}/.local/share/bookmarks}"
  [[ -d "$db_dir" ]] || return 1
  for f in "$db_dir"/*(.N); do
    [[ -f "$f" ]] || continue
    files+=("${${f##*/}%.*}")
  done
  compadd -Q -a files
}

compdef _bmark bmark
