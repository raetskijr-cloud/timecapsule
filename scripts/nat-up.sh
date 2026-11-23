#!/bin/bash
# Поднимает временный NAT Gateway для приватной подсети (LR3, вариант B).
#   1. выделяет Elastic IP; 2. создаёт NAT Gateway в public-a; 3. ждёт состояния available;
#   4. добавляет маршрут 0.0.0.0/0 в private-rt; 5. записывает идентификаторы в scripts/nat-state.json.
# Состояние читает scripts/nat-down.sh. Требуются AWS CLI и jq (есть в CloudShell и Git Bash).
# Запуск: AWS_PROFILE=<профиль> scripts/nat-up.sh
set -euo pipefail

AWS_REGION=eu-central-1
PUBLIC_SUBNET_ID=subnet-0f0cc660c40804fdb      # timecapsule-dev-public-a  (10.14.0.0/24)
PRIVATE_RT_ID=rtb-02c5a2fd7505f6bd5            # timecapsule-dev-private-rt
OWNER=danilaraetchi
STATE_FILE="$(dirname "$0")/nat-state.json"
export AWS_REGION AWS_PAGER=""

TAGS="{Key=Project,Value=timecapsule},{Key=Environment,Value=dev},{Key=Owner,Value=$OWNER},{Key=Lab,Value=lab3},{Key=Purpose,Value=coursework}"

if [ -f "$STATE_FILE" ]; then
  echo "Файл состояния $STATE_FILE уже существует: NAT уже поднят или не был убран (запустите scripts/nat-down.sh)." >&2
  exit 1
fi

echo "step 1: выделение Elastic IP (timecapsule-dev-nat-a-eip)"
ALLOC_ID=$(aws ec2 allocate-address --domain vpc \
  --tag-specifications "ResourceType=elastic-ip,Tags=[{Key=Name,Value=timecapsule-dev-nat-a-eip},$TAGS]" \
  --query AllocationId --output text)
echo "        AllocationId: $ALLOC_ID"

echo "step 2: создание NAT Gateway timecapsule-dev-nat-a в public-a"
NAT_ID=$(aws ec2 create-nat-gateway --subnet-id "$PUBLIC_SUBNET_ID" --allocation-id "$ALLOC_ID" \
  --connectivity-type public \
  --tag-specifications "ResourceType=natgateway,Tags=[{Key=Name,Value=timecapsule-dev-nat-a},$TAGS]" \
  --query NatGateway.NatGatewayId --output text)
echo "        NatGatewayId: $NAT_ID"

# идентификаторы записываются сразу, чтобы nat-down.sh мог убрать ресурсы даже после сбоя на следующих шагах
jq -n --arg nat "$NAT_ID" --arg alloc "$ALLOC_ID" --arg rt "$PRIVATE_RT_ID" --arg at "$(date -u +%FT%TZ)" \
  '{nat_gateway_id: $nat, allocation_id: $alloc, route_table_id: $rt, route_added: false, created_at: $at}' > "$STATE_FILE"

echo "step 3: ожидание состояния available (обычно 1-3 минуты)"
aws ec2 wait nat-gateway-available --nat-gateway-ids "$NAT_ID"

echo "step 4: маршрут 0.0.0.0/0 -> $NAT_ID в private-rt"
aws ec2 create-route --route-table-id "$PRIVATE_RT_ID" --destination-cidr-block 0.0.0.0/0 \
  --nat-gateway-id "$NAT_ID" --query Return --output text >/dev/null
jq '.route_added = true' "$STATE_FILE" > "$STATE_FILE.tmp" && mv "$STATE_FILE.tmp" "$STATE_FILE"

echo "step 5: состояние сохранено в $(basename "$STATE_FILE")"
PUBLIC_IP=$(aws ec2 describe-addresses --allocation-ids "$ALLOC_ID" --query 'Addresses[0].PublicIp' --output text)
echo "Готово. NAT $NAT_ID доступен, внешний адрес $PUBLIC_IP. Не забудьте scripts/nat-down.sh (NAT оплачивается почасово)."
