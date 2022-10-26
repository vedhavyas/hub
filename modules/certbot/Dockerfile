FROM golang:bullseye as builder
RUN mkdir -p /go/certbot
WORKDIR /go/certbot
COPY . .
RUN go build ./...

FROM python:slim-bullseye
COPY --from=builder /go/certbot/certbot /app/certbot
# Install cron
RUN apt-get update && apt-get install -y cron
# install certbot
RUN pip3 install certbot

WORKDIR /
COPY entrypoint.sh entrypoint.sh
RUN chmod +x /entrypoint.sh
ENTRYPOINT /entrypoint.sh
