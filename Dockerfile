# --- Estágio 1: Build da API Go ---
FROM golang:1.26-bookworm AS go-builder
WORKDIR /app

# Instala o gcc/g++ essencial no Debian
RUN apt-get update && apt-get install -y gcc g++ libc6-dev libopus-dev

# Define o proxy oficial do Go
ENV GOPROXY=https://proxy.golang.org,direct

# Copia os arquivos de dependência
COPY go.mod ./
COPY go.mod go.s[u]m ./

# Baixa as dependências
RUN go mod download

COPY . .

# Habilita CGO e compila com a tag mlow
RUN CGO_ENABLED=1 GOOS=linux go build -tags mlow -o server ./cmd/server

# --- Estágio 2: Build do Frontend React/Vite ---
FROM node:20-alpine AS node-builder
WORKDIR /app
COPY . .
WORKDIR /app/client
RUN npm install
RUN npm run build

# --- Estágio 3: Container Final ---
FROM nginx:alpine

# Instala suporte a glibc e a biblioteca libopus nativa do Alpine
RUN apk add --no-cache gcompat libc6-compat libstdc++ opus

# Copia arquivos do frontend e o binário em Go
COPY --from=node-builder /app/client/dist /usr/share/nginx/html
COPY --from=go-builder /app/server /app/server

# Copia a biblioteca libopus_mlow.so para a pasta de bibliotecas do sistema (/usr/lib)
COPY --from=go-builder /app/native/libopus_mlow.so /usr/lib/libopus_mlow.so

# Permissão de execução para o binário Go
RUN chmod +x /app/server

# Configuração do Nginx com suporte completo a WebSockets e Timeouts estendidos
RUN echo 'server { \
    listen 80; \
    client_max_body_size 100M; \
    location / { \
        root /usr/share/nginx/html; \
        index index.html index.htm; \
        try_files $uri $uri/ /index.html; \
    } \
    location /api/ { \
        proxy_pass http://127.0.0.1:8088; \
        proxy_http_version 1.1; \
        proxy_set_header Upgrade $http_upgrade; \
        proxy_set_header Connection "Upgrade"; \
        proxy_set_header Host $host; \
        proxy_set_header X-Real-IP $remote_addr; \
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for; \
        proxy_set_header X-Forwarded-Proto $scheme; \
        proxy_read_timeout 86400s; \
        proxy_send_timeout 86400s; \
        proxy_connect_timeout 60s; \
    } \
}' > /etc/nginx/conf.d/default.conf

EXPOSE 80

# Força a inicialização do Go passando o IP público explicitamente e depois o Nginx
ENTRYPOINT ["/bin/sh", "-c", "/app/server -public-ip 62.169.22.148 & nginx -g 'daemon off;'"]
