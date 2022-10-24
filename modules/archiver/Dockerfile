FROM golang:bullseye as builder
RUN mkdir -p /go/archiver
WORKDIR /go/archiver
COPY . .
RUN go build ./...

FROM debian:bullseye

COPY --from=builder /go/archiver/archiver /app/archiver

ENTRYPOINT ["/app/archiver"]
