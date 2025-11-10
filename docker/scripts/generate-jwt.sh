#!/bin/bash
# Generate GitHub App JWT token
set -euo pipefail

if [ $# -lt 2 ]; then
    echo "Usage: $0 <app-id> <private-key-path>"
    exit 1
fi

APP_ID="$1"
PRIVATE_KEY_PATH="$2"

if [ ! -f "${PRIVATE_KEY_PATH}" ]; then
    echo "ERROR: Private key file not found: ${PRIVATE_KEY_PATH}" >&2
    exit 1
fi

# Generate JWT
now=$(date +%s)
iat=$((now - 60))
exp=$((now + 600))

header='{"alg":"RS256","typ":"JWT"}'
payload="{\"iat\":${iat},\"exp\":${exp},\"iss\":\"${APP_ID}\"}"

b64_header=$(echo -n "${header}" | openssl base64 -e -A | tr '+/' '-_' | tr -d '=')
b64_payload=$(echo -n "${payload}" | openssl base64 -e -A | tr '+/' '-_' | tr -d '=')

signature=$(echo -n "${b64_header}.${b64_payload}" | \
    openssl dgst -sha256 -sign "${PRIVATE_KEY_PATH}" | \
    openssl base64 -e -A | tr '+/' '-_' | tr -d '=')

jwt="${b64_header}.${b64_payload}.${signature}"

echo "${jwt}"
