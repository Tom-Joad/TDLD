# Running TDLD on Unraid

The container runs permanently: it works through the download lists on a timer and has a web UI
on port `8083` for the lists, single downloads and the logs.

## Install

1. **Add the template.** The easy way is Community Applications: search for `tdld` under
   **Apps**. Without Community Applications, copy `tdld.xml` to
   `/boot/config/plugins/dockerMan/templates-user/` on the flash drive. Then, in the Unraid web
   UI, go to **Docker → Add Container** and pick `tdld` from the template dropdown.

2. **Fill in the settings.**

   | Setting | Value |
   |---|---|
   | Web UI | `8083`; the web UI has no login, so don't expose it to the internet |
   | Config | `/mnt/user/appdata/tdld`: lists, yt-dlp configs, cookies, archives, logs |
   | Downloads | a media share, e.g. `/mnt/user/media/youtube`, rather than appdata |
   | Hotfolder | optional, e.g. `/mnt/user/media/hotfolder`; leave empty if you don't convert videos to mp3 |
   | `PUID`, `PGID` | `99`, `100` (nobody:users) |
   | `UMASK` | `002`, so new files are writable for the `users` group, e.g. over SMB |
   | `SLEEP_INTERVAL` | seconds between download-list runs, default `3600` |
   | `AUTO_UPDATE_YTDLP` | `true` updates yt-dlp at every start instead of waiting for a new image |

   The advanced view has `TDLD_ALLOWED_HOSTS` (needed only behind a reverse proxy, see the
   [main README](../README.md#web-ui)) and `HOTFOLDER_INTERVAL`. Don't add `--user` to
   *Extra Parameters*: the container sets the user from `PUID`/`PGID` itself.

3. **Apply.** The log shows `TDLD <version> starting` with the settings, then the first run.
   Open the web UI from the container's icon in the **Docker** tab.

## YouTube cookies

YouTube often asks downloads to "sign in to confirm you're not a bot". Put exported browser
cookies into `/mnt/user/appdata/tdld/ytdlpconfig/cookies.txt`; the
[main README](../README.md#youtube-sign-in-to-confirm-youre-not-a-bot) explains how to export them.

## Updating

Unraid updates the container like any other (**Docker → Check for Updates**, or automatically
with the CA Auto Update plugin). Lists, configs and archives in `/config` are kept; a
`ytdl.sh` you edited in `/config/scripts` is never replaced. Before a major version, read
[Upgrading](../README.md#upgrading) in the main README.
