# pop — quickly cd to registered directories (and optionally open a file-manager window)
#
#   pop -a [name] [path]   register a directory (default: current dir, name = its basename)
#   pop -a -f name path    force overwrite an existing name
#   pop [name]             cd to the registered directory (bare `pop` lists entries)
#   pop -w name            cd and open a file-manager window there
#   pop -l                 list registered directories
#   pop -r name            remove a registration
#   pop -h                 show help
#
# Storage: $HOME/.config/pop/pop.json  (name -> absolute path, editable JSON)
# Override the store with POP_CONFIG=/path/to/file.json if you like.

pop() {
  local cfg="${POP_CONFIG:-$HOME/.config/pop/pop.json}"
  local action="" name="" path="" open_win=0 force=0
  local positional=()

  local _a
  for _a in "$@"; do
    case "$_a" in
      -a|--add)      action="add" ;;
      -r|--remove)   action="remove" ;;
      -l|--list)     action="list" ;;
      -w|--window)   open_win=1 ;;
      -f|--force)    force=1 ;;
      -h|--help)     action="help" ;;
      -*) printf 'pop: unknown option: %s\n' "$_a" >&2; return 1 ;;
      *) positional+=("$_a") ;;
    esac
  done

  if [[ -z "$action" ]]; then
    if (( ${#positional[@]} == 0 )); then action="list"
    else action="cd"; fi
  fi

  # --- storage helpers (jq) ---------------------------------------------------
  _pop_init() {
    if [[ ! -f "$cfg" ]] || ! jq -e . "$cfg" >/dev/null 2>&1; then
      mkdir -p "$(dirname "$cfg")"
      [[ -f "$cfg" ]] || printf '{}\n' > "$cfg"
    fi
  }
  _pop_get() { jq -r --arg n "$1" '.[$n] // empty' "$cfg"; }
  _pop_has() { jq -r --arg n "$1" 'has($n)' "$cfg"; }
  _pop_set() { # name path
    local tmp; tmp="$(mktemp)"
    jq --arg n "$1" --arg p "$2" '.[$n] = $p' "$cfg" > "$tmp" && mv "$tmp" "$cfg"
  }
  _pop_del() { # name
    local tmp; tmp="$(mktemp)"
    jq --arg n "$1" 'del(.[ $n ])' "$cfg" > "$tmp" && mv "$tmp" "$cfg"
  }
  # exact match first, else unique prefix/substring match
  _pop_resolve() { # name -> prints resolved path
    local n="$1" exact matches count
    exact="$(_pop_get "$n")"
    if [[ -n "$exact" ]]; then printf '%s' "$exact"; return 0; fi
    matches="$(jq -r --arg n "$n" \
      'to_entries[] | select((.key | startswith($n)) or (.key | contains($n))) | .key' "$cfg")"
    count="$(printf '%s' "$matches" | grep -c .)"
    if (( count == 1 )); then
      jq -r --arg n "$matches" '.[$n]' "$cfg"
      return 0
    fi
    if (( count > 1 )); then
      printf 'pop: ambiguous name %s (matches:' "$n" >&2
      while IFS= read -r m; do printf ' %s' "$m" >&2; done <<< "$matches"
      printf ')\n' >&2
    else
      printf 'pop: no entry matching %s\n' "$n" >&2
    fi
    return 1
  }
  _pop_open_window() { # dir
    local d="$1"
    if command -v thunar >/dev/null 2>&1; then
      ( thunar "$d" >/dev/null 2>&1 & )
    elif command -v nautilus >/dev/null 2>&1; then
      ( nautilus "$d" >/dev/null 2>&1 & )
    else
      ( xdg-open "$d" >/dev/null 2>&1 & )
    fi
  }

  case "$action" in
    help)
      cat <<'EOF'
pop — quickly cd to registered directories

usage:
  pop -a [name] [path]   register a directory (default: current dir, name = its basename)
  pop -a -f name path    force overwrite an existing name
  pop [name]             cd to the registered directory
  pop -w name            cd and open a file-manager window there
  pop -l                 list registered directories
  pop -r name            remove a registration
  pop -h                 show this help

name may be resolved by unique prefix, e.g. `pop my` -> `myProject`.
EOF
      ;;

    add)
      name="${positional[0]:-$(basename "$PWD")}"
      path="${positional[1]:-$PWD}"
      if [[ ! "$name" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]]; then
        printf 'pop: invalid name %s (use letters, digits, . _ -)\n' "$name" >&2
        return 1
      fi
      if [[ ! -d "$path" ]]; then
        printf 'pop: directory not found: %s\n' "$path" >&2
        return 1
      fi
      path="$(cd "$path" && pwd)"
      _pop_init
      local existing; existing="$(_pop_get "$name")"
      if [[ -n "$existing" && "$existing" != "$path" ]] && (( ! force )); then
        printf "pop: '%s' already registered as %s (use -f to overwrite)\n" "$name" "$existing" >&2
        return 1
      fi
      _pop_set "$name" "$path"
      if [[ -n "$existing" && "$existing" != "$path" ]]; then
        printf "updated '%s' -> %s\n" "$name" "$path"
      else
        printf "added '%s' -> %s\n" "$name" "$path"
      fi
      ;;

    remove)
      name="${positional[0]:-}"
      if [[ -z "$name" ]]; then printf 'pop: usage: pop -r name\n' >&2; return 1; fi
      _pop_init
      if [[ "$(_pop_has "$name")" == "true" ]]; then
        _pop_del "$name"
        printf "removed '%s'\n" "$name"
      else
        printf "pop: '%s' is not registered\n" "$name" >&2
        return 1
      fi
      ;;

    list)
      _pop_init
      local rows; rows="$(jq -r 'to_entries | sort_by(.key)[] | .key + "\t" + .value' "$cfg")"
      if [[ -z "$rows" ]]; then
        printf 'no registered directories (add one: pop -a [name])\n'
        return 0
      fi
      printf '%-20s %s\n' "name" "path"
      local n p
      while IFS=$'\t' read -r n p; do
        if [[ -d "$p" ]]; then
          printf '%-20s %s\n' "$n" "$p"
        else
          printf '%-20s %s   (missing)\n' "$n" "$p"
        fi
      done <<< "$rows"
      ;;

    cd)
      name="${positional[0]:-}"
      if [[ -z "$name" ]]; then printf 'pop: usage: pop [name]\n' >&2; return 1; fi
      _pop_init
      path="$(_pop_resolve "$name")" || return 1
      if [[ ! -d "$path" ]]; then
        printf 'pop: directory not found: %s\n' "$path" >&2
        return 1
      fi
      cd "$path" || return $?
      if (( open_win )); then
        _pop_open_window "$path"
        printf 'opened window: %s\n' "$path"
      fi
      ;;
  esac
}
