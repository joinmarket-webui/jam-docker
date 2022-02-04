# joinmarket-webui-docker

Docker images for [joinmarket-webui](https://github.com/joinmarket-webui/joinmarket-webui).

Contains two separate images:
- ui-only: Only the UI
- standalone: UI + joinmarket clientserver


## ui-only
### Usage Notes
```sh
docker pull ghcr.io/joinmarket-webui/joinmarket-webui-ui-only:latest
```

### Environment variables

The following environment variables control the configuration
- `JMWEBUI_JM_WALLETD_HOST` (required; jmwalletd rpc hostname)
- `JMWEBUI_JM_WALLETD_PORT` (required; jmwalletd rpc port)

### Run
```sh
docker run --rm  -it \
        --add-host=host.docker.internal:host-gateway \
        --env JMWEBUI_JM_WALLETD_HOST="host.docker.internal" \
        --env JMWEBUI_JM_WALLETD_PORT="28183" \
        --publish "8080:80" \
        joinmarket-webui/joinmarket-webui-ui-only
```

### Building Notes
```sh
docker build --label "local" \
        --build-arg JM_UI_REPO_REF=master \
        --tag "joinmarket-webui/joinmarket-webui-ui-only" ./ui-only
```

#### Build args
- `JM_UI_REPO` (ui git repo; defaults to `https://github.com/joinmarket-webui/joinmarket-webui`)
- `JM_UI_REPO_BRANCH` (ui git branch; defaults to `master`)
- `JM_UI_REPO_REF` (ui git ref; defaults to `master`)

### Inspecting the Container
```sh
docker run --rm --entrypoint="/bin/ash" -it joinmarket-webui/joinmarket-webui-ui-only
```


## standalone
### Usage Notes
```sh
docker pull ghcr.io/joinmarket-webui/joinmarket-webui-standalone:latest
```

### Environment variables

Variables starting with prefix `JM_` will be applied to `joinmarket.cfg`

### Run
```sh
docker run --rm  -it \
        --add-host=host.docker.internal:host-gateway \
        --env JM_RPC_HOST="host.docker.internal" \
        --env JM_RPC_PORT="18443" \
        --env JM_RPC_USER="jm" \
        --env JM_RPC_PASSWORD="***" \
        --env JM_NETWORK="regtest" \
        --publish "8080:80" \
        joinmarket-webui/joinmarket-webui-standalone
```

### Building Notes
```sh
docker build --label "local" \
        --build-arg JM_UI_REPO_REF=master \
        --build-arg JM_SERVER_REPO_REF=master \
        --tag "joinmarket-webui/joinmarket-webui-standalone" ./standalone
```

#### Build args
- `JM_UI_REPO` (ui git repo; defaults to `https://github.com/joinmarket-webui/joinmarket-webui`)
- `JM_UI_REPO_BRANCH` (ui git branch; defaults to `master`)
- `JM_UI_REPO_REF` (ui git ref; defaults to `master`)
---
- `JM_SERVER_REPO` (server git repo; defaults to `https://github.com/JoinMarket-Org/joinmarket-clientserver`)
- `JM_SERVER_REPO_BRANCH` (server git branch; defaults to `master`)
- `JM_SERVER_REPO_REF` (server git ref; defaults to `master`)

### Inspecting the Container
```sh
docker run --rm --entrypoint="/bin/bash" -it joinmarket-webui/joinmarket-webui-standalone
```


## TODO
- Do not run as root inside container.
  - Clarify what it takes for all services to be started as non-root user.
  - See [joinmarket-clientserver#PR699](https://github.com/JoinMarket-Org/joinmarket-clientserver/pull/669) and
    [dmp1ce/joinmarket-DOCKERFILE](https://github.com/dmp1ce/joinmarket-DOCKERFILE)
- Make irc config options editable via environment variables
  - A coinjoin on regtest is not possible, because these params can only be replaced by mounting an own `joinmarket.cfg`


## Resources
- JoinMarket (GitHub): https://github.com/JoinMarket-Org/joinmarket-clientserver
- joinmarket-webui (GitHub): https://github.com/joinmarket-webui/joinmarket-webui
- Umbrel (GitHub): https://github.com/getumbrel/umbrel
- Citadel (GitHub): https://github.com/runcitadel/citadel
---
- OCI Image Annotations: https://github.com/opencontainers/image-spec/blob/main/annotations.md
