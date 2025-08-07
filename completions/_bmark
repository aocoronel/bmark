#!/usr/bin/bash

BMARK_DB_DIR=${BMARK_DB_DIR:-"$HOME/.local/share/bookmarks"}
BMARK_FILE=${BMARK_FILE:-bookmark.db}

_bmark() {
  local cur prev
  COMPREPLY=()
  cur="${COMP_WORDS[COMP_CWORD]}"
  prev="${COMP_WORDS[COMP_CWORD - 1]}"

  case "${cur}" in
  -)
    mapfile -t COMPREPLY < <(compgen -W "--tag --note --title --url -s -r -d -h" -- "${cur}")
    return 0
    ;;
  esac

  for ((i = 0; i < ${#COMP_WORDS[@]}; i++)); do
    if [[ "${COMP_WORDS[i]}" == "-d" ]] && ((i + 1 < ${#COMP_WORDS[@]})); then
      BMARK_FILE="${COMP_WORDS[i + 1]}"
      break
    fi
  done

  case "${prev}" in
  edit)
    mapfile -t COMPREPLY < <(compgen -W "tag= id= title= note= url=" -- "${cur}")
    return 0
    ;;
  export | import)
    mapfile -t COMPREPLY < <(compgen -f -- "${cur}")
    return 0
    ;;
  -d)
    local files=()
    for f in "${BMARK_DB_DIR}"/*; do
      files+=("$(basename "${f%.*}")")
    done

    mapfile -t COMPREPLY < <(compgen -W "${files[*]}" -- "${cur}")
    return 0
    ;;
  --tag)
    local tags
    tags=$(sqlite3 "$BMARK_DB_DIR/$BMARK_FILE" "select tag from tags;" | tr '\n' ' ')
    mapfile -t COMPREPLY < <(compgen -W "${tags}" -- "${cur}")
    return 0
    ;;
  esac

  mapfile -t COMPREPLY < <(compgen -W "insert delete edit import export list setup version" -- "${cur}")
}

complete -F _bmark bmark
