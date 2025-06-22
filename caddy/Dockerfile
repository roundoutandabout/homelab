ARG VERSION="2.10"

FROM caddy:${VERSION}-builder AS builder

# We need these plugins to obtain SSL certificates from various providers
RUN xcaddy build \
	--with github.com/caddy-dns/cloudflare \
	--with github.com/caddy-dns/porkbun \
	--with github.com/caddy-dns/duckdns

FROM caddy:${VERSION}

COPY --from=builder /usr/bin/caddy /usr/bin/caddy
