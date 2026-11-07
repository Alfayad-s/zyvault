FROM node:22-bookworm-slim

# Node 22 ships npm 10, which crashes on this tree with "edgesOut".
RUN npm install -g npm@11.17.0

WORKDIR /app

COPY package.json package-lock.json ./
RUN npm ci --include=dev

COPY nest-cli.json tsconfig.json tsconfig.build.json ./
COPY src ./src
COPY scripts/railway-start.sh ./scripts/railway-start.sh

# Railway may start this image with pnpm. The script boots the compiled API.
RUN printf '%s\n' '#!/bin/sh' 'exec sh /app/scripts/railway-start.sh' > /usr/local/bin/pnpm \
 && chmod +x /usr/local/bin/pnpm

RUN npm run build

ENV NODE_ENV=production
EXPOSE 3000

CMD ["sh", "scripts/railway-start.sh"]
