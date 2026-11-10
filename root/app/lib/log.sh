# shellcheck shell=bash
# Log helpers shared by the init step, the download script and the hotfolder.
# Lines look like "[2026-11-10 12:00:00] [ytdl] message"; errors start with
# "ERROR: ", warnings with "WARNING: ". The time is in the container's TZ.

log() { # tag message...
    local tag=$1; shift
    printf '[%(%Y-%m-%d %H:%M:%S)T] [%s] %s\n' -1 "$tag" "$*"
}
log_warn() { local tag=$1; shift; log "$tag" "WARNING: $*"; }
log_error() { local tag=$1; shift; log "$tag" "ERROR: $*"; }

# Logs every line read from stdin, e.g. the output of a program.
log_pipe() { # tag
    local line
    while IFS= read -r line || [[ -n $line ]]; do
        log "$1" "$line"
    done
}
