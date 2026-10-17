#!/usr/bin/env bash
#

set -uo pipefail

SLEEP_INTERVAL="${SLEEP_INTERVAL:-3600}"

while :
do
    # Audio Only
    if [ -s /config/lists/audioonly.list ]
    then
        yt-dlp --config-locations "/config/ytdlpconfig/audioonly.config" 2>&1 | tee /config/logs/audioonly.log | sed 's/^/[ytdl] /'
    else
        echo "[ytdl] audio only download list is empty"
    fi

    # Channels
    if [ -s /config/lists/channels.list ]
    then
        yt-dlp --config-locations "/config/ytdlpconfig/channels.config" 2>&1 | tee /config/logs/channels.log | sed 's/^/[ytdl] /'
    else
        echo "[ytdl] channels download list is empty"
    fi

    # Playlists
    if [ -s /config/lists/playlists.list ]
    then
        yt-dlp --config-locations "/config/ytdlpconfig/playlists.config" 2>&1 | tee /config/logs/playlists.log | sed 's/^/[ytdl] /'
    else
        echo "[ytdl] playlists download list is empty"
    fi

    echo "[ytdl] Sleeping ${SLEEP_INTERVAL}s"
    sleep "$SLEEP_INTERVAL"
done
