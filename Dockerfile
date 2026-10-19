# --- Estágio 1: Build da API Go ---
FROM golang:1.26-bookworm AS go-builder
WORKDIR /app

RUN apt-get update && apt-get install -y gcc g++ libc6-dev libopus-dev

ENV GOPROXY=https://proxy.golang.org,direct

COPY go.mod ./
COPY go.mod go.s[u]m ./

RUN go mod download

COPY . .

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

RUN apk add --no-cache gcompat libc6-compat libstdc++ opus

COPY --from=node-builder /app/client/dist /usr/share/nginx/html
COPY --from=go-builder /app/server /app/server
COPY --from=go-builder /app/native/libopus_mlow.so /usr/lib/libopus_mlow.so

RUN chmod +x /app/server

# Nginx reescrevendo o IP interno 10.0.5.3 e mapeando a porta estática
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
        sub_filter "10.0.5.3" "62.169.22.148"; \
        sub_filter_once off; \
        sub_filter_types application/json text/plain; \
        proxy_read_timeout 86400s; \
        proxy_send_timeout 86400s; \
        proxy_connect_timeout 60s; \
    } \
}' > /etc/nginx/conf.d/default.conf

EXPOSE 80

ENTRYPOINT ["/bin/sh", "-c", "while true; do /app/server; sleep 2; done & nginx -g 'daemon off;'"]
