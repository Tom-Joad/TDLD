#!/usr/bin/env bash
#

set -uo pipefail

# shellcheck source=/dev/null
source /app/lib/log.sh

SLEEP_INTERVAL="${SLEEP_INTERVAL:-3600}"
LOCK_DIR=/config/locks
mkdir -p "$LOCK_DIR"

# Runs yt-dlp for one profile (audioonly, channels, playlists) unless its list
# is empty. The lock is shared with the web UI's "Download Now": only one
# yt-dlp works on a profile at a time, they'd write the same archive, files
# and log. A scheduled run waits for a manual download to finish.
run_profile() { # name label
    local name=$1 label=$2
    if [ -s "/config/lists/${name}.list" ]
    then
        (
            flock 9
            yt-dlp --config-locations "/config/ytdlpconfig/${name}.config" 2>&1 \
                | tee "/config/logs/${name}.log" | log_pipe ytdl
        ) 9>"$LOCK_DIR/${name}.lock"
    else
        log ytdl "${label} download list is empty"
    fi
}

while :
do
    run_profile audioonly "audio only"
    run_profile channels "channels"
    run_profile playlists "playlists"

    log ytdl "Sleeping ${SLEEP_INTERVAL}s"
    sleep "$SLEEP_INTERVAL"
done
