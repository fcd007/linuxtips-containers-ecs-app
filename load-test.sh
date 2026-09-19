#!/bin/bash

ALB_URL=""
HOST_HEADER="chip.linuxtips.demo"

CONCURRENCY=1000
DURATION=900

echo "=========================================="
echo "       ECS CPU LOAD TEST"
echo "=========================================="
echo "ALB:          $ALB_URL"
echo "Host:         $HOST_HEADER"
echo "Concorrência: $CONCURRENCY"
echo "Duração:      ${DURATION}s"
echo "=========================================="

END_TIME=$((SECONDS + DURATION))
REQUESTS=0

while [ $SECONDS -lt $END_TIME ]; do

    for ((i=1; i<=CONCURRENCY; i++)); do

        curl -s \
            --connect-timeout 2 \
            --max-time 30 \
            -H "Host: $HOST_HEADER" \
            "$ALB_URL/" \
            > /dev/null &

        ((REQUESTS++))

    done

    wait

    echo "$(date '+%H:%M:%S') - Requests enviados: $REQUESTS"

done

echo ""
echo "=========================================="
echo "Teste finalizado"
echo "Requests enviados: $REQUESTS"
echo "=========================================="