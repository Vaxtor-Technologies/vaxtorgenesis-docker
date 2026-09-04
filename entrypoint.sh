#!/bin/bash
set -euo pipefail

log() {
    echo -e "[$(date +'%Y-%m-%d %H:%M:%S')] [INFO] $1"
}

err() {
    echo -e "[$(date +'%Y-%m-%d %H:%M:%S')] [ERROR] $1" >&2
}

update_hasplm_ini() {
    local ini_file="/etc/hasplm/hasplm.ini"
    local ip_addr="$1"

    mkdir -p "$(dirname "$ini_file")"

    if [ ! -f "$ini_file" ]; then
        log "Creating new hasplm.ini with [REMOTE] section..."
        echo "[REMOTE]" > "$ini_file"
        echo "serveraddr = $ip_addr" >> "$ini_file"
        return
    fi

    if ! grep -q "^\[REMOTE\]" "$ini_file"; then
        log "Appending [REMOTE] section to existing hasplm.ini..."
        echo "" >> "$ini_file"
        echo "[REMOTE]" >> "$ini_file"
        echo "serveraddr = $ip_addr" >> "$ini_file"
        return
    fi

    if grep -q "^[[:space:]]*serveraddr[[:space:]]*=" "$ini_file"; then
        log "Updating existing serveraddr in hasplm.ini..."
        sed -i "s/^[[:space:]]*serveraddr[[:space:]]*=.*/serveraddr = $ip_addr/" "$ini_file"
    else
        log "Injecting serveraddr into existing [REMOTE] section..."
        sed -i "s/^\[REMOTE\]/\[REMOTE\]\nserveraddr = $ip_addr/" "$ini_file"
    fi
}

start_hasp_daemon() {
    log "Starting local HASP daemon..."
    /usr/sbin/hasplmd -s

    local max_wait=15
    local counter=0

    log "Waiting for HASP daemon to be ready on port 1947..."
    while ! curl -s --output /dev/null http://127.0.0.1:1947; do
        sleep 1
        counter=$((counter + 1))
        
        if [ "$counter" -ge "$max_wait" ]; then
            err "Local HASP daemon failed to bind port 1947 within ${max_wait} seconds."
            exit 1
        fi
    done
    log "HASP daemon is ready."
}


log "=== Initializing Vaxtor GENESIS ($(uname -m) Environment) ==="

# 1. Prepare HASP directory and copy libraries
mkdir -p /var/hasplm/update
cp -n /opt/hasp_libs/*.so /var/hasplm/update/ 2>/dev/null || true

# 2. PRE-DAEMON PHASE: Check network license
if [ -n "${LICENSE_SERVER_ADDR:-}" ]; then
    log "Network License parameter detected: $LICENSE_SERVER_ADDR"
    update_hasplm_ini "$LICENSE_SERVER_ADDR"
fi

# 3. DAEMON PHASE: Start the service (common and required for all cases)
start_hasp_daemon

# 4. POST-DAEMON PHASE: Check local activation if no network is provided
if [ -z "${LICENSE_SERVER_ADDR:-}" ]; then
    if [ -n "${PRODUCT_KEY:-}" ]; then
        log "No Network License provided. Operating in Local License mode."
        
        shopt -s nullglob
        lic_files=(/var/hasplm/installed/97461/*_base.v2c)
        if [ ${#lic_files[@]} -eq 0 ]; then
            log "Activating license with provided Product Key..."
            if [ -f /root/activate.sh ]; then
                /root/activate.sh "$PRODUCT_KEY"
            else
                err "Activation script /root/activate.sh not found!"
                exit 1
            fi
        else
            log "Local license found. Skipping activation."
        fi
        shopt -u nullglob
    else
        log "No license parameters (LICENSE_SERVER_ADDR or PRODUCT_KEY) provided. Continuing default execution..."
    fi
fi

log "Handing over control to the main application..."

# 5. Hand over control to the main process (PID 1)
exec "$@"