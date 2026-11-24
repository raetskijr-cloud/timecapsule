#!/bin/bash
# health-poll.sh <url> [секунд] [интервал]: /health раз в секунду с отметкой UTC (задание 11, перезагрузка базы).
URL=${1:?}; N=${2:-60}; I=${3:-1}
for _ in $(seq "$N"); do
  printf '%s ' "$(date -u +%H:%M:%S)"
  curl -s -m 5 -o /tmp/h.$$ -w '%{http_code} ' "$URL"; head -c 120 /tmp/h.$$ | tr '\n' ' '; echo
  sleep "$I"
done; rm -f /tmp/h.$$
