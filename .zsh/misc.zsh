bak() {
  local now f

  now=$(date +"%Y%m%d-%H%M%S")

  for f in "$@"; do
    if [[ ! -e "$f" ]]; then
      echo "file not found: $f" >&2
      continue
    fi

    cp -R "$f" "$f".$now.bak
  done
}

tailf() {
  local nl
  tail -f $2 | while read j; do
    print -n "$nl$j"
    nl="\n"
  done
}
