#!/usr/bin/env bash
# Tests root/app/hotfolder/watch.sh with a stand-in ffmpeg (no real conversion).
# Usage: tests/test_hotfolder.sh
set -uo pipefail

HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
WATCH="$HERE/../root/app/hotfolder/watch.sh"
WORK=$(mktemp -d)
BIN="$WORK/bin"
mkdir -p "$BIN"
fail=0
WATCH_PID=""

# shellcheck disable=SC2317,SC2329 # called by the trap below
cleanup() {
    [[ -z $WATCH_PID ]] || kill "$WATCH_PID" 2>/dev/null
    pkill -f "$BIN/ffmpeg" 2>/dev/null
    rm -rf "$WORK"
}
trap cleanup EXIT

# The stand-in takes the last argument as its output. MODE decides what it does.
cat > "$BIN/ffmpeg" <<STUB
#!/usr/bin/env bash
out="\${*: -1}"
case "\${FAKE_FFMPEG_MODE:-ok}" in
    ok) echo mp3 > "\$out" ;;
    fail) echo half > "\$out"; exit 1 ;;
    slow) echo half > "\$out"; exec -a $BIN/ffmpeg sleep 30 ;;
esac
STUB
chmod +x "$BIN/ffmpeg"

new_case() {
    CASE="$WORK/$1"
    mkdir -p "$CASE/in" "$CASE/out" "$CASE/done"
}
start_watch() {
    PATH="$BIN:$PATH" HOTFOLDER_IN="$CASE/in" HOTFOLDER_OUT="$CASE/out" HOTFOLDER_PROCESSED="$CASE/done" \
        HOTFOLDER_INTERVAL=1 SETTLE_SECONDS="${SETTLE:-3}" bash "$WATCH" > "$CASE/log" 2>&1 &
    WATCH_PID=$!
}
stop_watch() { kill "$WATCH_PID" 2>/dev/null; wait "$WATCH_PID" 2>/dev/null; WATCH_PID=""; }
check() { # description, command...
    local what=$1; shift
    if "$@"; then echo "ok: $what"; else echo "FAILED: $what"; sed 's/^/    log: /' "$CASE/log"; fail=1; fi
}
# shellcheck disable=SC2317,SC2329 # called through check
absent() { [[ ! -e $1 ]]; }
# shellcheck disable=SC2317,SC2329 # called through check
present() { [[ -e $1 ]]; }

# 1. A copy that keeps the source's old mtime and is still growing.
new_case growing
echo a > "$CASE/in/clip.mp4"; touch -d '2 days ago' "$CASE/in/clip.mp4"
start_watch
sleep 2.5
echo more >> "$CASE/in/clip.mp4"; touch -d '2 days ago' "$CASE/in/clip.mp4"
sleep 2
check "old mtime, size changed: not converted yet" absent "$CASE/out/clip.mp4.mp3"
sleep 6
stop_watch
check "settled file is converted" present "$CASE/out/clip.mp4.mp3"
check "settled file is moved to processed" present "$CASE/done/clip.mp4"
check "no partial file left" absent "$CASE/out/.clip.mp4.mp3.partial"

# 2. A file with an old mtime that was just created is not settled (ctime).
new_case fresh
echo a > "$CASE/in/new.mkv"; touch -d '2 days ago' "$CASE/in/new.mkv"
SETTLE=30 start_watch
sleep 4
stop_watch
check "old mtime but fresh ctime: waits" absent "$CASE/out/new.mkv.mp3"

# 3. ffmpeg fails: nothing that looks finished is left behind.
new_case failing
echo a > "$CASE/in/bad.mp4"; touch -d '2 days ago' "$CASE/in/bad.mp4"
sleep 3.2
FAKE_FFMPEG_MODE=fail start_watch
sleep 4
stop_watch
check "failed conversion leaves no output" bash -c "[[ -z \$(ls -A '$CASE/out') ]]"
check "failed conversion leaves the source" present "$CASE/in/bad.mp4"
check "failed conversion is not retried while the file is unchanged" \
    bash -c "[[ \$(grep -c 'converting bad.mp4' '$CASE/log') == 1 ]]"

