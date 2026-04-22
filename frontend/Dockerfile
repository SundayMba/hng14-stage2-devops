FROM node:20-alpine AS builder

WORKDIR /app

COPY package*.json ./
RUN npm ci
COPY app.js ./
COPY views ./views
RUN npm prune --omit=dev

FROM node:20-alpine

ENV NODE_ENV=production

WORKDIR /app

COPY --from=builder --chown=node:node /app /app

USER node
EXPOSE 3000

HEALTHCHECK --interval=15s --timeout=5s --start-period=10s --retries=3 CMD node -e "const http=require('http'); const port=process.env.PORT || 3000; const req=http.get({host:'127.0.0.1', port, path:'/health', timeout:4000}, (res) => process.exit(res.statusCode === 200 ? 0 : 1)); req.on('error', () => process.exit(1)); req.on('timeout', () => { req.destroy(); process.exit(1); });"

CMD ["node", "app.js"]
