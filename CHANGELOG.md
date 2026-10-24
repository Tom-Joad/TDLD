# Changelog

All notable changes to this project are listed here. Versions follow
[semantic versioning](https://semver.org/). A change that needs action when
upgrading (a renamed or removed setting, a different folder layout) only
comes with a new major version.

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

[3.0.1]: https://github.com/Tom-Joad/TDLD/compare/v3.0.0...v3.0.1
[3.0.0]: https://github.com/Tom-Joad/TDLD/compare/v2.0.0...v3.0.0
