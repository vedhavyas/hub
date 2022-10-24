FROM golang:bullseye as builder
RUN mkdir -p /go/archiver
WORKDIR /go/archiver
COPY . .
RUN go build ./...

FROM debian:bullseye
COPY --from=builder /go/archiver/archiver /app/archiver
# Install cron
RUN apt-get update && apt-get install -y cron

WORKDIR /
COPY entrypoint.sh entrypoint.sh
RUN chmod +x /entrypoint.sh
ENTRYPOINT /entrypoint.sh
