#!/bin/sh
set -eu

PROG="ralph"

usage() {
  cat <<EOF
Usage: $PROG <backend> "<PROMPT>" [OPTIONS]

Run an AI agent in a loop until it signals completion.

Backends:
  claude    Use Claude Code (claude --dangerously-skip-permissions -p)

Options:
  --max-iterations N   Maximum loop iterations (default: 10)

Example:
  $PROG claude "Fix all failing tests" --max-iterations 5

The agent prompt is augmented with instructions to:
  - Read progress.md first
  - Append learnings to progress.md
  - Output <promise>COMPLETE</promise> when done
EOF
  exit 1
}

if [ $# -lt 2 ]; then
  usage
fi

BACKEND="$1"
shift
PROMPT="$1"
shift

MAX_ITERATIONS=10

while [ $# -gt 0 ]; do
  case "$1" in
    --max-iterations)
      shift
      MAX_ITERATIONS="$1"
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage
      ;;
  esac
  shift
done

COMPLETION_PROMISE="COMPLETE"
PROGRESS_FILE="progress.md"

build_prompt() {
  cat <<EOF
$PROMPT

## Instructions

- Read $PROGRESS_FILE first if it exists
- Append learnings and progress to $PROGRESS_FILE after each significant step
- Stop condition: when ALL requirements are satisfied, reply with EXACTLY: <promise>$COMPLETION_PROMISE</promise>
- Do NOT output the promise tag until you are confident everything is done
EOF
}

run_claude() {
  prompt="$1"
  claude --dangerously-skip-permissions -p "$prompt" 2>&1
}

case "$BACKEND" in
  claude)
    run_agent() { run_claude "$1"; }
    ;;
  *)
    echo "Unknown backend: $BACKEND" >&2
    echo "Supported backends: claude" >&2
    exit 1
    ;;
esac

echo "Ralph: backend=$BACKEND max_iterations=$MAX_ITERATIONS"
echo "Ralph: prompt=$(echo "$PROMPT" | head -1)"
echo "---"

FULL_PROMPT="$(build_prompt)"

for i in $(seq 1 "$MAX_ITERATIONS"); do
  echo "=== Iteration $i/$MAX_ITERATIONS ==="

  OUTPUT="$(run_agent "$FULL_PROMPT")" || true

  echo "$OUTPUT"

  PROMISE_TEXT="$(echo "$OUTPUT" | perl -0777 -pe 's/.*?<promise>(.*?)<\/promise>.*/$1/s; s/^\s+|\s+$//g; s/\s+/ /g' 2>/dev/null || echo "")"

  if [ "$PROMISE_TEXT" = "$COMPLETION_PROMISE" ]; then
    echo "=== Ralph: COMPLETE at iteration $i ==="
    exit 0
  fi

  echo "--- Iteration $i done, continuing... ---"
  sleep 2
done

echo "Ralph: max iterations ($MAX_ITERATIONS) reached without completion."
exit 1
