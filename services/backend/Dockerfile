FROM node:24.19.0-alpine

WORKDIR /app

COPY package.json ./
COPY src ./src
COPY scripts ./scripts

ENV NODE_ENV=production \
    HOST=0.0.0.0 \
    PORT=8787 \
    DATABASE_PATH=/data/pilot.sqlite

RUN mkdir -p /data /backups && chown -R node:node /app /data /backups

USER node

EXPOSE 8787

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD wget -qO- http://127.0.0.1:8787/ready >/dev/null || exit 1

CMD ["node", "src/server.js"]
