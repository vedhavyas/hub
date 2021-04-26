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

ENV USER=docker
ENV UID=1000
ENV GID=1000

RUN addgroup -S $USER
RUN adduser \
    --disabled-password \
    --gecos "" \
    --home "$(pwd)" \
    --ingroup "$USER" \
    --no-create-home \
    --uid "$UID" \
    "$USER"

CMD ["sh", "-c", "chown $USER:$USER /data && ./caddy run -adapter caddyfile -config ./Caddyfile"]
