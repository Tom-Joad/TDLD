# Security policy

## Supported versions

Only the latest image (`ghcr.io/tom-joad/tdld:latest`) receives fixes.

## Reporting a vulnerability

Please do **not** open a public issue for security problems. Report them
privately through GitHub instead: on the
[Security tab](https://github.com/Tom-Joad/TDLD/security),
choose **Report a vulnerability**. You will get an answer within a few days.

## Scope notes

Of particular interest:

- the web UI (port 8083, no login): anything that lets a request read or
  write files outside the lists and logs, or run commands other than the
  configured yt-dlp download
- cookies from `/config/ytdlpconfig/cookies.txt` ending up in logs or the image
- files written with broader permissions or a different owner than
  `PUID`/`PGID`/`UMASK` allow

The services run as the unprivileged user `abc`; only the start-up setup in
`init-tdld-config` runs as root.

## Supply chain

Images are built by GitHub Actions for amd64 and arm64 and signed keylessly
with cosign. To verify an image:

```bash
cosign verify ghcr.io/tom-joad/tdld:latest \
  --certificate-identity-regexp 'https://github.com/Tom-Joad/ytdldocker/' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```
