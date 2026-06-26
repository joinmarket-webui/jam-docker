# jam-docker

Docker images for [Jam](https://github.com/joinmarket-webui/jam).

Contains three separate images:
- ui-only: Only the UI
- standalone: UI + joinmarket clientserver
- standalone-ng: UI + joinmarket-ng backend


## ui-only
### Usage Notes
```sh
docker pull ghcr.io/joinmarket-webui/jam-ui-only:latest
```

### Environment variables

The following environment variables control the configuration:
- `JAM_JMWALLETD_HOST` (required; jmwalletd hostname)
- `JAM_JMWALLETD_API_PORT` (required; jmwalletd api port)
- `JAM_JMWALLETD_WEBSOCKET_PORT` (required; jmwalletd websocket port)
- `JAM_JMOBWATCH_HOST` (optional; ob-watcher host; if not set `JAM_JMWALLETD_HOST` will be used)
- `JAM_JMOBWATCH_PORT` (required; ob-watcher port)

### Building Notes
Building a specific release:
```sh
docker build --label "local" \
        --build-arg JAM_REPO_REF=v0.3.0 \
        --tag "joinmarket-webui/jam-ui-only" ./ui-only
```

Building from a specific branch (with disabled release verification):
```sh
docker build --label "local" \
        --build-arg SKIP_RELEASE_VERIFICATION=true \
        --build-arg JAM_REPO_REF=master \
        --tag "joinmarket-webui/jam-ui-only" ./ui-only
```

#### Build args
- `SKIP_RELEASE_VERIFICATION` (optional, defaults to `false`; enable skipping release verification)
- `JAM_REPO` (ui git repo; defaults to `https://github.com/joinmarket-webui/jam`)
- `JAM_REPO_REF` (ui git ref; defaults to `master`)

### Inspecting the Container
```sh
docker run --rm --entrypoint="/bin/ash" -it joinmarket-webui/jam-ui-only
```

### Run
```sh
docker run --rm -it \
        --add-host host.docker.internal:host-gateway \
        --env JAM_JMWALLETD_HOST="host.docker.internal" \
        --env JAM_JMWALLETD_API_PORT="28183" \
        --env JAM_JMWALLETD_WEBSOCKET_PORT="28283" \
        --env JAM_JMOBWATCH_PORT="62601" \
        --publish "127.0.0.1:8080:80" \
        joinmarket-webui/jam-ui-only
```

or (using the host network)

```sh
docker run --rm -it \
        --network host \
        --env JAM_JMWALLETD_HOST="localhost" \
        --env JAM_JMWALLETD_API_PORT="28183" \
        --env JAM_JMWALLETD_WEBSOCKET_PORT="28283" \
        --env JAM_JMOBWATCH_PORT="62601" \
        joinmarket-webui/jam-ui-only
```

### Lint
```sh
docker run --rm -i hadolint/hadolint:latest-alpine hadolint "$@" - < "./ui-only/Dockerfile"
```


## standalone
### Usage Notes
```sh
docker pull ghcr.io/joinmarket-webui/jam-standalone:latest
```

### Environment variables
The following environment variables control the configuration:
- `APP_USER` (optional; username used for basic authentication)
- `APP_PASSWORD` (optional, but required if `APP_USER` is provided; password used for basic authentication)
- `ENSURE_WALLET` (optional, defaults to `false`; create and load `JM_RPC_WALLET_FILE` (default `jam_clientserver`) in bitcoin core on startup)
- `CREATE_WALLET_PARAMS_DESCRIPTORS` (optional, defaults to `true`; must be `false` for backend versions `< v0.9.12`)
- `READY_FILE` (optional; wait for a file to be created before starting all services, e.g. to wait for chain synchronization)
- `REMOVE_LOCK_FILES` (optional, defaults to `false`; remove leftover lockfiles from possible unclean shutdowns on startup)
- `RESTORE_DEFAULT_CONFIG` (optional, defaults to `false`; overwrites any existing `joinmarket.cfg` file with a default config)
- `WAIT_FOR_BITCOIND` (optional, defaults to `true`; wait for bitcoind to accept RPC request and report >= 100 blocks)
- `JAM_UI_PORT` (optional, defaults to `80`; adapt the port the UI is served on)

Variables starting with prefix `JM_` will be applied to `joinmarket.cfg` e.g.:
- `--env JM_GAPLIMIT=200` will set the `gaplimit` config value to `200`
- `--env JM_RPC_WALLET_FILE="jam_clientserver"` will set the `rpc_wallet_file` config value to `jam_clientserver`

### RPC authentication

The container supports two methods for Bitcoin RPC authentication:

#### Method 1: user/password
```sh
--env JM_RPC_USER="bitcoin" \
--env JM_RPC_PASSWORD="password"
```

#### Method 2: cookie authentication
```sh
--env JM_RPC_COOKIE_FILE="/path/to/.cookie"
```

**Note**: If `JM_RPC_COOKIE_FILE` is set, cookie authentication will be used. Otherwise, user/password authentication is used. The cookie file path should be accessible from within the container.

### Building Notes
Building a specific release:
```sh
docker build --label "local" \
        --build-arg JAM_REPO_REF=v0.4.1 \
        --build-arg JM_SERVER_REPO_REF=v0.9.11 \
        --tag "joinmarket-webui/jam-standalone" ./standalone
```

Building from a specific branch (with disabled release verification):
```sh
docker build --label "local" \
        --build-arg SKIP_RELEASE_VERIFICATION=true \
        --build-arg JAM_REPO_REF=master \
        --build-arg JM_SERVER_REPO_REF=master \
        --tag "joinmarket-webui/jam-standalone" ./standalone
```

#### Build args
- `SKIP_RELEASE_VERIFICATION` (optional, defaults to `false`; enable skipping release verification)
- `JAM_REPO` (ui git repo; defaults to `https://github.com/joinmarket-webui/jam`)
- `JAM_REPO_REF` (ui git ref; defaults to `master`)
- `JM_SERVER_REPO` (server git repo; defaults to `https://github.com/JoinMarket-Org/joinmarket-clientserver`)
- `JM_SERVER_REPO_REF` (server git ref; defaults to `master`)

### Inspecting the Container
```sh
docker run --rm --entrypoint="/bin/bash" -it joinmarket-webui/jam-standalone
```

### Run

#### Using user/password authentication
```sh
docker run --rm -it \
        --add-host host.docker.internal:host-gateway \
        --env JM_RPC_HOST="host.docker.internal" \
        --env JM_RPC_PORT="18443" \
        --env JM_RPC_USER="jm" \
        --env JM_RPC_PASSWORD="***" \
        --env JM_NETWORK="regtest" \
        --env JM_RPC_WALLET_FILE="jam_clientserver" \
        --env APP_USER="joinmarket" \
        --env APP_PASSWORD="joinmarket" \
        --env ENSURE_WALLET="true" \
        --env CREATE_WALLET_PARAMS_DESCRIPTORS="true" \
        --env REMOVE_LOCK_FILES="true" \
        --env RESTORE_DEFAULT_CONFIG="true" \
        --env WAIT_FOR_BITCOIND="true" \
        --volume jmdatadir:/root/.joinmarket \
        --publish "127.0.0.1:8080:80" \
        joinmarket-webui/jam-standalone
```

#### Using cookie authentication
```sh
docker run --rm -it \
        --add-host host.docker.internal:host-gateway \
        --env JM_RPC_HOST="host.docker.internal" \
        --env JM_RPC_PORT="18443" \
        --env JM_RPC_COOKIE_FILE="/bitcoin/.cookie" \
        --env JM_NETWORK="regtest" \
        --env JM_RPC_WALLET_FILE="jam_clientserver" \
        --env APP_USER="joinmarket" \
        --env APP_PASSWORD="joinmarket" \
        --env ENSURE_WALLET="true" \
        --env CREATE_WALLET_PARAMS_DESCRIPTORS="true" \
        --env REMOVE_LOCK_FILES="true" \
        --env RESTORE_DEFAULT_CONFIG="true" \
        --env WAIT_FOR_BITCOIND="true" \
        --volume jmdatadir:/root/.joinmarket \
        --volume /path/to/bitcoin/data:/bitcoin \
        --publish "127.0.0.1:8080:80" \
        joinmarket-webui/jam-standalone
```

### Lint
```sh
docker run --rm -i hadolint/hadolint:latest-alpine hadolint "$@" - < "./standalone/Dockerfile"
```


## standalone-ng
### Usage Notes
```sh
docker pull ghcr.io/joinmarket-webui/jam-standalone-ng:latest
```

Wraps the [joinmarket-ng](https://github.com/joinmarket-ng/joinmarket-ng)
backend (the next-generation Python rewrite of joinmarket-clientserver).

Configuration follows the joinmarket-ng convention: environment variables
take precedence and use the `SECTION__KEY` (double underscore) form, for
example:

```
BITCOIN__RPC_URL=http://bitcoin:8332
BITCOIN__RPC_USER=bitcoin
BITCOIN__RPC_PASSWORD=secret
# or alternatively:
# BITCOIN__RPC_COOKIE_FILE=/bitcoin/.cookie
NETWORK_CONFIG__NETWORK=mainnet
TAKER__MAX_CJ_FEE_ABS=10000
TAKER__MAX_CJ_FEE_REL=0.0003
```

Anything not covered by env vars can be set by mounting a custom
`config.toml` into `$JOINMARKET_DATA_DIR/config.toml` (default
`/root/.joinmarket-ng/config.toml`). The wrapper does not generate this
file. See the upstream [`config.toml.template`](https://github.com/joinmarket-ng/joinmarket-ng/blob/main/jmcore/src/jmcore/data/config.toml.template)
and [`settings.py`](https://github.com/joinmarket-ng/joinmarket-ng/blob/main/jmcore/src/jmcore/settings.py)
for the full list of supported keys.

Wrapper-specific env vars:
- `APP_USER`, `APP_PASSWORD`: enable HTTP basic auth for the UI
- `JAM_UI_PORT`: override the nginx listen port (default 80)
- `REMOVE_LOCK_FILES=true`: remove leftover wallet lockfiles on startup
- `READY_FILE=/path`: wait for this file before starting services
- `WAIT_FOR_BITCOIND=false`: skip the bitcoind RPC wait
- `ENSURE_WALLET=true`: create and load `BITCOIN__DESCRIPTOR_WALLET_NAME` (default `jam_ng`) at startup

### Build
```sh
JAM_REPO_REF="devel" \
JM_NG_REPO_REF="main" \
    docker buildx build \
        --build-arg JAM_REPO_REF \
        --build-arg JM_NG_REPO_REF \
        --tag "joinmarket-webui/jam-standalone-ng" ./standalone-ng
```

### Lint
```sh
docker run --rm -i hadolint/hadolint:latest-alpine hadolint "$@" - < "./standalone-ng/Dockerfile"
```


## Resources
- JoinMarket (GitHub): https://github.com/JoinMarket-Org/joinmarket-clientserver
- Jam (GitHub): https://github.com/joinmarket-webui/jam
- Umbrel (GitHub): https://github.com/getumbrel/umbrel
- Citadel (GitHub): https://github.com/runcitadel/citadel
---
- OCI Image Annotations: https://github.com/opencontainers/image-spec/blob/main/annotations.md
