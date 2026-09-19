FROM alpine:3.22

RUN apk add --no-cache python3 \
    && addgroup -S appgroup \
    && adduser -S -G appgroup appuser

WORKDIR /app

COPY server.py /app/server.py

RUN chown -R appuser:appgroup /app

USER appuser

EXPOSE 8080

CMD ["python3", "/app/server.py"]