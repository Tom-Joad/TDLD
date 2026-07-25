#!/bin/bash

set -euo pipefail

chown -R nobody /app/data
chmod -R 777 /app/data

DIRS=(
    /app/data/archives
    /app/data/scripts
    /app/data/config
    /app/data/logs
    /app/data/output
    /app/data/config/lists
    /app/data/config/ytdlpconfig
    /app/data/hotfolder/input
    /app/data/hotfolder/output
    /app/data/hotfolder/processed
)

for dir in "${DIRS[@]}"; do
    if [ -d "$dir" ]; then
        echo "${dir} exists."
    else
        echo "Error: ${dir} not found. Creating it"
        mkdir -p "$dir"
    fi
done

LISTS=(
    audioonly
    channels
    playlists
)

for name in "${LISTS[@]}"; do
    file="/app/data/config/lists/${name}.list"
    if [ -f "$file" ]; then
        echo "${file} exists."
    else
        echo "${file} does not exist. creating it"
        touch "$file"
    fi
done

if [ -z "$(ls -A /app/data/config/ytdlpconfig 2>/dev/null)" ]; then
    echo "/app/data/config/ytdlpconfig is empty. Populating it with defaults"
    cp -R /tmp/ytdlpconfig/. /app/data/config/ytdlpconfig/
fi

if [ ! -f /app/data/scripts/ytdl.sh ]; then
    echo "/app/data/scripts/ytdl.sh does not exist. creating it"
    cp -R /tmp/ytdl.sh /app/data/scripts/ytdl.sh
fi

chown -R nobody /app/data
chmod -R 777 /app/data

exit 0
