#!/bin/sh
# Toggle screen recording with wl-screenrec
# Start: select area with slurp, then record
# Stop: send SIGINT to running wl-screenrec

PIDFILE="${XDG_RUNTIME_DIR:-/tmp}/screenrec.pid"
FILEFILE="${XDG_RUNTIME_DIR:-/tmp}/screenrec.file"
OUTDIR="${HOME}/Desktop"

if [ -f "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
    # Stop recording
    kill -INT "$(cat "$PIDFILE")"
    rm -f "$PIDFILE"
    FILENAME=$(cat "$FILEFILE")
    rm -f "$FILEFILE"
    @notify_send@ -t 3000 "Recording saved" "$FILENAME"
    @gdbus@ call --session \
        --dest org.freedesktop.FileManager1 \
        --object-path /org/freedesktop/FileManager1 \
        --method org.freedesktop.FileManager1.ShowItems \
        "['file://$FILENAME']" "" > /dev/null 2>&1 &
else
    # Start recording
    mkdir -p "$OUTDIR"
    FILENAME="$OUTDIR/$(date +%Y%m%d%H%M%S).mp4"

    GEOMETRY=$(@slurp@)
    [ -z "$GEOMETRY" ] && exit 0

    @wl_screenrec@ -g "$GEOMETRY" -f "$FILENAME" &
    echo $! > "$PIDFILE"
    echo "$FILENAME" > "$FILEFILE"
    @notify_send@ -t 2000 "Recording started" "$FILENAME"
fi
