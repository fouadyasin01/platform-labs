# --------------------------------------------------
# Stage 1 — Prepare static assets
# --------------------------------------------------
FROM alpine:3.23 AS assets

WORKDIR /web

COPY web/ .


# --------------------------------------------------
# Stage 2 — Production Nginx runtime
# --------------------------------------------------
FROM nginx:alpine

RUN apk upgrade --no-cache \
    && addgroup -S nginxapp \
    && adduser -S nginxapp -G nginxapp \
    && chown -R nginxapp:nginxapp /var/cache/nginx \
                              /var/log/nginx \
                              /etc/nginx \
                              /usr/share/nginx/html \
    && touch /var/run/nginx.pid \
    && chown nginxapp:nginxapp /var/run/nginx.pid

COPY api-gateway/nginx.conf /etc/nginx/nginx.conf
COPY --from=assets --chown=nginxapp:nginxapp /web/ /usr/share/nginx/html/

USER nginxapp

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD wget -q -O /dev/null http://127.0.0.1:8080/health || exit 1