# 4. The container stops during a conversion; the next start cleans up.
new_case stopped
echo a > "$CASE/in/long.mp4"; touch -d '2 days ago' "$CASE/in/long.mp4"
sleep 3.2
FAKE_FFMPEG_MODE=slow start_watch
sleep 4
check "partial output is hidden while converting" present "$CASE/out/.long.mp4.mp3.partial"
check "no final mp3 while converting" absent "$CASE/out/long.mp4.mp3"
pkill -f "$BIN/ffmpeg" 2>/dev/null
stop_watch
check "interrupted conversion never became long.mp4.mp3" absent "$CASE/out/long.mp4.mp3"
rm -f "$CASE/in/long.mp4"
start_watch
sleep 1
stop_watch
check "restart removes the leftover partial file" absent "$CASE/out/.long.mp4.mp3.partial"

# 5. A file that stat can't read is skipped, without a shell error.
new_case vanished
ln -s "$CASE/in/gone.mp4" "$CASE/in/dangling.mp4"
start_watch
sleep 3
stop_watch
check "unreadable file: no syntax error" bash -c "! grep -qi 'syntax error\|unbound' '$CASE/log'"
check "unreadable file: loop kept running" grep -q 'checking' "$CASE/log"

# 6. The original can't be moved to processed: converted once, not every round.
new_case stuck
echo a > "$CASE/in/stuck.mp4"; touch -d '2 days ago' "$CASE/in/stuck.mp4"
chmod 555 "$CASE/done"
SETTLE=1 start_watch
sleep 5
stop_watch
chmod 755 "$CASE/done"
check "unmovable original: mp3 written" present "$CASE/out/stuck.mp4.mp3"
check "unmovable original: converted only once" \
    bash -c "[[ \$(grep -c 'converting stuck.mp4' '$CASE/log') == 1 ]]"
check "unmovable original: the error is logged" grep -q 'ERROR: .*could not be moved' "$CASE/log"
check "unmovable original: no 'done' line" bash -c "! grep -q 'done: stuck' '$CASE/log'"

# 7. A file with the name of an earlier one doesn't overwrite its mp3 or original.
new_case samename
echo old-mp3 > "$CASE/out/clip.mp4.mp3"
echo old-original > "$CASE/done/clip.mp4"
echo a > "$CASE/in/clip.mp4"; touch -d '2 days ago' "$CASE/in/clip.mp4"
SETTLE=1 start_watch
sleep 4
stop_watch
check "same name: earlier mp3 kept" grep -qx old-mp3 "$CASE/out/clip.mp4.mp3"
check "same name: earlier original kept" grep -qx old-original "$CASE/done/clip.mp4"
check "same name: new mp3 under a free name" present "$CASE/out/clip (2).mp4.mp3"
check "same name: new original under the same free name" present "$CASE/done/clip (2).mp4"

# 8. A name that fills the 255 bytes a file name may have.
new_case longname
long="$(printf 'ä%.0s' {1..122})x.mp4" # 122 two-byte characters + "x.mp4": 249 bytes
echo a > "$CASE/in/$long"; touch -d '2 days ago' "$CASE/in/$long"
SETTLE=1 start_watch
sleep 4
stop_watch
check "long name: converted" bash -c "ls '$CASE/out' | grep -q '\.mp4\.mp3\$'"
check "long name: original moved" absent "$CASE/in/$long"
check "long name: shortened name is valid UTF-8" bash -c "ls '$CASE/out' | iconv -f UTF-8 -t UTF-8 >/dev/null"
check "long name: converted only once" bash -c "[[ \$(grep -c 'converting ' '$CASE/log') == 1 ]]"

exit $fail
