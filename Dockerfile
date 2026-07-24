# --- Estágio 1: Build ---
FROM node:20-alpine AS builder

WORKDIR /app
COPY . .

# Entra na pasta do cliente e executa o build
WORKDIR /app/client
RUN npm install
RUN npm run build

# --- Estágio 2: Servidor de Produção (Nginx) ---
FROM nginx:alpine AS runner

# Copia os arquivos estáticos gerados pelo Vite (pasta dist) para o Nginx
COPY --from=builder /app/client/dist /usr/share/nginx/html

# Expõe a porta padrão do Nginx
EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
