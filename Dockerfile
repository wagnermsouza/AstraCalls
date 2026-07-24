# --- Estágio 1: Build ---
FROM node:20-alpine AS builder

# 1. Define a raiz de trabalho e copia TODOS os arquivos do repositório
WORKDIR /app
COPY . .

# 2. Entra na pasta client (onde está o package.json de fato)
WORKDIR /app/client

ENV NEXT_TELEMETRY_DISABLED=1

# 3. Instala e gera o build do Next.js
RUN npm install
RUN npm run build

# --- Estágio 2: Execução ---
FROM node:20-alpine AS runner
WORKDIR /app

ENV NODE_ENV=production
ENV NEXT_TELEMETRY_DISABLED=1

RUN addgroup --system --gid 1001 nodejs
RUN adduser --system --uid 1001 nextjs

# Copia os arquivos compilados de dentro da pasta client
COPY --from=builder /app/client/public ./public
COPY --from=builder --chown=nextjs:nodejs /app/client/.next/standalone ./
COPY --from=builder --chown=nextjs:nodejs /app/client/.next/static ./.next/static

USER nextjs

EXPOSE 3000
ENV PORT=3000
ENV HOSTNAME="0.0.0.0"

CMD ["node", "server.js"]
