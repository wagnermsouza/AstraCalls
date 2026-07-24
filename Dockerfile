# --- Estágio 1: Build ---
FROM node:20-alpine AS builder

# Declara os argumentos que o Coolify/Docker pode passar
ARG VITE_API_URL
ARG VITE_API_KEY

# Define as variáveis de ambiente que o Vite lerá durante o build
ENV VITE_API_URL=$VITE_API_URL
ENV VITE_API_KEY=$VITE_API_KEY

WORKDIR /app
COPY . .

WORKDIR /app/client
RUN npm install
RUN npm run build

# --- Estágio 2: Servidor Nginx ---
# --- Estágio 2: Servidor Nginx ---
FROM nginx:alpine AS runner

COPY --from=builder /app/client/dist /usr/share/nginx/html

# Cria o arquivo de configuração do Nginx com a rota de proxy para o backend Go
RUN echo 'server { \
    listen 80; \
    location / { \
        root /usr/share/nginx/html; \
        index index.html index.htm; \
        try_files $uri $uri/ /index.html; \
    } \
    location /api/ { \
        proxy_pass http://127.0.0.1:8080/; \
        proxy_set_header Host $host; \
        proxy_set_header X-Real-IP $remote_addr; \
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for; \
        proxy_set_header X-Forwarded-Proto $scheme; \
    } \
}' > /etc/nginx/conf.d/default.conf

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
