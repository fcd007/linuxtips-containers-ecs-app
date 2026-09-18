FROM alpine:3.24.1

RUN apk add --no-cache busybox-extras \
    && addgroup -S appgroup \
    && adduser -S -G appgroup appuser

USER appuser

EXPOSE 8080

CMD ["sh", "-c", "while true; do { printf 'HTTP/1.1 200 OK\\r\\nContent-Type: text/plain; charset=utf-8\\r\\nContent-Length: 30\\r\\nConnection: close\\r\\n\\r\\nECS Linuxtips ativo recurso UP'; } | nc -l -p 8080; done"]