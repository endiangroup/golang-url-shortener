FROM alpine

LABEL maintainer="Adrian Duke <adrian@endian.io>"
LABEL readme.md="https://github.com/endiangroup/golang-url-shortener/blob/master/README.md"
LABEL description="This Dockerfile will install the Golang URL Shortener."

RUN apk update && apk add ca-certificates curl

EXPOSE 80

COPY /go/src/github.com/endiangroup/golang-url-shortener/docker_releases/staging/golang-url-shortener_linux_amd64/golang-url-shortener /

VOLUME ["/data"]

HEALTHCHECK --interval=30s CMD curl -f http://127.0.0.1/api/v1/info || exit 1

CMD ["/golang-url-shortener"]
