#!/bin/sh
set -eu

export JAM_JMWALLETD_HOST
export JAM_JMWALLETD_API_PORT
export JAM_JMWALLETD_WEBSOCKET_PORT

# due to `set -u` this fails if variables are not defined
export JAM_JMWALLETD_API_PROXY
JAM_JMWALLETD_API_PROXY="${JAM_JMWALLETD_HOST}:${JAM_JMWALLETD_API_PORT}"
echo "Will proxy requests for /api/* to ${JAM_JMWALLETD_API_PROXY}/api/*"

export JAM_JMWALLETD_WEBSOCKET_PROXY
JAM_JMWALLETD_WEBSOCKET_PROXY="${JAM_JMWALLETD_HOST}:${JAM_JMWALLETD_WEBSOCKET_PORT}"
echo "Will proxy requests for /jmws to ${JAM_JMWALLETD_WEBSOCKET_PROXY}/"

# pass on to the original nginx entry point
exec /docker-entrypoint.sh "$@"
