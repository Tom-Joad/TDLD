#!/usr/bin/env bash

# shellcheck source=/dev/null
source "$(dirname "${BASH_SOURCE[0]}")/../lib/log.sh"

HOTFOLDER_IN="${HOTFOLDER_IN:-/hotfolder/input}"
HOTFOLDER_OUT="${HOTFOLDER_OUT:-/hotfolder/output}"
HOTFOLDER_PROCESSED="${HOTFOLDER_PROCESSED:-/hotfolder/processed}"
HOTFOLDER_INTERVAL="${HOTFOLDER_INTERVAL:-300}"
# A file still being copied in (over SMB, from a phone) must not be converted
# half-way and then moved away. It counts as settled when its size and
# modification time are the same as one round ago and the file's status
# change time (which a copy tool can't set back, unlike the modification
# time) is at least this old.
SETTLE_SECONDS="${SETTLE_SECONDS:-60}"

VIDEO_EXTENSIONS=(mp4 mkv avi mov webm flv wmv m4v)

# size:mtime of each file at the previous round
declare -A SEEN
# size:mtime of files whose conversion or move failed: they are left alone
# until they change (or the container restarts), instead of being converted
# again every round.
declare -A FAILED

# Gives up on the current file until it changes.
give_up() { # message...
    rm -f "$PARTIAL"
    FAILED["$SRC"]="$SIZE:$MTIME"
    log_error hotfolder "$*"
}

# Sets variable $2 to the length of $1 in bytes, whatever the locale.
bytes() { local LC_ALL=C; printf -v "$2" %d "${#1}"; }

# The name for a file's mp3 and its processed original: its own name, or
# "clip (2).mp4" when an earlier file of that name is still in the output or
# processed folder, so nothing is overwritten. A name too long for
# ".<name>.mp3.partial" (a file name has at most 255 bytes) is shortened.
free_name() { # file name
    local LC_ALL=C.UTF-8
    local stem=${1%.*} ext=.${1##*.} n=1 name len
    bytes "$stem$ext" len
    while (( len > 230 )); do
        stem=${stem%?}
        bytes "$stem$ext" len
    done
    name=$stem$ext
    while [[ -e $HOTFOLDER_OUT/$name.mp3 || -e $HOTFOLDER_PROCESSED/$name ]]; do
        n=$((n + 1))
        name="$stem ($n)$ext"
    done
    printf '%s\n' "$name"
}

log hotfolder "checking ${HOTFOLDER_IN} for video files (${VIDEO_EXTENSIONS[*]}) every ${HOTFOLDER_INTERVAL}s, writing mp3s to ${HOTFOLDER_OUT}"

shopt -s nullglob nocaseglob

# Conversions are written under a hidden name and renamed when ffmpeg
# succeeds. What a stop or a crash left behind from an earlier run is removed.
rm -f "$HOTFOLDER_OUT"/.*.mp3.partial

while :
do
    declare -A NOW=()
    for ext in "${VIDEO_EXTENSIONS[@]}"; do
        for SRC in "$HOTFOLDER_IN"/*."$ext"; do
            # A file renamed or removed since the glob can't be read: skip it.
            if ! STAT="$(stat -c '%s:%Y:%Z' "$SRC" 2>/dev/null)"; then
                continue
            fi
            IFS=: read -r SIZE MTIME CTIME <<<"$STAT"
            NOW["$SRC"]="$SIZE:$MTIME"
            FILENAME="$(basename "$SRC")"
            if [[ ${SEEN["$SRC"]-} != "$SIZE:$MTIME" ]] || (( $(date +%s) - CTIME < SETTLE_SECONDS )); then
                log hotfolder "$FILENAME is still changing, next round"
                continue
            fi
            if [[ ${FAILED["$SRC"]-} == "$SIZE:$MTIME" ]]; then
                continue
            fi
            NAME="$(free_name "$FILENAME")"
            MP3NAME="$NAME.mp3"
            DEST="$HOTFOLDER_OUT/$MP3NAME"
            PARTIAL="$HOTFOLDER_OUT/.$MP3NAME.partial"
            log hotfolder "converting $FILENAME -> $MP3NAME"
            if ! ffmpeg -nostdin -y -i "$SRC" -vn -acodec libmp3lame -q:a 2 -f mp3 "$PARTIAL"; then
                give_up "ffmpeg failed for $FILENAME, leaving it in place; it is tried again when it changes"
                continue
            fi
            # The copy may have gone on while ffmpeg ran.
            if [[ "$(stat -c '%s:%Y' "$SRC" 2>/dev/null)" != "$SIZE:$MTIME" ]]; then
                rm -f "$PARTIAL"
                log hotfolder "$FILENAME changed during conversion, next round"
                continue
            fi
            if ! mv -f "$PARTIAL" "$DEST"; then
                give_up "could not write $DEST; $FILENAME is tried again when it changes"
                continue
            fi
            if ! mv "$SRC" "$HOTFOLDER_PROCESSED/$NAME"; then
                give_up "$MP3NAME is done, but $FILENAME could not be moved to $HOTFOLDER_PROCESSED;" \
                    "it is not converted again unless it changes"
                continue
            fi
            unset 'NOW["$SRC"]'
            log hotfolder "done: $MP3NAME"
        done
    done
    # Only files seen this round are remembered; the others are gone.
    SEEN=()
    for key in "${!NOW[@]}"; do
        SEEN["$key"]="${NOW[$key]}"
    done
    for key in "${!FAILED[@]}"; do
        [[ ${NOW["$key"]-} == "${FAILED[$key]}" ]] || unset 'FAILED["$key"]'
    done

    sleep "$HOTFOLDER_INTERVAL"
done
