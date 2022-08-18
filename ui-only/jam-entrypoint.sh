#!/bin/sh
set -eu

export JAM_JMWALLETD_HOST
export JAM_JMWALLETD_API_PORT
export JAM_JMWALLETD_WEBSOCKET_PORT
export JAM_JMOBWATCH_PORT

# due to `set -u` this fails if variables are not defined
export JAM_JMWALLETD_API_PROXY
JAM_JMWALLETD_API_PROXY="${JAM_JMWALLETD_HOST}:${JAM_JMWALLETD_API_PORT}"
echo "Will proxy requests for /api/* to ${JAM_JMWALLETD_API_PROXY}/api/*"

export JAM_JMWALLETD_WEBSOCKET_PROXY
JAM_JMWALLETD_WEBSOCKET_PROXY="${JAM_JMWALLETD_HOST}:${JAM_JMWALLETD_WEBSOCKET_PORT}"
echo "Will proxy requests for /jmws to ${JAM_JMWALLETD_WEBSOCKET_PROXY}/"

export JAM_JMOBWATCH_PROXY
JAM_JMOBWATCH_PROXY="${JAM_JMWALLETD_HOST}:${JAM_JMOBWATCH_PORT}"
echo "Will proxy requests for /obwatch/* to ${JAM_JMOBWATCH_PROXY}/"

# pass on to the original nginx entry point
exec /docker-entrypoint.sh "$@"
