FROM node:22-bookworm-slim

RUN corepack enable && corepack prepare pnpm@11.22.0 --activate

WORKDIR /app

COPY package.json pnpm-lock.yaml pnpm-workspace.yaml ./
COPY apps/api/package.json apps/api/package.json
COPY apps/mobile/package.json apps/mobile/package.json

RUN pnpm install --frozen-lockfile --config.production=false

COPY apps/api/nest-cli.json apps/api/tsconfig.json apps/api/tsconfig.build.json apps/api/
COPY apps/api/src apps/api/src
COPY apps/api/scripts/railway-start.sh apps/api/scripts/railway-start.sh

RUN pnpm --filter api build

ENV NODE_ENV=production
EXPOSE 3000

CMD ["sh", "apps/api/scripts/railway-start.sh"]
