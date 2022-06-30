#!/bin/sh
set -eu

export JMWEBUI_JMWALLETD_HOST
export JMWEBUI_JMWALLETD_API_PORT
export JMWEBUI_JMWALLETD_WEBSOCKET_PORT

# due to `set -u` this fails if variables are not defined
export JMWEBUI_JMWALLETD_API_PROXY
JMWEBUI_JMWALLETD_API_PROXY="${JMWEBUI_JMWALLETD_HOST}:${JMWEBUI_JMWALLETD_API_PORT}"
echo "Will proxy requests for /api/* to ${JMWEBUI_JMWALLETD_API_PROXY}/api/*"

export JMWEBUI_JMWALLETD_WEBSOCKET_PROXY
JMWEBUI_JMWALLETD_WEBSOCKET_PROXY="${JMWEBUI_JMWALLETD_HOST}:${JMWEBUI_JMWALLETD_WEBSOCKET_PORT}"
echo "Will proxy requests for /jmws to ${JMWEBUI_JMWALLETD_WEBSOCKET_PROXY}/"

# pass on to the original nginx entry point
exec /docker-entrypoint.sh "$@"
