FROM node:20-alpine

RUN apk add --no-cache git

WORKDIR /action

COPY package.json package-lock.json* tsconfig.json ./
RUN npm ci --omit=dev --ignore-scripts || npm install --omit=dev --ignore-scripts

COPY src ./src

# Install dev deps only for the build step, then prune.
RUN npm install --no-save typescript @types/node \
 && npx tsc -p tsconfig.json \
 && npm prune --omit=dev \
 && rm -rf src

# GITHUB_WORKSPACE is the mount point for the caller repo inside GHA.
WORKDIR /github/workspace

ENTRYPOINT ["node", "/action/dist/cli.js"]
