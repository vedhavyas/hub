FROM golang:alpine as builder

RUN mkdir -p /go/archiver
WORKDIR /go/archiver
COPY . .
RUN go build ./...

FROM alpine

COPY --from=builder /go/archiver/archiver /app/archiver

VOLUME /data

ENTRYPOINT /app/archiver
