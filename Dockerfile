FROM node:20-slim AS base

FROM base AS builder
RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    build-essential \
    python3 \
    pkg-config \
    libcairo2-dev \
    libjpeg-dev \
    libpango1.0-dev \
    libgif-dev \
    librsvg2-dev \
    libfreetype6-dev \
    libharfbuzz-dev \
    libfribidi-dev \
    fonts-dejavu \
    fontconfig \
    curl \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*
WORKDIR /app
ENV npm_config_python=/usr/bin/python3

ARG NEXT_PUBLIC_APP_URL
ARG NEXT_PUBLIC_OPEN_SOURCE_URL
ARG NEXT_PUBLIC_DEFAULT_LOCALE=zh-cn

ENV NEXT_PUBLIC_APP_URL=$NEXT_PUBLIC_APP_URL
ENV NEXT_PUBLIC_OPEN_SOURCE_URL=$NEXT_PUBLIC_OPEN_SOURCE_URL
ENV NEXT_PUBLIC_DEFAULT_LOCALE=$NEXT_PUBLIC_DEFAULT_LOCALE
ENV NEXT_TELEMETRY_DISABLED=1
ENV DOCKER_BUILD=true
# Increase Node.js memory limit for Next.js build
ENV NODE_OPTIONS="--max-old-space-size=4096"

COPY . .
# Replace relative image paths with CDN URLs
# RUN chmod +x ./scripts/replace-image-paths.sh && ./scripts/replace-image-paths.sh
RUN npm ci && npm run build

FROM base AS runner
# Runtime libraries for canvas and image processing support
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    libcairo2 \
    libpango-1.0-0 \
    libpangocairo-1.0-0 \
    libjpeg62-turbo \
    libgif7 \
    librsvg2-2 \
    fontconfig \
    libfreetype6 \
    libharfbuzz0b \
    libfribidi0 \
    fonts-dejavu \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*
ENV NODE_ENV=production
RUN addgroup --system --gid 1001 nodejs
RUN adduser --system --uid 1001 nextjs
WORKDIR /app

# Copy the standalone Next.js server plus runtime assets that are read from disk.
COPY --from=builder --chown=nextjs:nodejs /app/public ./public
COPY --from=builder --chown=nextjs:nodejs /app/fonts ./fonts
COPY --from=builder --chown=nextjs:nodejs /app/content ./content
COPY --from=builder --chown=nextjs:nodejs /app/.next/standalone ./
COPY --from=builder --chown=nextjs:nodejs /app/.next/static ./.next/static

USER nextjs

ENV NEXT_TELEMETRY_DISABLED=1
ENV PORT=3000
ENV HOSTNAME=0.0.0.0

EXPOSE 3000

CMD ["node", "server.js"]
