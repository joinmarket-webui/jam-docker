#!/bin/sh
set -eu

export JMWEBUI_JM_WALLETD_HOST
export JMWEBUI_JM_WALLETD_PORT

# due to `set -u` this would fail if variables are not defined
export JMWEBUI_JM_WALLETD_PROXY="https://${JMWEBUI_JM_WALLETD_HOST}:${JMWEBUI_JM_WALLETD_PORT}"
echo "Will proxy requests for /api/* to ${JMWEBUI_JM_WALLETD_PROXY}/*"

# pass on to the original nginx entry point
exec /docker-entrypoint.sh "$@"
