#!/bin/bash
set -euo pipefail

log() {
    echo -e "[$(date +'%Y-%m-%d %H:%M:%S')] [INFO] $1"
}

err() {
    echo -e "[$(date +'%Y-%m-%d %H:%M:%S')] [ERROR] $1" >&2
}

# Validate input
if [ -z "${1:-}" ]; then
  err "Usage: $0 <PRODUCT_KEY>"
  exit 1
fi

PRODUCT_KEY="$1"
TEMP_DIR=$(mktemp -d)
COOKIE_FILE="$TEMP_DIR/cookie"
FINGERPRINT_FILE="$TEMP_DIR/host_fingerprint.c2v"
LICENSE_FILE="/var/hasplm/license.v2c"

# Cleanup trap: Ensures the temporary directory is deleted upon script exit, even on failure
trap 'rm -rf "$TEMP_DIR"' EXIT

# 1. Check dependencies
command -v hasp_update >/dev/null 2>&1 || { err "hasp_update tool not found."; exit 1; }
command -v curl >/dev/null 2>&1 || { err "curl not found."; exit 1; }
command -v xmllint >/dev/null 2>&1 || { err "libxml2-utils (xmllint) not found."; exit 1; }

# 2. Extract Host Fingerprint
log "Extracting host fingerprint..."
hasp_update i "$FINGERPRINT_FILE" || hasp_update f "$FINGERPRINT_FILE"

if [ ! -s "$FINGERPRINT_FILE" ]; then
  err "Failed to extract host fingerprint."
  exit 1
fi

# 3. EMS Login
log "Connecting to License Server..."
LOGIN_RESPONSE=$(curl -s -i -c "$COOKIE_FILE" --write-out '%{http_code}' --output /dev/null -X POST \
  -H "User-Agent: Vaxtor" \
  "https://licensing.vaxtor.com/ems/v710/ws/loginByProductKey.ws?productKey=$PRODUCT_KEY")

if [ "$LOGIN_RESPONSE" -ne 200 ]; then
  err "Authentication with License Server failed. HTTP Code: $LOGIN_RESPONSE"
  exit 1
fi

# 4. Request Activation
log "Requesting activation..."
ACTIVATION_BODY="<activation>
    <activationInput>
        <activationAttribute>
            <attributeValue><![CDATA[$(cat "$FINGERPRINT_FILE")]]></attributeValue>
            <attributeName>C2V</attributeName>
        </activationAttribute>
        <comments>Activated from Docker Container</comments>
    </activationInput>
</activation>"

ACTIVATION_RESPONSE=$(curl -s -L -b "$COOKIE_FILE" \
  -H "User-Agent: Vaxtor" \
  -H "Content-Type: Application/xml;charset=UTF-8" \
  -d "$ACTIVATION_BODY" \
  "https://licensing.vaxtor.com/ems/v710/ws/productKey/$PRODUCT_KEY/activation.ws")

# 5. Parse XML and save final license
log "Processing activation response..."
xmllint --format - <<< $(xmllint --xpath "string(//activationString)" - <<< "$ACTIVATION_RESPONSE" 2>/dev/null) > "$LICENSE_FILE" 2>/dev/null || true

if [ ! -s "$LICENSE_FILE" ]; then
  err "Could not extract activationString or response is invalid."
  exit 1
fi

# 6. Apply license to local host
log "Applying license file to HASP environment..."
hasp_update u "$LICENSE_FILE"
log "License successfully activated and attached."

# Final cleanup of the processed license file (HASP memory has already absorbed it)
rm -f "$LICENSE_FILE"

exit 0