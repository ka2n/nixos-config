#!/usr/bin/env bash
set -euo pipefail

curl=@curl@
jq=@jq@

usage() {
  cat <<'EOF'
Usage: web-search QUERY [PARAMETER=VALUE ...]
       web-search --help

Search the public web through RustXNG and return JSON.

Options:
  -h, --help                Show this help and exit

Parameters:
  max_results=5             Number of results (1-200; default: 5)
  include_raw_content=1     Include text from the top pages
  include_domains=DOMAIN   Only these domains (comma-separated)
  exclude_domains=DOMAIN   Exclude these domains (comma-separated)
  time_range=week          Date filter: day, week, month, or year
  language=ja              Search language
  categories=general       Search category, e.g. general, news, or science
  pageno=1                 Result page number

Environment:
  RUSTXNG_URL               Base URL (default: http://127.0.0.1:8888)

Examples:
  web-search 'NixOS Home Manager'
  web-search 'tokio runtime' include_domains=tokio.rs include_raw_content=1
  web-search 'Rust release' time_range=week max_results=3
EOF
}

if [[ ${1:-} == --help || ${1:-} == -h ]]; then
  usage
  exit 0
fi

if (( $# == 0 )) || [[ -z $1 ]]; then
  usage >&2
  exit 2
fi

query=$1
shift
limit=5
params=()
for param in "$@"; do
  case "$param" in
    max_results=*)
      limit=${param#*=}
      ;;
    include_raw_content=*|include_domains=*|exclude_domains=*|time_range=*|language=*|categories=*|pageno=*)
      params+=(--data-urlencode "$param")
      ;;
    *)
      echo "Unsupported parameter: $param" >&2
      exit 2
      ;;
  esac
done

if [[ ! $limit =~ ^[0-9]{1,3}$ ]] || (( 10#$limit < 1 || 10#$limit > 200 )); then
  echo 'max_results must be an integer from 1 to 200' >&2
  exit 2
fi

base_url=${RUSTXNG_URL:-http://127.0.0.1:8888}
"$curl" --fail-with-body --silent --show-error --connect-timeout 5 --max-time 60 \
  --get "${base_url%/}/search" \
  --data-urlencode "q=$query" --data-urlencode 'format=json' \
  --data-urlencode "max_results=$limit" "${params[@]}" |
  "$jq" '{query, results: [.results[] | {title, url, content} +
    (if .raw_content then {raw_content} else {} end)],
    unresponsive_engines: (.unresponsive_engines // [])}'
