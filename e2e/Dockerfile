FROM node:25-alpine

RUN npm install -g pnpm
RUN apk add --no-cache git

WORKDIR /app
RUN git clone https://github.com/coinbase/x402 . && \
    git checkout cc6d0fcc1efafc7f00b05ebe1887a0086d5a7cef

ENV NODE_OPTIONS="--max-old-space-size=4096"

WORKDIR /app/typescript
RUN pnpm install
RUN pnpm build

WORKDIR /app/examples/typescript
RUN pnpm install
RUN pnpm build --filter "...facilitator-example" --filter "...express-server-example"

EXPOSE 4021 4022
