#!/bin/bash
# LR5, задание 9 (запускать на app): перенос данных с db-server в RDS.
# Использование: migrate.sh <endpoint>. Приложение в браузере не открывать до переключения DNS (задание 10).
set -euo pipefail
EP=${1:?endpoint базы timecapsule-dev-rds}
OLD=db.timecapsule.internal
PW=$(sudo grep '^DB_PASSWORD=' /var/www/timecapsule/.env | cut -d= -f2-)
grep -v "^$OLD:5432:\*:timecapsule:" ~/.pgpass > ~/.pgpass.new || true
printf '%s:5432:*:timecapsule:%s\n' "$OLD" "$PW" >> ~/.pgpass.new; mv ~/.pgpass.new ~/.pgpass; chmod 600 ~/.pgpass; unset PW
count() { psql -h "$1" -U timecapsule -d timecapsule -At -c "SELECT 'users='||count(*) FROM users UNION ALL SELECT 'capsules='||count(*) FROM capsules"; }
cd ~
echo "[1/5] выгрузка с $OLD"
pg_dump -h $OLD -U timecapsule -d timecapsule --no-owner --no-privileges -f timecapsule.sql
ls -l timecapsule.sql
echo "[2/5] загрузка в $EP"
psql -h "$EP" -U timecapsule -d timecapsule -v ON_ERROR_STOP=1 --single-transaction -q -f timecapsule.sql
echo "[3/5] счётчики, старая база"; A=$(count $OLD); echo "$A"
echo "[4/5] счётчики, RDS";         B=$(count "$EP"); echo "$B"
[ "$A" = "$B" ] && echo "совпадают" || { echo "РАСХОЖДЕНИЕ"; exit 1; }
echo "[5/5] удаление выгрузки (в ней хеши паролей)"
shred -u timecapsule.sql 2>/dev/null || rm -f timecapsule.sql
ls timecapsule.sql 2>&1 || true
