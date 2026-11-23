#!/bin/bash
# Убирает временный NAT Gateway, созданный scripts/nat-up.sh (LR3, вариант B).
#   1. удаляет маршрут; 2. удаляет NAT Gateway; 3. ждёт состояния deleted;
#   4. освобождает Elastic IP с повторами (пауза растёт: 5, 10, 20, 40 с; до 6 попыток).
# Elastic IP освобождается только после удаления шлюза: пока шлюз использует адрес, AWS отвечает
# ошибкой AuthFailure/InvalidIPAddress.InUse.
set -euo pipefail

AWS_REGION=eu-central-1
STATE_FILE="$(dirname "$0")/nat-state.json"
export AWS_REGION AWS_PAGER=""

if [ ! -f "$STATE_FILE" ]; then
  echo "Файл состояния $STATE_FILE не найден: нечего убирать." >&2
  exit 1
fi

NAT_ID=$(jq -r .nat_gateway_id "$STATE_FILE")
ALLOC_ID=$(jq -r .allocation_id "$STATE_FILE")
RT_ID=$(jq -r .route_table_id "$STATE_FILE")
ROUTE_ADDED=$(jq -r .route_added "$STATE_FILE")

echo "step 1: удаление маршрута 0.0.0.0/0 из $RT_ID"
if [ "$ROUTE_ADDED" = "true" ]; then
  aws ec2 delete-route --route-table-id "$RT_ID" --destination-cidr-block 0.0.0.0/0
else
  echo "        маршрут не создавался, пропуск"
fi

echo "step 2: удаление NAT Gateway $NAT_ID"
aws ec2 delete-nat-gateway --nat-gateway-id "$NAT_ID" --query NatGatewayId --output text >/dev/null

echo "step 3: ожидание состояния deleted"
aws ec2 wait nat-gateway-deleted --nat-gateway-ids "$NAT_ID"

echo "step 4: освобождение Elastic IP $ALLOC_ID"
DELAY=5
for ATTEMPT in 1 2 3 4 5 6; do
  if aws ec2 release-address --allocation-id "$ALLOC_ID" 2>/dev/null; then
    echo "        адрес освобождён (попытка $ATTEMPT)"
    rm -f "$STATE_FILE"
    echo "Готово. NAT и Elastic IP удалены."
    exit 0
  fi
  echo "        адрес ещё не отпущен (попытка $ATTEMPT из 6), повтор через $DELAY с"
  sleep "$DELAY"
  [ "$DELAY" -lt 40 ] && DELAY=$((DELAY * 2))
done
echo "Не удалось освободить $ALLOC_ID за 6 попыток; файл состояния оставлен, повторите запуск." >&2
exit 1
