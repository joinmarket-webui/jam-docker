#!/bin/sh
set -eu

export JMWEBUI_JM_WALLETD_HOST=${JMWEBUI_JM_WALLETD_HOST:-127.0.0.1}
export JMWEBUI_JM_WALLETD_PORT=${JMWEBUI_JM_WALLETD_PORT:-28183}

export JMWEBUI_JM_WALLETD_PROXY="https://${JMWEBUI_JM_WALLETD_HOST}:${JMWEBUI_JM_WALLETD_PORT}"
echo "Will proxy requests for /api/* to ${JMWEBUI_JM_WALLETD_PROXY}/*"

# pass on to the original nginx entry point
exec /docker-entrypoint.sh "$@"
