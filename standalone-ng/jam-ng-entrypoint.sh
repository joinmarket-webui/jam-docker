#!/bin/bash
set -e

DATADIR=${DATADIR:-/root/.joinmarket-ng}

# ensure joinmarket-ng data directory exists
mkdir --parents "$DATADIR"

# ensure log directory structure exists
mkdir --parents /var/log/jam-ng/jmwalletd
mkdir --parents /var/log/jam-ng/obwatcher
mkdir --parents /var/log/jam-ng/tor

# config.toml generation
CONFIG_FILE="${DATADIR}/config.toml"

if [ ! -f "$CONFIG_FILE" ] || [ "${RESTORE_DEFAULT_CONFIG}" = "true" ]; then
    echo "Generating default config.toml..."
    
    cat > "$CONFIG_FILE" << 'EOF'
[blockchain]
network = "testnet"
blockchain_source = "bitcoin-core"
rpc_host = "127.0.0.1"
rpc_port = 18332
rpc_user = "user"
rpc_password = "password"
# rpc_cookie_file = ""

[coinjoin]
max_cj_fee_abs = 7500
max_cj_fee_rel = 0.0002
EOF
    
    echo "Default config.toml created at $CONFIG_FILE"
else
    echo "config.toml already exists at $CONFIG_FILE"
fi

# environment variable mapping: map JMNG_* env vars to config.toml
declare -A jmngenv
while IFS='=' read -r -d '' envkey parsedval; do
    n="${envkey,,}" # lowercase
    if [[ "$n" = jmng_* ]]; then
        n="${n:5}" # drop jmng_
        jmngenv[$n]="${!envkey}" # reread environment variable - characters might have been dropped (e.g. 'ending in =')
    fi
done < <(env -0)

# determine blockchain_source before network conversion
# adapt 'blockchain_source' if missing and we're in regtest mode
if [ "${jmngenv['network']}" = "regtest" ] && [ -z "${jmngenv['blockchain_source']}" ]; then
    jmngenv['blockchain_source']='regtest'
fi

# there is no 'regtest' value for config 'network': make sure to use "testnet" in regtest mode
if [ "${jmngenv['network']}" = "regtest" ]; then
    jmngenv['network']='testnet'
fi

# make sure `max_cj_fee_abs` and `max_cj_fee_rel` are set
# `max_cj_fee_abs` between 5000 - 10000 sats if not provided
jmngenv['max_cj_fee_abs']=${jmngenv['max_cj_fee_abs']:-"$(shuf -i 5000-10000 -n1)"}
# `max_cj_fee_rel` between 0.01 - 0.03% if not provided
jmngenv['max_cj_fee_rel']=${jmngenv['max_cj_fee_rel']:-"0.000$((RANDOM%3+1))"}

# for every env variable JMNG_FOO=BAR, replace the config.toml value of 'foo' by 'BAR'
# config.toml uses TOML format: key = "value" (quoted strings) or key = number/bool
# Note: this mapping is not section-aware. All JMNG_* keys must be unique across sections.
# Keys that appear in multiple sections (e.g. 'port') should not be set via env vars;
# use RESTORE_DEFAULT_CONFIG=true and mount a custom config.toml instead.
toml_escape() {
    printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'
}

toml_set() {
    local key="$1"
    local val="$2"
    local replace_val

    if [[ "$val" =~ ^-?[0-9]+([.][0-9]+)?$ ]] || [[ "$val" == "true" || "$val" == "false" ]]; then
        replace_val="$val"
    else
        replace_val="\"$(toml_escape "$val")\""
    fi

    if grep -Eq "^# $key = |^$key = " "$CONFIG_FILE"; then
        # uncomment the key if it is commented out (e.g. # rpc_cookie_file = "")
        sed -i "s|^# $key = .*|$key = $replace_val|g" "$CONFIG_FILE"
        # replace existing key = "..." or key = number/bool
        sed -i "s|^$key = .*|$key = $replace_val|g" "$CONFIG_FILE"
    else
        echo "Warning: key '$key' not found in $CONFIG_FILE, skipping (set JMNG_${key^^} has no effect)"
    fi
}

for key in "${!jmngenv[@]}"; do
    toml_set "$key" "${jmngenv[${key}]}"
done

# RPC authentication: handle cookie file vs user/password
if [ -n "${jmngenv['rpc_cookie_file']}" ]; then
    echo "Using RPC cookie authentication with file: ${jmngenv['rpc_cookie_file']}"
    # using cookie auth, comment out user/password
    sed -i 's|^rpc_user = .*|# rpc_user = ""|g' "$CONFIG_FILE"
    sed -i 's|^rpc_password = .*|# rpc_password = ""|g' "$CONFIG_FILE"
