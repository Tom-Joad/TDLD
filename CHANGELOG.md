# Changelog

All notable changes to this project are listed here. Versions follow
[semantic versioning](https://semver.org/). A change that needs action when
upgrading (a renamed or removed setting, a different folder layout) only
comes with a new major version.

## [Unreleased]

### Changed
- Updated the base image (linuxserver/baseimage-alpine 3.24 from `d07ad0e`
  to `7315b19`).
- `/downloads` and `/hotfolder` are declared as volumes like `/config`, so
  their content no longer ends up in the container if one isn't mapped.

### Docs
- The README's tag table no longer names an old version.
- SECURITY.md describes how images are built, pinned and scanned.
- Changelog links for 2.0.2 to 2.0.4; the 3.0.0 link compares against 2.0.4.

## [3.2.0] - 2026-11-10

### Added
- Every log line has a time stamp (`[2026-11-10 12:00:00] [ytdl] …`), errors
  and warnings start with `ERROR:` and `WARNING:`, and the log opens with a
  `TDLD <version> starting` line with the settings that matter. The bug report
  template asks for it.
- The web UI shows which profile has a download running, scheduled or manual.

### Changed
- Only one yt-dlp works on a profile at a time: "Download Now" and the
  scheduled run share a lock per profile (`/config/locks`). A manual download
  while one is running is refused with a message; a scheduled run waits for a
  manual one to finish. Finished manual downloads are reaped. The scheduled
  script `/config/scripts/ytdl.sh` is replaced by the new one when it is the
  unchanged copy of an earlier version; a copy you changed is kept, and the
  start log says that it differs.
- A manual log is moved to `<name>-manual.log.1` when it has grown past 5 MiB,
  and the web UI reads only the end of a log instead of the whole file.
- All of yt-dlp's dependencies (`brotli`, `certifi`, `requests`, `urllib3`,
  `websockets` and the others the `default` extra pulls in) are pinned in
  `requirements.txt`, so builds of the same tag install the same versions and
  updates arrive as Dependabot pull requests. `AUTO_UPDATE_YTDLP` updates
  yt-dlp at start as before.

### Fixed
- Saving a download list no longer empties it first. The list is written to a
  temporary file and renamed over the old one, one save at a time per list, so
  a download run, a crash or a full disk can't see or leave an empty or cut-off
  list.
- The hotfolder no longer converts a file that is still being copied when the
  copy tool kept the source's old modification time. A file counts as ready
  when its size and modification time are the same as one round ago and its
  status change time is older than the settle time.
- The hotfolder writes each mp3 under a hidden temporary name and renames it
  when ffmpeg succeeds, so a failed or interrupted conversion no longer leaves
  a half-written mp3 that looks finished. A file that disappears between
  listing and reading is skipped.
- The web UI drops a client that stops sending its request body after 30
  seconds instead of holding a thread for good, and answers a `Content-Length`
  with characters such as `²` with `400` instead of a traceback.
- The web UI's log lines are no longer buffered, so they appear at once in
  `docker logs` and aren't lost when the container stops.
- The Docker Compose comment and the Unraid template now list all host names
  the web UI answers to without `TDLD_ALLOWED_HOSTS` (`localhost`, single
  words, `*.local`, `*.lan`, `*.home.arpa`, `*.internal`), as the README does.

## [3.1.1] - 2026-11-07

### Changed
- Updated dependencies:
  - linuxserver/baseimage-alpine from `52106d1` to `d07ad0e`

## [3.1.0] - 2026-11-06

### Added
- A `3.1`-style tag (major and minor version) next to `3`, `latest` and the
  full version.

### Changed
- Images are built from releases only, no longer from every change on the
  main branch. `latest` and `3` now move with each release, and a full
  version tag such as `3.1.0` always names exactly that release.

## [3.0.6] - 2026-11-03

### Security
- Security updates of the distribution packages, picked up by rebuilding the image:
  - `libexpat` 2.10.0-r0 (CVE-2026-117610, CVE-2026-118370)

