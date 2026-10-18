FROM node:22-bookworm-slim

WORKDIR /app

COPY package.json ./
RUN npm install --include=dev

COPY nest-cli.json tsconfig.json tsconfig.build.json ./
COPY src ./src
COPY scripts/railway-start.sh ./scripts/railway-start.sh

RUN npm run build

ENV NODE_ENV=production
EXPOSE 3000

CMD ["sh", "scripts/railway-start.sh"]
