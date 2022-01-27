# jm-docker


```sh
> docker-compose -f docker-compose.regtest.yml up
```

This setup will start 3 joinmarket-ui container. 
Two "standalone" container connecting to the same bitcoin-core instance.
One "ui-only" container connecting to the second standalone container.

Generate coins:
```sh
> docker exec -t jm-docker_bitcoind_1 bitcoin-cli -datadir=/data generatetoaddress 1 $target_address
```
```sh
> docker exec -t jm-docker_bitcoind_1 bitcoin-cli -datadir=/data -generate 100
```