## [3.0.5] - 2026-10-31

### Changed
- Updated dependencies:
  - linuxserver/baseimage-alpine from `7a59ee7` to `52106d1`
  - yt-dlp from 2026.8.19 to 2026.10.26

## [3.0.4] - 2026-10-28

### Security
- Security updates of the distribution packages, picked up by rebuilding the image:
  - `python3` 3.14.10-r1

## [3.0.3] - 2026-10-27

### Security
- Security updates of the distribution packages, picked up by rebuilding the image:
  - `python3` 3.14.10-r0 (CVE-2026-114583, CVE-2026-115557, CVE-2026-12345)

## [3.0.2] - 2026-10-26

### Security
- Security updates of the distribution packages, picked up by rebuilding the image:
  - `curl` 8.23.0-r0 (CVE-2026-92392)
  - `ffmpeg-libavcodec` 8.1.3-r0
  - `libcurl` 8.23.0-r0 (CVE-2026-92392)

## [3.0.1] - 2026-10-24

### Changed
- Updated dependencies:
  - linuxserver/baseimage-alpine from `b661ece` to `7a59ee7`
- The build upgrades the Alpine packages before installing anything, so
  every image has the current fixes, not only those of the pinned base
  image. Before, packages the base image ships (such as musl, brotli,
  c-ares and ca-certificates) stayed at its state until the next base
  image update.

## [3.0.0] - 2026-10-20

**Needs action when upgrading** if you open the web UI under a host name
other than an IP address, a single word (`tower`) or a `.local`, `.lan`,
`.home.arpa` or `.internal` name: add it to `TDLD_ALLOWED_HOSTS`. The image
tag `2` stays on 2.0.4.

### Security
- **The web UI only answers to host names a web site can't take over.** A
  page whose own name was made to point at your server (DNS rebinding)
  counted as the web UI itself and passed the cross-site check: it could
  read the lists and logs, change the lists and start downloads. Other names
  now get `403 unknown host name`; `TDLD_ALLOWED_HOSTS` adds names, e.g. for
  a reverse proxy.

### Fixed
- A request with a negative or non-numeric `Content-Length` is answered with
  `400` at once; it used to hold a web UI thread until the client gave up,
  or ended in a traceback.
- A failing start-up step stops the container instead of leaving it running
  without its setup.
- The services run with `HOME=/config` instead of root's home, which they
  can't read.
- The hotfolder's ffmpeg no longer reads from standard input.

### Docs
- The README no longer calls this repository an export of a private one,
  points Unraid users to Community Applications, explains why pip stays in
  the image, and shows how to run the smoke test.

## [2.0.4] - 2026-10-19

### Security
- **The web UI refuses requests from other web sites.** It has no login, so
  any page open in the same browser could rewrite the lists and start
  downloads. Scripts such as `curl` still work.
- **A manual download takes only one `http://` or `https://` address.** A
  value starting with `-` reached yt-dlp as an option; together with a list
  that yt-dlp could be told to read as its configuration, a web page could
  have made it run commands. Every page also says `nosniff` and can't be
  framed by other sites.

### Fixed
- The hotfolder waits until a video hasn't changed for a minute, so a file
  that is still being copied in is no longer converted half-way and moved.

### Changed
- New base image digest (`linuxserver/baseimage-alpine:3.24`).
- A `docker-compose.yml` is in the repository.

## [2.0.3] - 2026-10-17

### Changed
- Images are built and signed in this repository. To verify an image built
  from 2.0.3 on, see the new `cosign verify` command in `SECURITY.md`.
- New base image digest (`linuxserver/baseimage-alpine:3.24`).

## [2.0.2] - 2026-10-04

### Changed
- The container log starts with a TomJoad Images banner instead of the
  base image's "custom build" one.

## [2.0.1] - 2026-10-03

