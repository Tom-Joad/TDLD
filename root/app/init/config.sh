#!/usr/bin/env bash
# shellcheck shell=bash

# Prepares /config: lists, yt-dlp configs, archives, logs and the download
# script. Run by init-tdld-config as abc, never as root: abc owns /config
# and could otherwise point a symlink there at a system file for root to
# overwrite.

set -euo pipefail

# shellcheck source=/dev/null
source /app/lib/log.sh

LISTS=(audioonly channels playlists)
LEGACY=/app/data

mkdir -p /config/locks /config/lists /config/ytdlpconfig /config/archives /config/logs /config/scripts \
    /config/cache

# Up to 1.x everything lived in /app/data. If that is still mounted and
# /config is new, take over the lists, the yt-dlp configs (with their paths
# rewritten) and the download archives, so nothing is downloaded twice.
if [[ -d ${LEGACY}/config/lists && ! -f /config/lists/channels.list ]]; then
    log init "migrating ${LEGACY} to /config"
    cp -R "${LEGACY}/config/lists/." /config/lists/
    if [[ -d ${LEGACY}/archives ]]; then
        cp -R "${LEGACY}/archives/." /config/archives/
    fi
    for file in "${LEGACY}"/config/ytdlpconfig/*; do
        [[ -f ${file} ]] || continue
        sed -e 's#/app/data/output#/downloads#g' \
            -e 's#/app/data/config/#/config/#g' \
            -e 's#/app/data/#/config/#g' \
            "${file}" > "/config/ytdlpconfig/$(basename "${file}")"
    done
    if [[ -f ${LEGACY}/scripts/ytdl.sh ]]; then
        log_warn init "${LEGACY}/scripts/ytdl.sh is not migrated, it uses the old paths. If you" \
            "changed it, carry your changes over to /config/scripts/ytdl.sh"
    fi
    if ! grep -qs ' /downloads ' /proc/mounts; then
        log_warn init "/downloads is not mapped: new downloads stay inside the container." \
            "Map your download folder (before: ${LEGACY}/output) to /downloads"
    fi
    # The old image made everything world-writable (777).
    find /config/lists /config/archives /config/ytdlpconfig -type f -exec chmod 644 {} +
fi

for name in "${LISTS[@]}"; do
    if [[ ! -f /config/lists/${name}.list ]]; then
        touch "/config/lists/${name}.list"
    fi
    if [[ ! -f /config/ytdlpconfig/${name}.config ]]; then
        cp "/defaults/ytdlpconfig/${name}.config" /config/ytdlpconfig/
    fi
done

if [[ ! -f /config/ytdlpconfig/cookies.txt ]]; then
    cat > /config/ytdlpconfig/cookies.txt <<'COOKIES'
# Netscape HTTP Cookie File
# Placeholder file. yt-dlp is configured to read cookies from this file
# (see the --cookies line in the *.config files) to avoid YouTube's
# "Sign in to confirm you're not a bot" errors. Replace this file with
# cookies exported from a logged-in YouTube session, e.g. via the
# "Get cookies.txt LOCALLY" browser extension. See the README for details.
COOKIES
fi

# The copy is the user's to edit, so it is only replaced while it is still a
# script an earlier release copied, unchanged. Without that, installations
# would keep running the old loop forever. When a release changes
# root/defaults/ytdl.sh, add the sha256 of the version it replaces here.
OLD_YTDL_SHA256S=(
    a8b90768b428dee03ed8f4c3f00dbcd3a935da7d5ffaf48dd7ed00192d06643e # 2.0.0 to 3.1.1
)
if [[ ! -f /config/scripts/ytdl.sh ]]; then
    cp /defaults/ytdl.sh /config/scripts/ytdl.sh
elif ! cmp -s /defaults/ytdl.sh /config/scripts/ytdl.sh; then
    current=$(sha256sum < /config/scripts/ytdl.sh)
    if [[ " ${OLD_YTDL_SHA256S[*]} " == *" ${current%% *} "* ]]; then
        cp /defaults/ytdl.sh /config/scripts/ytdl.sh
        log init "/config/scripts/ytdl.sh updated to this version's script"
    else
        log_warn init "/config/scripts/ytdl.sh differs from this version's script (/defaults/ytdl.sh)." \
            "Without its changes the scheduled run neither logs time stamps nor waits for a manual download"
    fi
fi
