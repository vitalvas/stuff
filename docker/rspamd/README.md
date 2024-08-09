# Rspamd in a Docker container

This container is made to assemble the final container.

But this does not prevent you from mounting your configuration in `/etc/rspamd`.

## Docker-compose

Example: `docker-compose.yml`

```
version: "3.8"
services:
  rspamd:
    image: cloudmail/rspamd:latest
    restart: always
    hostname: rspamd
    volumes:
      - /media/rspamd/data:/var/lib/redis
      - /media/rspamd/conf/local.d:/etc/rspamd/local.d
```

