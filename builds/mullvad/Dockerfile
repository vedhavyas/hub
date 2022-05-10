FROM golang:alpine as builder

RUN mkdir -p /go/mullvad
WORKDIR /go/mullvad
COPY . .
RUN go build ./...

FROM alpine

COPY --from=builder /go/mullvad/mullvad-cli /app/mullvad-cli

VOLUME /data

ENV USER=docker
ENV UID=1000
ENV GID=1000

RUN addgroup -g $GID -S $USER
RUN adduser \
    --disabled-password \
    --gecos "" \
    --home "$(pwd)" \
    --ingroup "$USER" \
    --no-create-home \
    --uid "$UID" \
    "$USER"

USER $USER
ENTRYPOINT /app/mullvad-cli




