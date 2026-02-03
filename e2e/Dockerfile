FROM node:25-alpine

RUN npm install -g pnpm
RUN apk add --no-cache git

WORKDIR /app
RUN git clone https://github.com/coinbase/x402 . && \
    git checkout be253a872d1022c8d5d3f1f7ac9326daf30e999d

ENV NODE_OPTIONS="--max-old-space-size=4096"

WORKDIR /app/typescript
RUN pnpm install
RUN pnpm build

WORKDIR /app/examples/typescript
RUN pnpm install
RUN pnpm build --filter "...facilitator-example" --filter "...express-server-example"

EXPOSE 4021 4022
