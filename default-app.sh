#!/bin/bash
set -euo pipefail

log() {
    echo -e "[$(date +'%Y-%m-%d %H:%M:%S')] [INFO] $1"
}

err() {
    echo -e "[$(date +'%Y-%m-%d %H:%M:%S')] [ERROR] $1" >&2
}

echo -e "\n"
log "=== Starting Vaxtor GENESIS Application ==="
echo -e "\n"

DEBUG_MODE="${DEBUG:-false}"

if [ "${DEBUG_MODE,,}" = "true" ]; then
    log "Running in DEBUG mode..."
    exec vaxtorgenesis -console -debug
else
    log "Running in standard console mode..."
    exec vaxtorgenesis -console
fi
