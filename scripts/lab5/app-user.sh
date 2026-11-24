#!/bin/bash
# LR5, задание 8 (запускать на app): пользователь timecapsule и база timecapsule в RDS.
# Использование: app-user.sh <endpoint>
# Пароль берётся из DB_PASSWORD в .env внутри psql (обратные кавычки) и не попадает ни в аргументы, ни в вывод.
# Интерактивный \password по ssh без tty не работает, поэтому ALTER USER с переменной.
set -euo pipefail
EP=${1:?endpoint базы timecapsule-dev-rds}
echo "[1/3] ~/.pgpass для timecapsule на $EP"
PW=$(sudo grep '^DB_PASSWORD=' /var/www/timecapsule/.env | cut -d= -f2-)
grep -v "^$EP:5432:\*:timecapsule:" ~/.pgpass > ~/.pgpass.new || true
printf '%s:5432:*:timecapsule:%s\n' "$EP" "$PW" >> ~/.pgpass.new; mv ~/.pgpass.new ~/.pgpass; chmod 600 ~/.pgpass
unset PW
echo "[2/3] CREATE USER, GRANT, CREATE DATABASE (dbadmin, база postgres)"
psql -h "$EP" -U dbadmin -d postgres -v ON_ERROR_STOP=1 <<'SQL'
\set QUIET on
\set pw `sudo grep '^DB_PASSWORD=' /var/www/timecapsule/.env | cut -d= -f2-`
CREATE USER timecapsule;
ALTER USER timecapsule PASSWORD :'pw';
\unset pw
\set QUIET off
GRANT timecapsule TO dbadmin;
CREATE DATABASE timecapsule OWNER timecapsule;
SQL
echo "[3/3] проверка"
psql -h "$EP" -U dbadmin -d postgres -c '\du timecapsule' -c '\l timecapsule'
