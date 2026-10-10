# syntax=docker/dockerfile:1
# linuxserver.io's Alpine base: s6-overlay, PUID/PGID/UMASK/TZ, the abc
# user and docker mods, as in every linuxserver.io container.
# Pinned by digest (a multi-arch index); Dependabot proposes new digests.
FROM ghcr.io/linuxserver/baseimage-alpine:3.24@sha256:f68ac194f40cfe528e5e9549a22623bf4effbfaf93fad834909d2d6c2abd3096

# VERSION and BUILD_DATE are passed in by the build workflow.
ARG BUILD_DATE
ARG VERSION
LABEL build_version="TDLD version: ${VERSION} Build-date: ${BUILD_DATE}"
LABEL maintainer="TomJoad"
LABEL org.opencontainers.image.source="https://github.com/Tom-Joad/TDLD" \
      org.opencontainers.image.title="TDLD" \
      org.opencontainers.image.description="yt-dlp on a timer, with a web UI for the download lists and a video-to-mp3 hotfolder" \
      org.opencontainers.image.licenses="MIT"

RUN \
 apk add --no-cache \
	bash \
	curl \
	py3-pip \
	ffmpeg \
	quickjs

# gcc/g++/make/python3-dev are only needed to build yt-dlp's pip dependencies;
# install them in a virtual apk package so they can be dropped afterwards.
# yt-dlp is pinned in requirements.txt, so a new release arrives as a
# Dependabot pull request; AUTO_UPDATE_YTDLP still updates it at start.
COPY requirements.txt /tmp/requirements.txt
RUN \
 apk add --no-cache --virtual .build-deps \
	gcc \
	g++ \
	make \
	python3-dev \
 && python3 -m pip install --break-system-packages --no-cache-dir -r /tmp/requirements.txt \
 && apk del .build-deps \
 && rm /tmp/requirements.txt

# s6 services (init-tdld-config, svc-ytdl, svc-webui, svc-hotfolder), the
# web UI and hotfolder scripts, and the defaults copied to /config.
COPY root/ /
RUN \
 chmod +x /etc/s6-overlay/s6-rc.d/*/run /defaults/ytdl.sh /app/hotfolder/watch.sh \
 && mkdir -p /config /downloads /hotfolder \
 && printf 'TDLD version: %s\nBuild-date: %s\n' "${VERSION:-unknown}" "${BUILD_DATE:-unknown}" > /build_version

EXPOSE 8083

# Lists, yt-dlp configs, archives, logs and the download script.
VOLUME /config

HEALTHCHECK --interval=30s --timeout=5s --start-period=30s \
    CMD curl -fs http://127.0.0.1:${WEBUI_PORT:-8083}/ || exit 1

# The entrypoint stays the base image's /init (s6-overlay), which must run as
# PID 1: don't add `--init` to `docker run`.
