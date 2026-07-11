#!/bin/sh
#

set -uo pipefail

umask a=rwx

SLEEP_INTERVAL="${SLEEP_INTERVAL:-3600}"

while :
do
    # Audio Only
    if [ -s /app/data/config/lists/audioonly.list ]
    then
        yt-dlp --config-locations "/app/data/config/ytdlpconfig/audioonly.config" 2>&1 | tee /app/data/logs/audioonly.log | sed 's/^/[ytdl] /'
    else
        echo "[ytdl] audio only download list is empty"
    fi

    # Channels
    if [ -s /app/data/config/lists/channels.list ]
    then
        yt-dlp --config-locations "/app/data/config/ytdlpconfig/channels.config" 2>&1 | tee /app/data/logs/channels.log | sed 's/^/[ytdl] /'
    else
        echo "[ytdl] channels download list is empty"
    fi

    # Playlists
    if [ -s /app/data/config/lists/playlists.list ]
    then
        yt-dlp --config-locations "/app/data/config/ytdlpconfig/playlists.config" 2>&1 | tee /app/data/logs/playlists.log | sed 's/^/[ytdl] /'
    else
        echo "[ytdl] playlists download list is empty"
    fi

    echo "[ytdl] Sleeping ${SLEEP_INTERVAL}s"
    sleep "$SLEEP_INTERVAL"
done
