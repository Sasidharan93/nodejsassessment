# ---- Stage 1: Build ----
FROM node:20-alpine AS builder

WORKDIR /app

# Copy only package files first (layer caching - deps only reinstall if these change)
COPY package*.json ./

# Install ALL deps (including dev) so we can run tests/lint at build time if needed
RUN npm ci

# Copy source code
COPY src ./src

# ---- Stage 2: Production ----
FROM node:20-alpine AS production

WORKDIR /app

# Set to production so npm skips devDependencies
ENV NODE_ENV=production

# Copy only package files, install ONLY production deps
COPY package*.json ./
RUN npm ci --omit=dev && npm cache clean --force

# Copy application source from builder stage
COPY --from=builder /app/src ./src

# Run as non-root user for security (node:alpine already has a 'node' user)
USER node

EXPOSE 8080

# Basic healthcheck (Cloud Run has its own, but this helps local testing)
HEALTHCHECK --interval=30s --timeout=3s CMD node -e "require('http').get('http://localhost:8080/healthz', r => process.exit(r.statusCode===200?0:1))"

CMD ["node", "src/server.js"]
