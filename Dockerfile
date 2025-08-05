FROM caddy:2-builder AS build

RUN xcaddy build \
        --with github.com/mholt/caddy-l4/layer4 \
        --with github.com/mholt/caddy-l4/modules/l4proxy \
        --with github.com/caddy-dns/cloudflare 

#####################################################################
FROM caddy:2

RUN apk add bash jq

COPY --from=build /usr/bin/caddy /usr/bin/caddy

COPY ./entrypoint.sh /
RUN chmod +x /entrypoint.sh

ENTRYPOINT [ "/usr/bin/env", "bash", "/entrypoint.sh" ]
CMD []

