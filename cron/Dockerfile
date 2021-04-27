FROM golang:buster as builder
WORKDIR /app
COPY create_vultr_snapshot.go .
RUN go mod init create_vultr_snapshot
RUN go build ./...
RUN ls -lah

FROM python:slim-buster
MAINTAINER Vedhavyas Singareddi

# Install cron
RUN apt-get update && apt-get install -y cron

WORKDIR /

COPY . .
COPY --from=builder /app/create_vultr_snapshot .

RUN chmod +x /entrypoint.sh /media_cleaner.py /download_cleaner.sh /create_vultr_snapshot

RUN pip3 install python-dateutil

ENTRYPOINT /entrypoint.sh
