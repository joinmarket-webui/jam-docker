#!/bin/bash
set -e

# ensure 'log' directory exists
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

# adapt 'blockchain_source' if missing and we're in regtest mode
if [ "${jmenv['network']}" = "regtest" ] && [ "${jmenv['blockchain_source']}" = "" ]; then
    jmenv['blockchain_source']='regtest'
fi

# there is no 'regtest' value for config 'network': make sure to use "testnet" in regtest mode
if [ "${jmenv['network']}" = "regtest" ]; then
    jmenv['network']='testnet'
fi

# For every env variable JM_FOO=BAR, replace the default configuration value of 'foo' by 'BAR'
for key in "${!jmenv[@]}"; do
    val="${jmenv[${key}]}"
    sed -i "s/^$key =.*/$key = $val/g" "$CONFIG" || echo "Couldn't set : $key = $val, please modify $CONFIG manually"
done

# wait for a ready file to be created if necessary
if [ "${READY_FILE}" ] && [ "${READY_FILE}" != "false" ]; then
    echo "Waiting for $READY_FILE to be created..."
    while [ ! -f "$READY_FILE" ]; do sleep 1; done
    echo "The chain is fully synched"
fi

# ensure that a wallet exists and is loaded if necessary
if [ "${ENSURE_WALLET}" = "true" ]; then
    btcuser="${jmenv['rpc_user']}:${jmenv['rpc_password']}"
    btchost="http://${jmenv['rpc_host']}:${jmenv['rpc_port']}"
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


exec supervisord