else
    echo "Using RPC user/password authentication"
    # using user/password auth, comment out cookie file
    sed -i 's|^rpc_cookie_file = .*|# rpc_cookie_file = ""|g' "$CONFIG_FILE"
fi

# optional features

# remove leftover lockfiles from possible unclean shutdowns before startup
if [ "${REMOVE_LOCK_FILES}" = "true" ]; then
    echo "Remove leftover wallet lockfiles before startup..."
    rm --force --verbose "${DATADIR}"/wallets/.*.jmdat.lock
fi

# setup basic authentication
if [ -n "${APP_USER}" ]; then
    BASIC_AUTH_USER=${APP_USER:?APP_USER empty or unset}
    BASIC_AUTH_PASS=${APP_PASSWORD:?APP_PASSWORD empty or unset}

    echo "${BASIC_AUTH_USER}:$(openssl passwd -apr1 "${BASIC_AUTH_PASS}")" > /etc/nginx/.htpasswd
    sed -i 's/auth_basic off;/auth_basic "JoinMarket WebUI";/g' /etc/nginx/conf.d/default.conf
fi

# configure nginx listen port
if [ -n "${JAM_UI_PORT##*[!0-9]*}" ]; then
    echo "UI will be served on port ${JAM_UI_PORT}."
    sed -i "s/listen 80;/listen ${JAM_UI_PORT};/g" /etc/nginx/conf.d/default.conf
    sed -i "s/listen \[::\]:80;/listen [::]:${JAM_UI_PORT};/g" /etc/nginx/conf.d/default.conf
fi

# wait for a ready file to be created if necessary
if [ "${READY_FILE}" ] && [ "${READY_FILE}" != "false" ]; then
    echo "Waiting for file $READY_FILE to be created..."
    while [ ! -f "$READY_FILE" ]; do sleep 1; done
    echo "Successfully waited for file $READY_FILE to be created."
fi

# Bitcoin RPC wait and wallet management

# read RPC connection details from config.toml
rpc_host=$(sed -n 's/^rpc_host = "\(.*\)"/\1/p' "$CONFIG_FILE")
rpc_port=$(sed -n 's/^rpc_port = \(.*\)/\1/p' "$CONFIG_FILE")
rpc_cookie_file=$(sed -n 's/^rpc_cookie_file = "\(.*\)"/\1/p' "$CONFIG_FILE")
rpc_user=$(sed -n 's/^rpc_user = "\(.*\)"/\1/p' "$CONFIG_FILE")
rpc_password=$(sed -n 's/^rpc_password = "\(.*\)"/\1/p' "$CONFIG_FILE")

# build bitcoin-cli base command with RPC connection flags
btccli_base=(bitcoin-cli "-rpcconnect=${rpc_host}" "-rpcport=${rpc_port}")
if [ -n "${rpc_cookie_file}" ]; then
    btccli_base+=("-rpccookiefile=${rpc_cookie_file}")
else
    btccli_base+=("-rpcuser=${rpc_user}" "-rpcpassword=${rpc_password}")
fi

# wait for bitcoind to accept RPC requests if necessary
if [ "${WAIT_FOR_BITCOIND}" != "false" ]; then
    echo "Waiting for bitcoind to accept RPC requests..."
    # use `getblockchaininfo` command here, as this is the first request JM is
    # performing during initialization
    # generally only testing for a non-error response would be enough, but
    # waiting for blocks >= 100 is needed for regtest environments as well!
    until blocks=$("${btccli_base[@]}" getblockchaininfo 2>/dev/null | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['blocks'])" 2>/dev/null) \
        && [ -n "${blocks}" ] && [ "${blocks}" -ge 100 ] 2>/dev/null
    do
        sleep 5
    done
    echo "Successfully waited for bitcoind to accept RPC requests."
fi

# ensure that a wallet exists and is loaded if necessary
if [ "${ENSURE_WALLET}" = "true" ]; then
    wallet_name="jam"

    echo "Creating wallet ${wallet_name} if missing..."
    "${btccli_base[@]}" createwallet "${wallet_name}" false false "" false false true > /dev/null 2>&1 || true

    echo "Loading wallet ${wallet_name}..."
    "${btccli_base[@]}" loadwallet "${wallet_name}" true > /dev/null 2>&1 || true
fi

# shellcheck source=/dev/null
source /opt/venv/bin/activate

exec /init
