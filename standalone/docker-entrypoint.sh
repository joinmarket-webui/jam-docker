#!/bin/bash
set -e

cd ..
. jmvenv/bin/activate
cd scripts

export JM_onion_serving_host="$(/sbin/ip route|awk '/src/ { print $9 }')"

# First we restore the default cfg as created by wallet-tool.py generate
if ! [ -f "$CONFIG" ]; then
    cp "$DEFAULT_CONFIG" "$CONFIG"
fi

if ! [ -f "$AUTO_START" ]; then
    cp "$DEFAULT_AUTO_START" "$AUTO_START"
fi

# generate ssl certificates for jmwalletd
if ! [ -f "${DATADIR}/ssl/key.pem" ]; then
    subj="/C=US/ST=Utah/L=Lehi/O=Your Company, Inc./OU=IT/CN=example.com"
    mkdir -p "${DATADIR}/ssl/" \
      && pushd "$_" \
      && openssl req -newkey rsa:4096 -x509 -sha256 -days 3650 -nodes -out cert.pem -keyout key.pem -subj "$subj" \
      && popd
fi

# auto start services
while read p; do
    [[ "$p" == "" ]] && continue
    [[ "$p" == "#"* ]] && continue
    echo "Auto start: $p"
    file_path="/etc/supervisor/conf.d/$p.conf"
    if [ -f "$file_path" ]; then
      sed -i 's/autostart=false/autostart=true/g' $file_path
    else
      echo "$file_path not found"
    fi
done <$AUTO_START

declare -A jmenv
while IFS='=' read -r -d '' envkey parsedval; do
    n="${envkey,,}" # lowercase
    if [[ "$n" =  jm_* ]]; then
        n="${n:3}" # drop jm_
        jmenv[$n]=${!envkey} # reread environment variable - characters might have been dropped (e.g 'ending in =')
    fi
done < <(env -0)

jmenv['rpc_wallet_file']=${jmenv['rpc_wallet_file']:-'jm_webui_default'}

# For every env variable JM_FOO=BAR, replace the default configuration value of 'foo' by 'BAR'
for key in ${!jmenv[@]}; do
    val=${jmenv[${key}]}
    sed -i "s/^$key =.*/$key = $val/g" "$CONFIG" || echo "Couldn't set : $key = $val, please modify $CONFIG manually"
    sed -i "s/^#$key =.*/$key = $val/g" "$CONFIG" || echo "Couldn't set : $key = $val, please modify $CONFIG manually"
done

if [[ "${READY_FILE}" ]]; then
    echo "Waiting $READY_FILE to be created..."
    while [ ! -f "$READY_FILE" ]; do sleep 1; done
    echo "The chain is fully synched"
fi

if [[ "${ENSURE_WALLET}" ]]; then
    btchost="http://${jm_rpc_user}:${jm_rpc_password}@${jm_rpc_host}:${jm_rpc_port}"
    wallet_name="${jmenv['rpc_wallet_file']}"

    create_payload="{\"jsonrpc\":\"1.0\",\"id\":\"curl\",\"method\":\"createwallet\",\"params\":[\"${wallet_name}\"]}"
    curl --data-binary "$create_payload" $btchost || true

    load_payload="{\"jsonrpc\":\"1.0\",\"id\":\"curl\",\"method\":\"loadwallet\",\"params\":[\"${wallet_name}\"]}"
    curl --data-binary "$load_payload" $btchost || true
fi


exec supervisord
