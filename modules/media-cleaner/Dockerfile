FROM rust:slim-buster as builder
MAINTAINER Vedhavyas Singareddi

RUN apt-get update && apt-get install -y libssl-dev pkg-config

RUN mkdir -p /media-cleaner
WORKDIR /media-cleaner
COPY src src
COPY Cargo.lock Cargo.lock
COPY Cargo.toml Cargo.toml
RUN cargo build --release

FROM debian:buster-slim
MAINTAINER Vedhavyas Singareddi

# Install cron
RUN apt-get update && apt-get install -y cron

WORKDIR /
COPY --from=builder /media-cleaner/target/release/media-cleaner /media-cleaner
COPY ./entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh /media-cleaner

ENTRYPOINT /entrypoint.sh
