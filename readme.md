# jam-docker

Docker images for [Jam](https://github.com/joinmarket-webui/jam).

Contains two separate images:
- ui-only: Only the UI
- standalone: UI + joinmarket clientserver


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
        --publish "8080:80" \
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
- `ENSURE_WALLET` (optional, defaults to `false`; create and load the wallet in bitcoin core on startup)
- `READY_FILE` (optional; wait for a file to be created before starting all services, e.g. to wait for chain synchronization)
- `REMOVE_LOCK_FILES` (optional, defaults to `false`; remove leftover lockfiles from possible unclean shutdowns on startup)
- `RESTORE_DEFAULT_CONFIG` (optional, defaults to `false`; overwrites any existing `joinmarket.cfg` file with a default config)
- `WAIT_FOR_BITCOIND` (optional, defaults to `true`; wait for bitcoind to accept RPC request and report >= 100 blocks)

Variables starting with prefix `JM_` will be applied to `joinmarket.cfg` e.g.:
- `JM_GAPLIMIT: 2000` will set the `gaplimit` config value to `2000`

### Building Notes
Building a specific release:
```sh
docker build --label "local" \
        --build-arg JAM_REPO_REF=v0.3.0 \
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
```sh
docker run --rm -it \
        --add-host host.docker.internal:host-gateway \
        --env JM_RPC_HOST="host.docker.internal" \
        --env JM_RPC_PORT="18443" \
        --env JM_RPC_USER="jm" \
        --env JM_RPC_PASSWORD="***" \
        --env JM_NETWORK="regtest" \
        --env APP_USER="joinmarket" \
        --env APP_PASSWORD="joinmarket" \
        --env ENSURE_WALLET="true" \
        --env REMOVE_LOCK_FILES="true" \
        --env RESTORE_DEFAULT_CONFIG="true" \
        --env WAIT_FOR_BITCOIND="true" \
        --volume jmdatadir:/root/.joinmarket \
        --publish "8080:80" \
        joinmarket-webui/jam-standalone
```

### Lint
```sh
docker run --rm -i hadolint/hadolint:latest-alpine hadolint "$@" - < "./standalone/Dockerfile"
```


## Resources
- JoinMarket (GitHub): https://github.com/JoinMarket-Org/joinmarket-clientserver
- Jam (GitHub): https://github.com/joinmarket-webui/jam
- Umbrel (GitHub): https://github.com/getumbrel/umbrel
- Citadel (GitHub): https://github.com/runcitadel/citadel
---
- OCI Image Annotations: https://github.com/opencontainers/image-spec/blob/main/annotations.md
