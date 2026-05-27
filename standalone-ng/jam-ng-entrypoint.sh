#!/bin/bash
#
# jam-ng entrypoint
#
# joinmarket-ng reads its configuration from environment variables (highest
# priority) and from a TOML file (~/.joinmarket-ng/config.toml or
# $JOINMARKET_DATA_DIR/config.toml). Env vars use the SECTION__KEY convention
# (double underscore), e.g. BITCOIN__RPC_URL, NETWORK_CONFIG__NETWORK,
# TAKER__MAX_CJ_FEE_ABS.
#
# This entrypoint does NOT generate config.toml. If you need to customize
# anything beyond what env vars cover, mount your own config.toml into
# $JOINMARKET_DATA_DIR/config.toml.
#
# See:
#   https://github.com/joinmarket-ng/joinmarket-ng/blob/main/jmcore/src/jmcore/data/config.toml.template
#   https://github.com/joinmarket-ng/joinmarket-ng/blob/main/jmcore/src/jmcore/settings.py
set -e

# DATADIR is kept for backwards compatibility with legacy standalone users.
# joinmarket-ng reads JOINMARKET_DATA_DIR; the Dockerfile sets both to the
# same default so they stay in sync unless explicitly overridden.
DATADIR=${JOINMARKET_DATA_DIR:-${DATADIR:-/root/.joinmarket-ng}}
export JOINMARKET_DATA_DIR="$DATADIR"

# ensure joinmarket-ng data directory exists
mkdir --parents "$DATADIR"

# ensure log directory structure exists
mkdir --parents /var/log/jam-ng/jmwalletd
mkdir --parents /var/log/jam-ng/obwatcher
mkdir --parents /var/log/jam-ng/tor

# optional: remove leftover wallet lockfiles from unclean shutdowns
if [ "${REMOVE_LOCK_FILES}" = "true" ]; then
    echo "Removing leftover wallet lockfiles before startup..."
    rm --force --verbose "${DATADIR}"/wallets/.*.jmdat.lock || true
fi

# basic authentication for the nginx-served UI
if [ -n "${APP_USER}" ]; then
    BASIC_AUTH_USER=${APP_USER:?APP_USER empty or unset}
    BASIC_AUTH_PASS=${APP_PASSWORD:?APP_PASSWORD empty or unset}

    echo "${BASIC_AUTH_USER}:$(openssl passwd -apr1 "${BASIC_AUTH_PASS}")" > /etc/nginx/.htpasswd
    sed -i 's/auth_basic off;/auth_basic "JoinMarket WebUI";/g' /etc/nginx/conf.d/default.conf
fi

# nginx listen port override
if [ -n "${JAM_UI_PORT##*[!0-9]*}" ]; then
    echo "UI will be served on port ${JAM_UI_PORT}."
    sed -i "s/listen 80;/listen ${JAM_UI_PORT};/g" /etc/nginx/conf.d/default.conf
    sed -i "s/listen \[::\]:80;/listen [::]:${JAM_UI_PORT};/g" /etc/nginx/conf.d/default.conf
fi

# wait for a ready file before starting services (e.g. chain sync gate)
if [ "${READY_FILE}" ] && [ "${READY_FILE}" != "false" ]; then
    echo "Waiting for file $READY_FILE to be created..."
    while [ ! -f "$READY_FILE" ]; do sleep 1; done
    echo "Successfully waited for file $READY_FILE to be created."
fi

# Bitcoin RPC wait and optional wallet management.
#
# Configuration is read from env vars (canonical joinmarket-ng convention)
# with sensible fallbacks. Unlike the legacy standalone wrapper, no values
# are read out of config.toml because the entrypoint does not generate one.
#
#   BITCOIN__RPC_URL=http://host:port      (preferred)
#   BITCOIN__RPC_USER, BITCOIN__RPC_PASSWORD
#   BITCOIN__RPC_COOKIE_FILE               (alternative to user/password)
#
# If BITCOIN__RPC_URL is unset, the bitcoind wait and wallet management are
# skipped silently (jmwalletd will still start; it will simply fail later if
# it cannot reach Bitcoin Core, which is the user's responsibility to fix).
rpc_url="${BITCOIN__RPC_URL:-}"
rpc_user="${BITCOIN__RPC_USER:-}"
rpc_password="${BITCOIN__RPC_PASSWORD:-}"
rpc_cookie_file="${BITCOIN__RPC_COOKIE_FILE:-}"

if [ -n "${rpc_url}" ]; then
    # parse host and port from rpc_url (http[s]://host:port[/path])
    rpc_host=$(printf '%s' "${rpc_url}" | sed -E 's|^https?://||; s|/.*$||; s|:[0-9]+$||')
    rpc_port=$(printf '%s' "${rpc_url}" | sed -E 's|^https?://||; s|/.*$||; s|^[^:]*:||')

    btccli_base=(bitcoin-cli "-rpcconnect=${rpc_host}" "-rpcport=${rpc_port}")
    if [ -n "${rpc_cookie_file}" ]; then
        btccli_base+=("-rpccookiefile=${rpc_cookie_file}")
    elif [ -n "${rpc_user}" ]; then
        btccli_base+=("-rpcuser=${rpc_user}" "-rpcpassword=${rpc_password}")
    fi

    if [ "${WAIT_FOR_BITCOIND}" != "false" ]; then
        echo "Waiting for bitcoind at ${rpc_url} to accept RPC requests..."
        # generally a non-error response would be enough, but waiting for
        # blocks >= 100 is also needed for regtest environments.
        until blocks=$("${btccli_base[@]}" getblockchaininfo 2>/dev/null \
                | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['blocks'])" 2>/dev/null) \
            && [ -n "${blocks}" ] && [ "${blocks}" -ge 100 ] 2>/dev/null
        do
            sleep 5
        done
        echo "Successfully waited for bitcoind to accept RPC requests."
    fi

    if [ "${ENSURE_WALLET}" = "true" ]; then
        wallet_name="${BITCOIN__RPC_WALLET_FILE:-jam}"
        echo "Creating wallet ${wallet_name} if missing..."
        "${btccli_base[@]}" createwallet "${wallet_name}" false false "" false false true > /dev/null 2>&1 || true
        echo "Loading wallet ${wallet_name}..."
        "${btccli_base[@]}" loadwallet "${wallet_name}" true > /dev/null 2>&1 || true
    fi
else
    if [ "${WAIT_FOR_BITCOIND}" != "false" ] || [ "${ENSURE_WALLET}" = "true" ]; then
        echo "BITCOIN__RPC_URL is not set; skipping bitcoind wait and wallet management."
    fi
fi

# shellcheck source=/dev/null
source /opt/venv/bin/activate

exec /init
