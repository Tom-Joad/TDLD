# Changelog

All notable changes to this project are listed here. A change that needs
action when upgrading (a renamed or removed setting, a different folder
layout) only comes with a new major version.

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
