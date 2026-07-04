#!/bin/sh
set -Eeuo pipefail

BLOCKS=${1:-101} # default to mine a single block
ADDRESS=${2:-bcrt1q6rz28mcfaxtmd6v789l9rrlrusdprr9pz3cppk} # default to first address of "abandon [...] about" address

echo "Mining ${BLOCKS} blocks to address ${ADDRESS}..."
payload="{\
    \"jsonrpc\":\"1.0\",\
    \"id\":\"curl\",\
    \"method\":\"generatetoaddress\",\
    \"params\":[${BLOCKS},\"${ADDRESS}\"]\
}"
curl --silent --user "${_BTC_USER}" --data-binary "${payload}" "${_BTC_URL}" > /dev/null 2>&1

echo "Successfully mined ${BLOCKS} blocks to address ${ADDRESS}."
