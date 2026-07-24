# --- Estágio 1: Build da API Go ---
FROM golang:1.22-alpine AS go-builder
WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -o server .

# --- Estágio 2: Build do Frontend React/Vite ---
FROM node:20-alpine AS node-builder
WORKDIR /app
COPY . .
WORKDIR /app/client
RUN npm install
RUN npm run build

# --- Estágio 3: Container Final ---
FROM nginx:alpine

# Copia arquivos do frontend e o binário em Go
COPY --from=node-builder /app/client/dist /usr/share/nginx/html
COPY --from=go-builder /app/server /app/server

# Permissão de execução para o binário Go
RUN chmod +x /app/server

# Configuração do Nginx apontando para o Go na 8088
RUN echo 'server { \
    listen 80; \
    location / { \
        root /usr/share/nginx/html; \
        index index.html index.htm; \
        try_files $uri $uri/ /index.html; \
    } \
    location /api/ { \
        proxy_pass http://127.0.0.1:8088/; \
        proxy_http_version 1.1; \
        proxy_set_header Upgrade $http_upgrade; \
        proxy_set_header Connection "upgrade"; \
        proxy_set_header Host $host; \
        proxy_set_header X-Real-IP $remote_addr; \
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for; \
        proxy_set_header X-Forwarded-Proto $scheme; \
    } \
}' > /etc/nginx/conf.d/default.conf

EXPOSE 80

# Força a inicialização do Go e depois do Nginx ignorando o entrypoint original
ENTRYPOINT ["/bin/sh", "-c", "/app/server & nginx -g 'daemon off;'"]
