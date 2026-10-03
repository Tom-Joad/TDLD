#!/usr/bin/env bash
# Starts the image with empty bind mounts and checks that the setup ran, the
# files belong to PUID/PGID and all three services are up.
# Usage: tests/smoke.sh <image>
set -euo pipefail

IMAGE=${1:?usage: tests/smoke.sh <image>}
NAME=tdld-smoke-$$
DIR=$(mktemp -d)
trap 'docker rm -f "$NAME" >/dev/null 2>&1 || true; sudo rm -rf "$DIR" 2>/dev/null || rm -rf "$DIR"' EXIT

docker run -d --name "$NAME" -e PUID=1234 -e PGID=1234 -e UMASK=002 \
    -v "$DIR/config:/config" -v "$DIR/downloads:/downloads" -v "$DIR/hotfolder:/hotfolder" \
    "$IMAGE" >/dev/null

for _ in $(seq 60); do
    status=$(docker inspect -f '{{.State.Health.Status}}' "$NAME")
    [[ $status == healthy ]] && break
    sleep 2
done
docker logs "$NAME"
[[ $status == healthy ]] || { echo "container is $status, not healthy"; exit 1; }

fail=0
check() { if "$@" >/dev/null; then echo "ok: $*"; else echo "FAILED: $*"; fail=1; fi; }
for f in lists/audioonly.list lists/channels.list lists/playlists.list \
         ytdlpconfig/audioonly.config ytdlpconfig/cookies.txt scripts/ytdl.sh; do
    check test -f "$DIR/config/$f"
done
for d in config config/lists downloads hotfolder hotfolder/input hotfolder/output hotfolder/processed; do
    owner=$(stat -c %u:%g "$DIR/$d")
    if [[ $owner == 1234:1234 ]]; then echo "ok: $d owned by $owner"; else echo "FAILED: $d owned by $owner"; fail=1; fi
done
for p in ytdl.sh server.py watch.sh; do
    check docker exec "$NAME" pgrep -u 1234 -f "$p"
done
if docker logs "$NAME" 2>&1 | grep -E 'Permission denied|No such file|fatal'; then
    echo "FAILED: errors in the log"; fail=1
fi
exit $fail
