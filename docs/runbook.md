# Руководство по эксплуатации (runbook)

Для стенда `timecapsule-dev` в `eu-central-1`. Раздел каждой лабораторной работы дополняется.

## LR2. Один экземпляр `webserver`

| Действие | Команда или шаги |
| --- | --- |
| Запуск | `aws ec2 start-instances --instance-ids <id>`; публичный IP меняется, взять новый из `describe-instances` |
| После запуска | в `/var/www/timecapsule/.env` заменить `APP_URL=http://<новый IP>`, выполнить `sudo systemctl reload php-fpm` |
| Проверка | `curl http://<IP>/health` возвращает `{"status":"ok","db":"ok",...}` |
| Выпуск версии | `git push`, затем `ssh -i ~/.ssh/danilaraetchi-keypair.pem ec2-user@<IP> ./deploy.sh` |
| Откат | `git revert --no-edit HEAD`, `git push`, повторный `./deploy.sh`; на сервере код не правится |
| Журнал выпусков | `~/deploy.log` на сервере |
| Остановка | `aws ec2 stop-instances --instance-ids <id> --region eu-central-1`; экземпляр не удаляется |
| Если SSH не пускает | в Security Group `webserver-sg` заменить источник правила SSH на текущий `My IP` |

## LR3. VPC `timecapsule-dev-vpc`

| Действие | Команда или шаги |
| --- | --- |
| Запуск (порядок) | `db`, затем `app`, затем `bastion`: `aws ec2 start-instances --instance-ids <id>` |
| После запуска | `HostName` bastion в `~/.ssh/config` заменить на новый публичный IP; приватные адреса `app` и `db` не меняются |
| Проверка | `curl http://<EIP app>/health` возвращает `"db":"ok"` |
| Выпуск версии | `git push`, затем `ssh app ./deploy.sh` (через bastion, `ProxyJump`) |
| Правка `.env` на сервере | после `sed -i` выполнить `sudo chgrp apache /var/www/timecapsule/.env` и `sudo systemctl reload php-fpm` |
| Обновление пакетов на `db` | `scripts/nat-up.sh`, `ssh db`, `sudo dnf -y update`, `scripts/nat-down.sh` (CloudShell или Git Bash; нужны `jq` и AWS CLI) |
| Если `nat-down.sh` прерван | запустить повторно: идентификаторы лежат в `scripts/nat-state.json`; иначе удалить вручную маршрут, NAT Gateway, затем Elastic IP |
| Остановка | остановить `bastion`, `app`, `db`; Elastic IP `timecapsule-dev-app-eip` остаётся привязанным (оплата $0,005 в час) |
| Контроль платного | `aws ec2 describe-nat-gateways --filter Name=state,Values=available` пусто; `aws ec2 describe-addresses` содержит только адрес `app` |

## LR5. База `timecapsule-dev-rds` (Amazon RDS)

| Действие | Команда или шаги |
| --- | --- |
| Запуск (порядок) | сначала база: `aws rds start-db-instance --db-instance-identifier timecapsule-dev-rds`, до `available` около 5 минут; затем `app`, затем `bastion` |
| Остановка (порядок) | `bastion`, `app`, затем база: `aws rds stop-db-instance --db-instance-identifier timecapsule-dev-rds` (около 8 минут до `stopped`) |
| Ночная остановка | расписание `timecapsule-dev-rds-nightly-stop`, `cron(0 23 * * ? *)`, `Europe/Chisinau`; если база уже `stopped`, ошибка `InvalidDBInstanceState` безвредна |
| Самозапуск через 7 дней | остановленная база запускается AWS сама; расписание останавливает её снова в 23:00; проверять `aws rds describe-db-instances` после перерыва |
| Проверка | `curl http://<EIP app>/health` возвращает `"db":"ok"`; `dig +short db.timecapsule.internal` с `app` возвращает endpoint и адрес из `10.14.10.0/24` |
| Подключение для разбора | с `app`: `psql -h db.timecapsule.internal -U timecapsule -d timecapsule` (пароль в `~/.pgpass`) |
| Восстановление | `Restore to point in time` создаёт НОВУЮ базу; после проверки записать новый endpoint в CNAME `db` (одной пачкой `DELETE` + `CREATE`) |
| Контроль платного | `aws rds describe-db-instances` не более 2 экземпляров и ни одного `lab5-*` после Части 1; у `timecapsule-dev-rds` статус `stopped` |
