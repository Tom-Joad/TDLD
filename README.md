# TDLD

TDLD is a self-contained [yt-dlp](https://github.com/yt-dlp/yt-dlp) container, built on the
[linuxserver.io](https://www.linuxserver.io/) Alpine base image, that:

* polls three link lists (audio-only, channels, playlists) on a timer and downloads new content with `yt-dlp` + `ffmpeg`
* serves a small web UI for editing those link lists, starting a single download and reading the logs
* watches a "hotfolder" and converts dropped video files to `.mp3` on a timer

> **About this repository:** TDLD is published here as an export of a private source repository and
> is overwritten with every sync. Issues and security reports are handled here; pull requests
> can't be merged directly, but are welcome as suggestions and are carried over by hand.

## Table of contents

* [Application setup](#application-setup)
* [YouTube "Sign in to confirm you're not a bot"](#youtube-sign-in-to-confirm-youre-not-a-bot)
* [Web UI](#web-ui)
* [Hotfolder (video → mp3)](#hotfolder-video--mp3)
* [Supported architectures](#supported-architectures)
* [Usage](#usage)
* [Parameters](#parameters)
* [User / group identifiers](#user--group-identifiers)
* [Upgrading from 1.x](#upgrading-from-1x)
* [Support info](#support-info)
* [Building locally](#building-locally)

## Application setup

Map a folder to `/config` for the settings and one to `/downloads` for the media; the
container creates everything it needs on first start:

| Path | Contents |
| --- | --- |
| `/config/lists/*.list` | Download lists, one URL per line: `audioonly`, `channels`, `playlists` |
| `/config/ytdlpconfig/*.config` | yt-dlp config per list: quality, output naming, etc. |
| `/config/ytdlpconfig/cookies.txt` | YouTube cookies, see [bot-detection](#youtube-sign-in-to-confirm-youre-not-a-bot) |
| `/config/archives` | yt-dlp download archives, so nothing is downloaded twice |
| `/config/logs` | Per-list download logs (also shown in the web UI) |
| `/config/scripts/ytdl.sh` | The download loop, copied on first start; edit it here to customise it |
| `/downloads` | Downloaded media, in `audioonly/`, `channels/` and `playlists/` |
| `/hotfolder` | `input/`, `output/` and `processed/` of the [hotfolder](#hotfolder-video--mp3) |

Edit the lists by hand or via the [web UI](#web-ui) on port `8083`. Files in `/config` that you
changed or deleted are not overwritten; a deleted list or config file is recreated with the
defaults on the next start.

The download loop logs to the container log (`docker logs`) and to `/config/logs/*.log`.

## YouTube "Sign in to confirm you're not a bot"

YouTube increasingly blocks unauthenticated download requests with errors like
`Sign in to confirm you're not a bot` or `LOGIN_REQUIRED`. The image ships two mitigations, but
one of them needs a one-time manual step from you:

* **JS runtime (automatic):** the image includes `quickjs` so `yt-dlp` can solve YouTube's JS
  challenges and generate PO tokens itself. Nothing to configure.
* **Cookies (manual, and the important one):** every `*.config` file references
  `/config/ytdlpconfig/cookies.txt`. On first start a placeholder (comment-only) file is
  created there so `yt-dlp` doesn't error out, but it contains no actual cookies yet. To actually
  get past bot-detection, export cookies from a browser that's logged into YouTube — e.g. with the
  ["Get cookies.txt LOCALLY"](https://chromewebstore.google.com/detail/get-cookiestxt-locally/cclelndahbckbenkjhflpdbgdldlbecc)
  extension — and overwrite `/config/ytdlpconfig/cookies.txt` with the exported file.
  Re-export it whenever YouTube invalidates the session (you'll see the bot-detection error return).

## Web UI

A minimal web UI is served on port `8083`. Open `http://<host>:8083/` in a browser to edit the
three lists (**Save All** writes straight to the `.list` files the download loop reads), start a
single download with one of the three profiles, and read the latest log lines.

The web UI has no login. Don't expose it to the internet; put it behind a reverse proxy with
authentication if you need access from outside your network.

## Hotfolder (video → mp3)

Drop a video file into `/hotfolder/input` and the container extracts the audio to
`/hotfolder/output/<filename>.mp3` on its next check (every `HOTFOLDER_INTERVAL` seconds,
default 5 minutes), then moves the original into `/hotfolder/processed`.

Supported source extensions: `.mp4`, `.mkv`, `.avi`, `.mov`, `.webm`, `.flv`, `.wmv`, `.m4v`
(case-insensitive). The output filename includes the original extension (e.g. `clip.mp4.mp3`,
`clip.mkv.mp3`) so two files that only differ by extension never overwrite each other.

## Supported architectures

Pulling `ghcr.io/tom-joad/tdld:latest` retrieves the correct image for your architecture.

| Architecture | Available | Tag |
| :----: | :----: | ---- |
| x86-64 | ✅ | latest / 2 / 2.0.0 |
| arm64 | ✅ | latest / 2 / 2.0.0 |

`latest` follows every change; `2` stays on 2.x and never brings a change that needs action when
upgrading; `2.0.0` is fixed. Releases with upgrade notes are listed under
[Releases](https://github.com/Tom-Joad/TDLD/releases).

## Usage

### docker-compose (recommended)

```yaml
---
services:
  tdld:
    image: ghcr.io/tom-joad/tdld:latest
    container_name: tdld
    environment:
      - PUID=1000
      - PGID=1000
      - UMASK=022
      - TZ=Europe/Berlin
    ports:
      - 8083:8083
    volumes:
      - /path/to/tdld/config:/config
      - /path/to/downloads:/downloads
      - /path/to/hotfolder:/hotfolder #optional
    restart: unless-stopped
```

### docker cli

```bash
docker run -d \
  --name=tdld \
  -e PUID=1000 \
  -e PGID=1000 \
  -e UMASK=022 \
  -e TZ=Europe/Berlin \
  -p 8083:8083 \
  -v /path/to/tdld/config:/config \
  -v /path/to/downloads:/downloads \
  -v /path/to/hotfolder:/hotfolder `#optional` \
  --restart unless-stopped \
  ghcr.io/tom-joad/tdld:latest
```

### Unraid

Add `https://github.com/Tom-Joad/TDLD` under **Template repositories** at the bottom of the
**Docker** tab and save, then **Add Container** and pick `tdld` from the template list.
Alternatively, save [`unraid/tdld.xml`](unraid/tdld.xml) as
`/boot/config/plugins/dockerMan/templates-user/my-tdld.xml` on the flash drive.

The template is set up with `PUID=99`, `PGID=100` (Unraid's `nobody:users`) and `UMASK=002`, so new
files are writable for the `users` group, e.g. over SMB. Point **Downloads** at a media share
rather than appdata.

### Synology (Container Manager)

The image is hosted on GitHub Container Registry (`ghcr.io`), not Docker Hub. In **Container
Manager** → **Registry** → **Settings** → **Add**, add `https://ghcr.io`, or use **Image** →
**Add** → **Add From URL** with `ghcr.io/tom-joad/tdld:latest`. Then create the container
with the ports, folders and variables from [Parameters](#parameters); `PUID`/`PGID` are the
IDs of your DSM user (`id <user>` over SSH).

## Parameters

| Parameter | Function |
| :----: | --- |
| `-p 8083` | Web UI |
| `-e PUID=1000` | User ID that owns new files, see [below](#user--group-identifiers) |
| `-e PGID=1000` | Group ID that owns new files |
| `-e UMASK=022` | Permissions of new files; `002` makes them writable for the group |
| `-e TZ=Europe/Berlin` | Timezone, [list](https://en.wikipedia.org/wiki/List_of_tz_database_time_zones#List) |
| `-e SLEEP_INTERVAL=3600` | Seconds between download-list runs |
| `-e AUTO_UPDATE_YTDLP=false` | `true`: update yt-dlp with pip once at every container start, instead of waiting for a new image |
| `-e HOTFOLDER_INTERVAL=300` | Seconds between hotfolder checks |
| `-e WEBUI_PORT=8083` | Port the web UI listens on inside the container |
| `-e HOTFOLDER_IN=/hotfolder/input` | Folder watched for new video files |
| `-e HOTFOLDER_OUT=/hotfolder/output` | Where converted `.mp3` files are written |
| `-e HOTFOLDER_PROCESSED=/hotfolder/processed` | Where source files are moved after conversion |
| `-v /config` | Lists, yt-dlp configs, archives, logs and the download script |
| `-v /downloads` | Downloaded media |
| `-v /hotfolder` | Hotfolder input, output and processed files (optional) |

## User / group identifiers

The services run as the user `abc`, whose IDs are set with `PUID` and `PGID`, so files in
mapped folders belong to a user on the host instead of root. Use the IDs of the host user that
owns those folders; `id <user>` shows them:

```bash
$ id youruser
uid=1000(youruser) gid=1000(youruser) groups=1000(youruser)
```

`/config` is handed to that user on every start. `/downloads` and `/hotfolder` are only taken
over when Docker created them (they belong to root); folders that already belong to someone else
are left as they are.

## Upgrading from 1.x

2.0 moves everything out of `/app/data`, and `UID`/`GID` are replaced by `PUID`/`PGID` (the old
variables never had an effect). To upgrade an existing container:

1. Keep the old `/app/data` mapping for the first start and add the new mappings: an empty
   folder for `/config`, and your download folder (before `/app/data/output`) for `/downloads`.
2. On the first start the lists, the yt-dlp configs (with their paths rewritten) and the download
   archives are copied to `/config`; the log shows `migrating /app/data to /config`. A customised
   `ytdl.sh` is not copied, because it still uses the old paths: carry your changes over to
   `/config/scripts/ytdl.sh`.
3. Check the lists in the web UI, then remove the `/app/data` mapping. Set `PUID`/`PGID`
   instead of `UID`/`GID`.

## Support info

* Shell access whilst the container is running: `docker exec -it tdld /bin/bash`
* To monitor the logs of the container in realtime: `docker logs -f tdld`
* Container version: `docker inspect -f '{{ index .Config.Labels "build_version" }}' tdld`
* Image version: `docker inspect -f '{{ index .Config.Labels "build_version" }}' ghcr.io/tom-joad/tdld:latest`

Changes are listed in the [changelog](CHANGELOG.md). Security problems: see [SECURITY.md](SECURITY.md).

## Building locally

```bash
git clone https://github.com/Tom-Joad/TDLD.git
cd TDLD
docker build \
  --no-cache \
  --pull \
  --build-arg VERSION=local \
  --build-arg BUILD_DATE="$(date -u +%Y-%m-%d)" \
  -t ghcr.io/tom-joad/tdld:latest .
```

## License

[MIT](LICENSE)
