FROM node:22-alpine3.22 AS dependencies

WORKDIR /app

COPY app/package*.json ./

RUN npm ci --omit=dev


FROM node:22-alpine3.22 AS runtime

WORKDIR /app

ENV NODE_ENV=production \
    NPM_CONFIG_UPDATE_NOTIFIER=false

RUN apk upgrade --no-cache \
    && addgroup -S appgroup -g 1001 \
    && adduser -S appuser -u 1001 -G appgroup \
    && rm -rf /usr/local/lib/node_modules/npm \
              /usr/local/lib/node_modules/corepack

COPY --from=dependencies /app/package*.json ./
COPY --from=dependencies /app/node_modules ./node_modules
COPY app/server.js ./server.js

RUN chown -R 1001:1001 /app

USER 1001

EXPOSE 3000

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD node -e "fetch('http://127.0.0.1:3000/health').then(r => { if (!r.ok) process.exit(1); }).catch(() => process.exit(1))"

CMD ["node", "server.js"]