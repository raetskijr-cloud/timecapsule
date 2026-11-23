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
