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

COOKIES_FILE="/app/data/config/ytdlpconfig/cookies.txt"
if [ ! -f "$COOKIES_FILE" ]; then
    echo "${COOKIES_FILE} does not exist. Creating a placeholder"
    cat > "$COOKIES_FILE" <<'EOF'
# Netscape HTTP Cookie File
# Placeholder file. yt-dlp is configured to read cookies from this file
# (see the --cookies line in the *.config files) to avoid YouTube's
# "Sign in to confirm you're not a bot" errors. Replace this file with
# cookies exported from a logged-in YouTube session, e.g. via the
# "Get cookies.txt LOCALLY" browser extension. See the README for details.
EOF
fi

if [ ! -f /app/data/scripts/ytdl.sh ]; then
    echo "/app/data/scripts/ytdl.sh does not exist. creating it"
    cp -R /tmp/ytdl.sh /app/data/scripts/ytdl.sh
fi

chown -R nobody /app/data
chmod -R 777 /app/data

exit 0
