#!/usr/bin/env bash
set -euo pipefail

if (( $# == 0 )) || [[ -z $1 ]]; then
  echo 'Usage: search.sh QUERY [max_results=5] [include_raw_content=1] [include_domains=example.com] [time_range=week] ...' >&2
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
curl --fail-with-body --silent --show-error --connect-timeout 5 --max-time 60 \
  --get "${base_url%/}/search" \
  --data-urlencode "q=$query" --data-urlencode 'format=json' \
  --data-urlencode "max_results=$limit" "${params[@]}" |
  jq '{query, results: [.results[] | {title, url, content} +
    (if .raw_content then {raw_content} else {} end)],
    unresponsive_engines: (.unresponsive_engines // [])}'
