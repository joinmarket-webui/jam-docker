#!/bin/bash
set -e

# ensure jm working directory exists
mkdir --parents "${DATADIR}/"

# ensure log directory exists
mkdir --parents /var/log/jam

# restore the default config
if [ ! -f "$CONFIG" ] || [ "${RESTORE_DEFAULT_CONFIG}" = "true" ]; then
    cp --force "$DEFAULT_CONFIG" "$CONFIG"
fi

# remove leftover lockfiles from possible unclean shutdowns before startup
if [ "${REMOVE_LOCK_FILES}" = "true" ]; then
    echo "Remove leftover wallet lockfiles before startup..."
    rm --force --verbose "${DATADIR}"/wallets/.*.jmdat.lock
fi

# setup basic authentication
if [ -n "${APP_USER}" ]; then
    BASIC_AUTH_USER=${APP_USER:?APP_USER empty or unset}
    BASIC_AUTH_PASS=${APP_PASSWORD:?APP_PASSWORD empty or unset}

    echo -e "${BASIC_AUTH_USER}:$(openssl passwd -quiet -6 <<< echo "${BASIC_AUTH_PASS}")\n" > /etc/nginx/.htpasswd
    sed -i 's/auth_basic off;/auth_basic "JoinMarket WebUI";/g' /etc/nginx/conf.d/default.conf
fi

if [ -n "${JAM_UI_PORT##*[!0-9]*}" ]; then
    echo "UI will be served on port ${JAM_UI_PORT}."
    sed -i "s/listen 80;/listen ${JAM_UI_PORT};/g" /etc/nginx/conf.d/default.conf
    sed -i "s/listen [::]:80;/listen [::]:${JAM_UI_PORT};/g" /etc/nginx/conf.d/default.conf
fi

# generate ssl certificates for jmwalletd
if [ ! -f "${DATADIR}/ssl/key.pem" ]; then
    subj="/C=US/ST=Utah/L=Lehi/O=Your Company, Inc./OU=IT/CN=example.com"
    mkdir --parents "${DATADIR}/ssl/" \
      && pushd "$_" \
      && openssl req -newkey rsa:4096 -x509 -sha256 -days 3650 -nodes -out cert.pem -keyout key.pem -subj "$subj" \
      && popd
fi

declare -A jmenv
while IFS='=' read -r -d '' envkey parsedval; do
    n="${envkey,,}" # lowercase
    if [[ "$n" =  jm_* ]]; then
        n="${n:3}" # drop jm_
        jmenv[$n]="${!envkey}" # reread environment variable - characters might have been dropped (e.g 'ending in =')
    fi
done < <(env -0)

# ensure a wallet name is present
jmenv['rpc_wallet_file']=${jmenv['rpc_wallet_file']:-'jm_webui_default'}

# make sure `max_cj_fee_abs` and `max_cj_fee_rel` are set
# `max_cj_fee_abs` between 5000 - 10000 sats if not provided
jmenv['max_cj_fee_abs']=${jmenv['max_cj_fee_abs']:-"$(shuf -i 5000-10000 -n1)"}
# `max_cj_fee_rel` between 0.01 - 0.03% if not provided
jmenv['max_cj_fee_rel']=${jmenv['max_cj_fee_rel']:-"0.000$((RANDOM%3+1))"}

# adapt 'blockchain_source' if missing and we're in regtest mode
if [ "${jmenv['network']}" = "regtest" ] && [ "${jmenv['blockchain_source']}" = "" ]; then
    jmenv['blockchain_source']='regtest'
fi

# there is no 'regtest' value for config 'network': make sure to use "testnet" in regtest mode
if [ "${jmenv['network']}" = "regtest" ]; then
    jmenv['network']='testnet'
fi

# for every env variable JM_FOO=BAR, replace the default configuration value of 'foo' by 'BAR'
for key in "${!jmenv[@]}"; do
    val="${jmenv[${key}]}"
    sed -i "s/^#$key =/$key =/g" "$CONFIG"
    sed -i "s|^$key =.*|$key = $val|g" "$CONFIG" || echo "Couldn't set : $key = $val, please modify $CONFIG manually"
done

# wait for a ready file to be created if necessary
if [ "${READY_FILE}" ] && [ "${READY_FILE}" != "false" ]; then
    echo "Waiting for file $READY_FILE to be created..."
    while [ ! -f "$READY_FILE" ]; do sleep 1; done
    echo "Successfully waited for file $READY_FILE to be created."
fi

btchost="http://${jmenv['rpc_host']}:${jmenv['rpc_port']}"

# determine RPC authentication method
if [ -n "${jmenv['rpc_cookie_file']}" ]; then
    echo "Using RPC cookie authentication with file: ${jmenv['rpc_cookie_file']}"
    btcuser=$(cat "${jmenv['rpc_cookie_file']}")
    # using cookie auth, comment out user/password
    sed -i 's/^rpc_user =/#rpc_user =/g' "$CONFIG"
    sed -i 's/^rpc_password =/#rpc_password =/g' "$CONFIG"
else
    echo "Using RPC user/password authentication"
    btcuser="${jmenv['rpc_user']}:${jmenv['rpc_password']}"
    # using user/password auth, comment out cookie file
    sed -i 's/^rpc_cookie_file =/#rpc_cookie_file =/g' "$CONFIG"
fi

# wait for bitcoind to accept RPC requests if necessary
if [ "${WAIT_FOR_BITCOIND}" != "false" ]; then
    echo "Waiting for bitcoind to accept RPC requests..."
    # use `getblockchaininfo` command here, as this is the first request JM is
    # performing during initialization
    getblockchaininfo_payload="{\
        \"jsonrpc\":\"2.0\",\
        \"id\":\"curl\",\
        \"method\":\"getblockchaininfo\",\
        \"params\":{}\
    }"
    # generally only testing for a non-error response would be enough, but 
    # waiting for blocks >= 100 is needed for regtest environments as well!
    until curl --silent --show-error --user "${btcuser}" --data-binary "${getblockchaininfo_payload}" "${btchost}" 2>&1 | jq -e ".result.blocks >= 100" > /dev/null 2>&1
    do
        sleep 5
    done
    echo "Successfully waited for bitcoind to accept RPC requests."
fi

# ensure that a wallet exists and is loaded if necessary
if [ "${ENSURE_WALLET}" = "true" ]; then
    wallet_name="${jmenv['rpc_wallet_file']}"

    echo "Creating wallet $wallet_name if missing..."
    create_payload="{\
        \"jsonrpc\":\"2.0\",\
        \"id\":\"curl\",\
        \"method\":\"createwallet\",\
        \"params\":{\
            \"wallet_name\":\"${wallet_name}\",\
            \"descriptors\":false,\
            \"load_on_startup\":true\
        }\
    }"
    curl --silent --user "${btcuser}" --data-binary "${create_payload}" "${btchost}" > /dev/null || true

    echo "Loading wallet $wallet_name..."
    load_payload="{\
        \"jsonrpc\":\"2.0\",\
        \"id\":\"curl\",\
        \"method\":\"loadwallet\",\
        \"params\":{\
            \"filename\":\"${wallet_name}\",\
            \"load_on_startup\":true\
        }\
    }"
    curl --silent --user "${btcuser}" --data-binary "${load_payload}" "${btchost}" > /dev/null || true
fi

exec /usr/bin/dinit --container
