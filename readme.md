# jam-docker

Docker images for [Jam](https://github.com/joinmarket-webui/jam).

Contains separate images:
- `ui-only`: Only the UI
- `standalone-ng`: UI + joinmarket-ng backend


## ui-only
Bundles [Jam](https://github.com/joinmarket-webui/jam) without backend.

### Usage Notes
```sh
docker pull ghcr.io/joinmarket-webui/jam-ui-only:latest
```

### Environment variables

The following environment variables control the configuration:
- `JAM_JMWALLETD_HOST` (required; jmwalletd hostname)
- `JAM_JMWALLETD_API_PORT` (required; jmwalletd api port)
- `JAM_JMWALLETD_WEBSOCKET_PORT` (optional; jmwalletd websocket port; if not set `JAM_JMWALLETD_API_PORT` will be used)
- `JAM_JMWALLETD_WEBSOCKET_PATH` (optional; path to websocket endpoint; defaults to `/api/v1/ws`)
- `JAM_JMOBWATCH_HOST` (optional; ob-watcher host; if not set `JAM_JMWALLETD_HOST` will be used)
- `JAM_JMOBWATCH_PORT` (required; ob-watcher port)

### Run
```sh
docker run --rm -it \
  --add-host host.docker.internal:host-gateway \
  --env JAM_JMWALLETD_HOST="host.docker.internal" \
  --env JAM_JMWALLETD_API_PORT="28183" \
  --env JAM_JMWALLETD_WEBSOCKET_PORT="28183" \
  --env JAM_JMOBWATCH_PORT="62601" \
  --publish "127.0.0.1:8080:80" \
  ghcr.io/joinmarket-webui/jam-ui-only:latest
```

or (using the host network)

```sh
docker run --rm -it \
  --network host \
  --env JAM_JMWALLETD_HOST="localhost" \
  --env JAM_JMWALLETD_API_PORT="28183" \
  --env JAM_JMWALLETD_WEBSOCKET_PORT="28183" \
  --env JAM_JMOBWATCH_PORT="62601" \
  ghcr.io/joinmarket-webui/jam-ui-only:latest
```

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

### Lint
```sh
docker run --rm -i hadolint/hadolint:latest-alpine hadolint "$@" - < "./ui-only/Dockerfile"
```


## standalone-ng
Bundles [Jam](https://github.com/joinmarket-webui/jam) with [JoinMarket NG](https://github.com/joinmarket-ng/joinmarket-ng) as backend.

### Usage Notes
```sh
docker pull ghcr.io/joinmarket-webui/jam-standalone-ng:latest
```

### Environment variables

The following environment variables control the configuration:
- `APP_USER` (optional; username used for basic authentication)
- `APP_PASSWORD` (optional, but required if `APP_USER` is provided; password used for basic authentication)
- `READY_FILE` (optional; wait for a file to be created before starting all services, e.g. to wait for chain synchronization)
- `REMOVE_LOCK_FILES` (optional, defaults to `false`; remove leftover lockfiles from possible unclean shutdowns on startup)
- `WAIT_FOR_BITCOIND` (optional, defaults to `true`; wait for bitcoind to accept RPC request and report >= 100 blocks)
- `JAM_UI_PORT` (optional, defaults to `80`; adapt the port the UI is served on)

### Run
```sh
docker run --rm -it \
  --env BITCOIN__RPC_URL="https://CHANGEME:8332" \
  --env BITCOIN__RPC_USER="CHANGEME" \
  --env BITCOIN__RPC_PASSWORD="CHANGEME" \
  --publish "127.0.0.1:8080:80" \
  ghcr.io/joinmarket-webui/jam-standalone-ng:latest
```

#### Configuration
The upstream `config.toml.template` is the canonical list of settings. Every
nested `[section] key` can be supplied as an environment variable by uppercasing
both names and joining them with a double underscore: `SECTION__KEY`.
Environment variables take precedence, for example:

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

Top-level and non-settings options can be set by mounting a custom `config.toml`
into `$JOINMARKET_DATA_DIR/config.toml` (default `/root/.joinmarket-ng/config.toml`).
The wrapper does not generate this file.
See the upstream [`config.toml.template`](https://github.com/joinmarket-ng/joinmarket-ng/blob/main/jmcore/src/jmcore/data/config.toml.template)
and [`settings.py`](https://github.com/joinmarket-ng/joinmarket-ng/blob/main/jmcore/src/jmcore/settings.py) for the full list of supported keys.

Example for running with customized config variables:
```sh
docker run --rm -it \
  --env BITCOIN__RPC_URL="https://CHANGEME:8332" \
  --env BITCOIN__RPC_USER="CHANGEME" \
  --env BITCOIN__RPC_PASSWORD="CHANGEME" \
  --env LOGGING__LEVEL="INFO" \
  --env NETWORK_CONFIG__NETWORK="mainnet" \
  --env NETWORK_CONFIG__BITCOIN_NETWORK="mainnet" \
  --env NETWORK_CONFIG__DIRECTORY_SERVERS="CHANGEME0.onion:5222,CHANGEME1.onion:5222" \
  --env WALLET__MIXDEPTH_COUNT="3" \
  --env WALLET__GAP_LIMIT="21" \
  --env WALLET__SCAN_RANGE="1000" \
  --env WALLET__SMART_SCAN="true" \
  --env WALLET__BACKGROUND_FULL_RESCAN="true" \
  --env WALLET__SCAN_LOOKBACK_BLOCKS="52560" \
  [...]
  --publish "127.0.0.1:8080:80" \
  ghcr.io/joinmarket-webui/jam-standalone-ng:latest
```

### Building Notes
Building a specific release:
```sh
docker build --label "local" \
  --build-arg JAM_REPO_REF=v2.0.0-beta.0 \
  --build-arg JM_NG_REPO_REF=0.34.2 \
  --tag "joinmarket-webui/jam-standalone-ng" ./standalone-ng
```

Building from a specific branch (with disabled release verification):
```sh
docker build --label "local" \
  --build-arg SKIP_RELEASE_VERIFICATION=true \
  --build-arg JAM_REPO_REF=master \
  --build-arg JM_NG_REPO_REF=main \
  --tag "joinmarket-webui/jam-standalone-ng" ./standalone-ng
```

#### Build args
- `SKIP_RELEASE_VERIFICATION` (optional, defaults to `false`; enable skipping release verification)
- `JAM_REPO` (ui git repo; defaults to `https://github.com/joinmarket-webui/jam`)
- `JAM_REPO_REF` (ui git ref; defaults to `master`)
- `JM_NG_REPO` (backend git repo; defaults to `https://github.com/joinmarket-ng/joinmarket-ng`)
- `JM_NG_REPO_REF` (backend git ref; defaults to `main`)

### Lint
```sh
docker run --rm -i hadolint/hadolint:latest-alpine hadolint "$@" - < "./standalone-ng/Dockerfile"
```


## Resources
- Jam (GitHub): https://github.com/joinmarket-webui/jam
- JoinMarket NG (GitHub): https://github.com/joinmarket-ng/joinmarket-ng
- JoinMarket NG (Docs): https://joinmarket-ng.github.io/joinmarket-ng/
