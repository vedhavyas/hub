FROM golang:alpine as builder
WORKDIR /app
RUN go install github.com/caddyserver/xcaddy/cmd/xcaddy@latest
RUN xcaddy build --with github.com/mholt/caddy-webdav
RUN ./caddy list-modules

FROM alpine

COPY --from=builder /app/caddy /app/
RUN mkdir -p /data

WORKDIR /app

COPY Caddyfile Caddyfile

VOLUME /data
EXPOSE 8080
CMD ["sh", "-c", "./caddy run -adapter caddyfile -config ./Caddyfile"]
