# TDLD Docker Container

TDLD is a self-contained [yt-dlp](https://github.com/yt-dlp/yt-dlp) container that:

* polls three link lists (audio-only, channels, playlists) on a timer and downloads new content with `yt-dlp` + `ffmpeg`
* serves a small web UI for editing those link lists from a browser
* watches a "hotfolder" directory and converts dropped video files to `.mp3` on a timer

## Table of contents

* [Application setup](#application-setup)
* [Web UI](#web-ui)
* [Hotfolder (video → mp3)](#hotfolder-video--mp3)
* [Supported architectures](#supported-architectures)
* [Version tags](#version-tags)
* [Usage](#usage)
  * [docker-compose](#docker-compose-recommended)
  * [docker cli](#docker-cli)
  * [Unraid](#unraid)
  * [Synology (Container Manager / Docker)](#synology-container-manager--docker)
* [Environment variables](#environment-variables)
* [Volumes / paths](#volumes--paths)
* [Support info](#support-info)
* [Building locally](#building-locally)
* [Versions](#versions)

## Application setup

Mount a host directory to `/app/data` (see [Volumes / paths](#volumes--paths) below) — the container
creates everything it needs inside it on first start.

Download lists (one URL per line), inside your mounted config volume:

* `/app/data/config/lists/audioonly.list` - audio-only downloads
* `/app/data/config/lists/channels.list` - full channel links
* `/app/data/config/lists/playlists.list` - playlist links

You can edit these by hand, or via the [web UI](#web-ui) on port `8083`.

The `yt-dlp` config files used for each list live at `/app/data/config/ytdlpconfig/*.config` and can be
edited to change download quality, output naming, etc. Downloaded media lands in `/app/data/output`.

The download loop logs to the docker console (`docker logs`) and to `/app/data/logs/*.log`.

## Web UI

A minimal web UI for editing the three download lists is served on port `8083` (see
[Environment variables](#environment-variables) to change the port). Open `http://<host>:8083/` in a
browser, edit any of the lists, and click **Save All** — changes are written straight to the
`.list` files the download loop reads from.

## Hotfolder (video → mp3)

Drop a video file into `/app/data/hotfolder/input` and the container will extract the audio to
`/app/data/hotfolder/output/<filename>.mp3` on its next check (every `HOTFOLDER_INTERVAL` seconds,
default 5 minutes), then move the original into `/app/data/hotfolder/processed`.

Supported source extensions: `.mp4`, `.mkv`, `.avi`, `.mov`, `.webm`, `.flv`, `.wmv`, `.m4v`
(case-insensitive). The output filename includes the original extension (e.g. `clip.mp4.mp3`,
`clip.mkv.mp3`) so two files that only differ by extension never overwrite each other.

## Supported Architectures

Simply pulling `ghcr.io/tom-joad/tdld:latest` should retrieve the correct image for your arch, but you can also pull specific arch images via tags.

The architectures supported by this image are:

| Architecture | Available | Tag |
| :----: | :----: | ---- |
| x86-64 | ✅ | latest / \<version tag\> |
| arm64 | ✅ | latest / \<version tag\> |

## Version Tags

This image provides various versions that are available via tags. Please read the descriptions carefully and exercise caution when using unstable or development tags.

| Tag    | Available | Description |
| :----: | :----: |--- |
| latest | ✅ | Stable releases |
| dev    | ✅ | Development releases - unstable |

## Usage

Here are some example snippets to help you get started creating a container.

### docker-compose (recommended)

```yaml
---
version: "2.1"
services:
  tdld:
    image: ghcr.io/tom-joad/tdld:latest
    container_name: tdld
    environment:
      - UID=1000
      - GID=1000
      - TZ=Europe/Berlin
      - SLEEP_INTERVAL=3600
      - AUTO_UPDATE_YTDLP=false
      - HOTFOLDER_INTERVAL=300
    ports:
      - 8083:8083
    volumes:
      - /path/to/config:/app/data
      - /path/to/downloads:/app/data/output
      - /path/to/hotfolder:/app/data/hotfolder
    restart: unless-stopped
```

### docker cli

See the [docker run reference](https://docs.docker.com/engine/reference/commandline/run/) for more info.

```bash
docker run -d \
  --name=tdld \
  -e UID=1000 \
  -e GID=1000 \
  -e TZ=Europe/Berlin \
  -p 8083:8083 \
  -v /path/to/config:/app/data \
  -v /path/to/downloads:/app/data/output \
  -v /path/to/hotfolder:/app/data/hotfolder \
  --restart unless-stopped \
  ghcr.io/tom-joad/tdld:latest
```

### Unraid

This image isn't in Community Applications yet, so add it manually:

1. **Docker** tab → **Add Container**, then toggle **Advanced View** (top right) so you can add
   custom path mappings and variables.
2. Fill in:
   * **Name**: `tdld`
   * **Repository**: `ghcr.io/tom-joad/tdld:latest`
   * **Network Type**: `Bridge`
   * **WebUI**: `http://[IP]:[PORT:8083]/`
3. **Port Mappings**: container port `8083` → a host port of your choice (`8083` is fine unless it's
   already taken).
4. **Path Mappings** (add each as its own entry):
   * Container Path `/app/data` → Host Path e.g. `/mnt/user/appdata/tdld`
   * Container Path `/app/data/output` → Host Path e.g. `/mnt/user/media/youtube` (so downloads
     land directly on your media share instead of inside appdata)
   * Container Path `/app/data/hotfolder` → Host Path e.g. `/mnt/user/media/hotfolder` (optional,
     only if you use the hotfolder feature)
5. **Variables**: at minimum set `TZ` to your timezone. Unraid's built-in `nobody` user is
   `UID=99` / `GID=100` — set those explicitly (`UID=99`, `GID=100`) rather than the `1000`/`1000`
   used in the generic examples above, so file ownership on your array matches what Unraid expects.
6. Apply, then check **Docker** → container icon → **Logs** to confirm it started cleanly.

### Synology (Container Manager / Docker)

The image is hosted on GitHub Container Registry (`ghcr.io`), not Docker Hub, so DSM's built-in
registry search won't find it — you need to add the registry first.

1. Open **Container Manager** (DSM 7.2+) or **Docker** (older DSM) → **Registry** → settings gear
   icon → **Add**, and add:
   * **Name**: anything, e.g. `ghcr`
   * **URL**: `https://ghcr.io`
2. Go to **Registry**, search for `tom-joad/tdld`, and download the `latest` tag — or, if search
   doesn't surface it, use **Image** → **Add** → **Add From URL** with
   `ghcr.io/tom-joad/tdld:latest` directly.
3. **Image** → select the downloaded image → **Run** to open the container wizard:
   * **Port Settings**: Local Port `8083` → Container Port `8083` (change the local port if `8083` is
     already used by something else on your NAS).
   * **Volume**: add folder mappings for
     * a shared folder (e.g. `docker/tdld/config`) → `/app/data`
     * a shared folder for finished downloads (e.g. `docker/tdld/output` or a media share) →
       `/app/data/output`
     * optionally a shared folder → `/app/data/hotfolder`
   * **Environment**: add `UID`, `GID`, `TZ`, and any of the optional variables below.
   * Enable **Enable auto-restart**.
4. Start the container, then confirm via **Container** → **Details** → **Log** that it came up
   cleanly, and open `http://<nas-ip>:8083/` for the web UI.

## Environment variables

| Variable | Default | Description |
| --- | --- | --- |
| `UID` | `911` | User ID to run as (match your host's file ownership) |
| `GID` | `911` | Group ID to run as |
| `TZ` | - | Timezone, e.g. `Europe/Berlin` |
| `SLEEP_INTERVAL` | `3600` | Seconds between download-list runs |
| `AUTO_UPDATE_YTDLP` | `false` | Set `true` to `pip install -U yt-dlp` on every container start (default relies on rebuilding/pulling the image for updates instead) |
| `HOTFOLDER_INTERVAL` | `300` | Seconds between hotfolder checks for new video files |
| `WEBUI_PORT` | `8083` | Port the web UI listens on inside the container |
| `LISTS_DIR` | `/app/data/config/lists` | Where the web UI reads/writes the `.list` files |
| `HOTFOLDER_IN` | `/app/data/hotfolder/input` | Directory watched for new video files |
| `HOTFOLDER_OUT` | `/app/data/hotfolder/output` | Where converted `.mp3` files are written |
| `HOTFOLDER_PROCESSED` | `/app/data/hotfolder/processed` | Where source files are moved after conversion |

## Volumes / paths

Everything lives under `/app/data`, so a single volume mount at `/app/data` is enough to persist
all state (a separate mount for `/app/data/output` is common so downloads land on a different
disk/share than config).

| Path | Contents |
| --- | --- |
| `/app/data/config/lists/*.list` | Download lists edited by hand or via the web UI |
| `/app/data/config/ytdlpconfig/*.config` | Per-list yt-dlp config files |
| `/app/data/output` | Downloaded media |
| `/app/data/logs` | Per-list download logs |
| `/app/data/archives` | yt-dlp download archive files (dedup tracking) |
| `/app/data/scripts/ytdl.sh` | The download loop script (copied in on first start; edit it here to customize) |
| `/app/data/hotfolder/input` | Drop video files here to convert them to mp3 |
| `/app/data/hotfolder/output` | Converted mp3 files |
| `/app/data/hotfolder/processed` | Original video files, moved here after conversion |

## Support Info

* Shell access whilst the container is running: `docker exec -it tdld /bin/bash`
* To monitor the logs of the container in realtime: `docker logs -f tdld`
* container version number
  * `docker inspect -f '{{ index .Config.Labels "build_version" }}' tdld`
* image version number
  * `docker inspect -f '{{ index .Config.Labels "build_version" }}' ghcr.io/tom-joad/tdld:latest`

## Building locally

If you want to make local modifications to these images for development purposes or just to customize the logic:

```bash
git clone https://github.com/Tom-Joad/TDLD.git
cd TDLD
docker build \
  --no-cache \
  --pull \
  -t ghcr.io/tom-joad/tdld:latest .
```

## Versions

* **04.07.2026:** - Added web UI, hotfolder (multi-format video → mp3 on a timer), `AUTO_UPDATE_YTDLP`/`SLEEP_INTERVAL` env vars, and documentation for Unraid/Synology.
* **07.05.2022:** - Initial Release.
