FROM golang:alpine as builder

RUN mkdir -p /go/mullvad
WORKDIR /go/mullvad
COPY . .
RUN go build ./...

FROM alpine

COPY --from=builder /go/mullvad/mullvad-cli /app/mullvad-cli

VOLUME /data

ENTRYPOINT /app/mullvad-cli




