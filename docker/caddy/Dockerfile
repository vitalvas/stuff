FROM caddy:builder-alpine AS builder

RUN xcaddy build \
    --with github.com/WingLim/caddy-webhook \
    --with github.com/abiosoft/caddy-exec \
    --with github.com/kirsch33/realip \
    --with github.com/techknowlogick/caddy-s3browser@main \
    --with github.com/git001/caddyv2-upload \
    --with github.com/mholt/caddy-webdav \
    --with github.com/pteich/caddy-tlsconsul \
    --with github.com/mholt/caddy-ratelimit \
    --with github.com/caddy-dns/cloudflare \
    --with github.com/caddy-dns/route53 

FROM caddy:latest
COPY --from=builder /usr/bin/caddy /usr/bin/caddy
