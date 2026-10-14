
# systemd example init scripts and service configuration for jam

Sample scripts and configuration files for systemd.

Adapt the .service file and docker compose file to your match your
specific setup.

This startup configuration assumes the existence of a "jam" user
and group. They must be created before attempting to use this script.

Rename `docker-compose.example.yml` to `docker-compose.yml` and adapt
the jam-standalone image version and environment variables:
```
BITCOIN__RPC_URL: http://CHANGEME:8332
BITCOIN__RPC_USER: CHANGEME
BITCOIN__RPC_PASSWORD: CHANGEME
```

Since this file contians sensitive information, make sure
it is only readable by the specified user.


Rename `jam.example.service` to `jam.service` and adapt
it to your needs, e.g.: change `/path/to/you/app/docker-compose.yml`
to the actual location of your `docker-compose.yml` file.

Installing the .service file consists of copying it to
/usr/lib/systemd/system directory, followed by the command
`systemctl daemon-reload` in order to update running systemd configuration.

To test, run `systemctl start jam` and to enable for system startup run
`systemctl enable jam`.
