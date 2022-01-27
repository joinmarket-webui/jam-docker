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
- Make irc config vars editable: A coinjoin on regtest is not possible, because these params cannot be replaced at the moment.
