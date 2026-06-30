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
