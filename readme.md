# jm-docker

## Test
The docker-compose setup will start 3 joinmarket-ui container. 
Two "standalone" container connecting to the same bitcoin-core instance.
One "ui-only" container connecting to the second standalone container.

```sh
> docker-compose up
```

Visit your browser on `http://localhost:8080` for the first `standalone` instance, 
`http://localhost:8081` for the `ui-only` instance (proxying to the second `standalone` instance).

Generate coins:
```sh
> docker exec -t jm-docker_bitcoind_1 bitcoin-cli -datadir=/data generatetoaddress 1 $target_address
```
```sh
> docker exec -t jm-docker_bitcoind_1 bitcoin-cli -datadir=/data -generate 100
```

## TODO
- Do not run as root inside container.
  - Clarify what it takes for all services to be started as non-root user.
  - See [joinmarket-clientserver#PR699](https://github.com/JoinMarket-Org/joinmarket-clientserver/pull/669) and
    [dmp1ce/joinmarket-DOCKERFILE](https://github.com/dmp1ce/joinmarket-DOCKERFILE)
- Make irc config options editable via environment variables
  - A coinjoin on regtest is not possible, because these params can only be replaced by mounting an own `joinmarket.cfg`