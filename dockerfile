# syntax=docker/dockerfile:1
FROM ghcr.io/linuxserver/baseimage-alpine:3.24

# set version label
ARG BUILD_DATE
ARG VERSION
ARG CODE_RELEASE
LABEL build_version="git.reimold.xyz version: 1.6 Build-date: 04.07.2026"
LABEL maintainer="TomJoad"
LABEL description="TJs ytdl "

RUN \
 apk add --no-cache \
	bash \
	curl \
	py3-pip \
	ffmpeg

# gcc/g++/make/python3-dev are only needed to build yt-dlp's pip dependencies;
# install them in a virtual apk package so they can be dropped afterwards.
RUN \
 apk add --no-cache --virtual .build-deps \
	gcc \
	g++ \
	make \
	python3-dev \
 && python3 -m pip install --break-system-packages -U "yt-dlp[default]" \
 && apk del .build-deps

# make folderstructure
RUN mkdir -p /app/scripts

# copy sourcefiles / prepopulate container
COPY sourcefiles/scripts/ytdl.sh /tmp/ytdl.sh
COPY sourcefiles/scripts/s6scripts/populatevolume.sh /custom-cont-init.d/populatevolume.sh
COPY sourcefiles/tmp/ytdlpconfig/audioonly.config /tmp/ytdlpconfig/audioonly.config
COPY sourcefiles/tmp/ytdlpconfig/channels.config /tmp/ytdlpconfig/channels.config
COPY sourcefiles/tmp/ytdlpconfig/playlists.config /tmp/ytdlpconfig/playlists.config
COPY sourcefiles/scripts/s6scripts/services.d/ytdl/run /etc/services.d/ytdl/run

# simple web UI for editing the download lists
COPY webui/server.py /app/scripts/webui/server.py
COPY services.d/webui/run /etc/services.d/webui/run

# hotfolder: drop an mp4 in, get an mp3 extracted via ffmpeg
COPY hotfolder/watch.sh /app/scripts/hotfolder/watch.sh
COPY services.d/hotfolder/run /etc/services.d/hotfolder/run

RUN \
 chmod +x /custom-cont-init.d/populatevolume.sh /tmp/ytdl.sh /app/scripts/hotfolder/watch.sh \
 && chmod -R 755 /etc/services.d/ytdl /etc/services.d/webui /etc/services.d/hotfolder

EXPOSE 8083

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s \
    CMD curl -fs http://127.0.0.1:8083/ || exit 1

#VOLUME /config