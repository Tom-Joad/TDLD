#!/usr/bin/env bash

HOTFOLDER_IN="${HOTFOLDER_IN:-/hotfolder/input}"
HOTFOLDER_OUT="${HOTFOLDER_OUT:-/hotfolder/output}"
HOTFOLDER_PROCESSED="${HOTFOLDER_PROCESSED:-/hotfolder/processed}"
HOTFOLDER_INTERVAL="${HOTFOLDER_INTERVAL:-300}"
# A file still being copied in (over SMB, from a phone) must not be converted
# half-way and then moved away: wait until it hasn't changed for this long.
SETTLE_SECONDS=60

VIDEO_EXTENSIONS=(mp4 mkv avi mov webm flv wmv m4v)

echo "[hotfolder] checking ${HOTFOLDER_IN} for video files (${VIDEO_EXTENSIONS[*]}) every ${HOTFOLDER_INTERVAL}s, writing mp3s to ${HOTFOLDER_OUT}"

shopt -s nullglob nocaseglob

while :
do
    for ext in "${VIDEO_EXTENSIONS[@]}"; do
        for SRC in "$HOTFOLDER_IN"/*."$ext"; do
            if (( $(date +%s) - $(stat -c %Y "$SRC") < SETTLE_SECONDS )); then
                echo "[hotfolder] $(basename "$SRC") is still changing, next round"
                continue
            fi
            FILENAME="$(basename "$SRC")"
            MP3NAME="$FILENAME.mp3"
            DEST="$HOTFOLDER_OUT/$MP3NAME"
            echo "[hotfolder] converting $FILENAME -> $MP3NAME"
            if ffmpeg -y -i "$SRC" -vn -acodec libmp3lame -q:a 2 "$DEST"; then
                mv "$SRC" "$HOTFOLDER_PROCESSED/$FILENAME"
                echo "[hotfolder] done: $MP3NAME"
            else
                echo "[hotfolder] ffmpeg failed for $FILENAME, leaving it in place"
            fi
        done
    done

    sleep "$HOTFOLDER_INTERVAL"
done
