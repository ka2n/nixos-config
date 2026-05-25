# Resolve a GitHub-ish reference matched by foot's regex into a URL and open it
# via x-open-url. The regex captures one of:
#   <host>/<org>/<repo>[#<num>]   e.g. github.com/foo/bar, github.com/foo/bar#42
#   <org>/<repo>#<num>            e.g. org/repo#123
#   <repo>#<num>                  e.g. mscfb#1   (host/org inferred from git origin)
#   #<num>                        e.g. #123     (host/org/repo inferred from git origin)
# The match may start with a single boundary character (whitespace or
# punctuation) — strip it before parsing.

ref="$1"

case "$ref" in
  [A-Za-z0-9#]*) ;;
  ?*) ref=${ref#?} ;;
esac

# Resolve <host>/<org>/<repo> from the current git repository's `origin` remote.
# Only the inference cases (#num and repo#num) call this. Sets host/org/repo
# and returns 0 on success, non-zero if not in a git repo or no origin.
infer_from_origin() {
  local origin path
  origin=$(@git@ -C "$PWD" remote get-url origin 2>/dev/null) || return 1
  case "$origin" in
    git@*:*)
      host=${origin#git@}; host=${host%%:*}
      path=${origin#*:}
      ;;
    *://*)
      path=${origin#*://}; path=${path#*@}
      host=${path%%/*}; host=${host%%:*}
      path=${path#*/}
      ;;
    *)
      return 1
      ;;
  esac
  path=${path%.git}
  org=${path%%/*}
  repo=${path#*/}; repo=${repo%%/*}
  [ -n "$host" ] && [ -n "$org" ] && [ -n "$repo" ]
}

url=""
case "$ref" in
  http://*|https://*)
    url=$ref
    ;;
  '#'[0-9]*)
    num=${ref#\#}
    if infer_from_origin; then
      url="https://$host/$org/$repo/issues/$num"
    fi
    ;;
  */*/*#*)
    url="https://${ref%#*}/issues/${ref##*#}"
    ;;
  */*/*)
    url="https://$ref"
    ;;
  */*#*)
    url="https://github.com/${ref%#*}/issues/${ref##*#}"
    ;;
  *#*)
    r=${ref%#*}
    num=${ref##*#}
    if infer_from_origin; then
      url="https://$host/$org/$r/issues/$num"
    fi
    ;;
esac

[ -n "$url" ] || exit 1
exec @x_open_url@ "$url"