### Changed
- yt-dlp is pinned (`requirements.txt`, now 2026.8.19), so a new release
  arrives as a reviewable Dependabot pull request. `AUTO_UPDATE_YTDLP` still
  updates it at container start.
- The base image is pinned by digest.

### Added
- Images carry an SBOM and provenance, are scanned with Trivy, and the
  repository is scanned with `gitleaks` on every push.

## [2.0.0] - 2026-10-03

Follows the linuxserver.io container conventions. **Needs action when
upgrading**, see "Upgrading from 1.x" in the README.

### Changed
- **Folders:** settings, lists, yt-dlp configs, archives, logs and the
  download script live in `/config`; downloads in `/downloads`; the hotfolder
  in `/hotfolder`. On the first start with the old `/app/data` still mapped,
  lists, yt-dlp configs (paths rewritten) and download archives are copied
  over.
- **User:** `PUID`, `PGID` and `UMASK` set the owner and permissions of new
  files. The documented `UID`/`GID` never had an effect.
- Files are no longer made world-writable: the `chown nobody` and
  `chmod -R 777` on every start are gone, and `/config` belongs to `PUID`.
- Image setup and the services run as s6-rc units (`init-tdld-config`,
  `svc-ytdl`, `svc-webui`, `svc-hotfolder`) instead of `/custom-cont-init.d`
  and `/etc/services.d`, so `/custom-cont-init.d` is free for your own scripts.
- `AUTO_UPDATE_YTDLP` updates yt-dlp once per container start, no longer
  each time the download service restarts.
- The image version comes from the build instead of a hard-coded label.

### Fixed
- Starting without a mapped `/app/data` stopped the setup, and the web UI and
  the download loop failed with `Permission denied` / `No such file`.

### Added
- Image tags `2` and `2.0.0` next to `latest`; images are published only
  from master, branch builds are no longer pushed.
- Unraid template (`unraid/tdld.xml`), security policy, issue templates,
  this changelog and the MIT license file.

## 15.08.2026
- Added `quickjs` JS runtime and a `cookies.txt` placeholder/config wiring to
  work around YouTube's bot-detection ("Sign in to confirm you're not a bot")
  errors.

## 04.07.2026
- Added web UI, hotfolder (multi-format video → mp3 on a timer),
  `AUTO_UPDATE_YTDLP`/`SLEEP_INTERVAL` env vars, and documentation for
  Unraid/Synology.

## 07.05.2022
- Initial release.

[3.2.0]: https://github.com/Tom-Joad/TDLD/compare/v3.1.1...v3.2.0
[3.1.1]: https://github.com/Tom-Joad/TDLD/compare/v3.1.0...v3.1.1
[3.1.0]: https://github.com/Tom-Joad/TDLD/compare/v3.0.6...v3.1.0
[3.0.6]: https://github.com/Tom-Joad/TDLD/compare/v3.0.5...v3.0.6
[3.0.5]: https://github.com/Tom-Joad/TDLD/compare/v3.0.4...v3.0.5
[3.0.4]: https://github.com/Tom-Joad/TDLD/compare/v3.0.3...v3.0.4
[3.0.3]: https://github.com/Tom-Joad/TDLD/compare/v3.0.2...v3.0.3
[3.0.2]: https://github.com/Tom-Joad/TDLD/compare/v3.0.1...v3.0.2
[3.0.1]: https://github.com/Tom-Joad/TDLD/compare/v3.0.0...v3.0.1
[3.0.0]: https://github.com/Tom-Joad/TDLD/compare/f51e227...v3.0.0
[2.0.4]: https://github.com/Tom-Joad/TDLD/compare/e457420...f51e227
[2.0.3]: https://github.com/Tom-Joad/TDLD/compare/b21c71f...e457420
[2.0.2]: https://github.com/Tom-Joad/TDLD/tree/b21c71f
[2.0.0]: https://github.com/Tom-Joad/TDLD/releases/tag/v2.0.0
