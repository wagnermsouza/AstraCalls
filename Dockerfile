# --- Estágio 1: Build ---
FROM node:20-alpine AS builder
WORKDIR /app/client

# Copia todos os arquivos do projeto primeiro
COPY . .

# Desabilita telemetria do Next.js
ENV NEXT_TELEMETRY_DISABLED=1

# Instala as dependências e gera o build
RUN npm install
RUN npm run build

# --- Estágio 2: Execução ---
FROM node:20-alpine AS runner
WORKDIR /app

ENV NODE_ENV=production
ENV NEXT_TELEMETRY_DISABLED=1

# Cria usuário sem privilégios de root por segurança
RUN addgroup --system --gid 1001 nodejs
RUN adduser --system --uid 1001 nextjs

# Copia os arquivos gerados no build
COPY --from=builder /app/public ./public
COPY --from=builder --chown=nextjs:nodejs /app/.next/standalone ./
COPY --from=builder --chown=nextjs:nodejs /app/.next/static ./.next/static

USER nextjs

EXPOSE 3000
ENV PORT=3000
ENV HOSTNAME="0.0.0.0"

CMD ["node", "server.js"]
