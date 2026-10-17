#!/usr/bin/env bash
# Starts the image with empty bind mounts and checks that the setup ran, the
# files belong to PUID/PGID and all three services are up.
# Usage: tests/smoke.sh <image>
set -euo pipefail

IMAGE=${1:?usage: tests/smoke.sh <image>}
NAME=tdld-smoke-$$
DIR=$(mktemp -d)
# The caller's IDs, so the test can read and remove what the container
# writes; abc must not be root.
PUID=$(id -u); PGID=$(id -g)
[[ $PUID != 0 ]] || { PUID=1000; PGID=1000; }

# shellcheck disable=SC2317,SC2329 # called by the trap below (code differs by shellcheck version)
cleanup() {
    docker rm -f "$NAME" >/dev/null 2>&1 || true
    # Some files are written as root; remove them through a container.
    docker run --rm --entrypoint sh -v "$DIR:/w" "$IMAGE" -c 'rm -rf /w/*' >/dev/null 2>&1 || true
    rm -rf "$DIR"
}
trap cleanup EXIT

# Create the mounted folders first: Docker Desktop creates missing ones in
# its VM, not on the host, so the checks below would find nothing.
mkdir -p "$DIR/config" "$DIR/downloads" "$DIR/hotfolder"

docker run -d --name "$NAME" -e PUID="$PUID" -e PGID="$PGID" -e UMASK=002 \
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
banner=$(docker logs "$NAME" 2>&1)
if grep -q 'BASED ON IMAGES FROM LINUXSERVER\.IO' <<<"$banner" && ! grep -q 'Based on images from linuxserver\.io' <<<"$banner"; then
    echo "ok: TomJoad Images start banner"
else
    echo "FAILED: TomJoad Images start banner"; fail=1
fi
for f in lists/audioonly.list lists/channels.list lists/playlists.list \
         ytdlpconfig/audioonly.config ytdlpconfig/cookies.txt scripts/ytdl.sh; do
    check test -f "$DIR/config/$f"
done
for d in config config/lists downloads hotfolder hotfolder/input hotfolder/output hotfolder/processed; do
    owner=$(stat -c %u:%g "$DIR/$d")
    if [[ $owner == "$PUID:$PGID" ]]; then echo "ok: $d owned by $owner"; else echo "FAILED: $d owned by $owner"; fail=1; fi
done
for p in ytdl.sh server.py watch.sh; do
    check docker exec "$NAME" pgrep -u "$PUID" -f "$p"
done
if docker logs "$NAME" 2>&1 | grep -E 'Permission denied|No such file|fatal'; then
    echo "FAILED: errors in the log"; fail=1
fi
exit $fail
