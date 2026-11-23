#!/bin/bash
# Выпуск новой версии TimeCapsule (LR2, вариант B).
# Запуск на сервере: ~/deploy.sh            (на сервере ~/deploy.sh - символическая ссылка на этот файл)
# Запуск с ноутбука: ssh -i ~/.ssh/danilaraetchi-keypair.pem ec2-user@<IP> ./deploy.sh
# Пробный запуск:    ./deploy.sh --dry-run  (только git fetch и список отличий, ничего не меняется)
set -euo pipefail

APP_DIR=/var/www/timecapsule
LOG_FILE="$HOME/deploy.log"
MODE=release
[ "${1:-}" = "--dry-run" ] && MODE=dry-run

step() { echo "[$1/5] $2"; }
fail() { echo "ОШИБКА: шаг не выполнен (строка $1). Деплой остановлен." >&2; log_line "FAILED"; exit 1; }
log_line() { printf '%s mode=%s result=%s commit=%s\n' "$(date -u +%FT%TZ)" "$MODE" "$1" \
    "$(git -C "$APP_DIR" log -1 --format=%h 2>/dev/null || echo -)" >> "$LOG_FILE"; }
trap 'fail $LINENO' ERR

cd "$APP_DIR"

if [ "$MODE" = "dry-run" ]; then
  step 1 "Проверка удалённого репозитория (git fetch), без изменения файлов"
  git fetch origin
  git diff --stat HEAD..origin/main
  echo "Пробный запуск завершён. На сервере коммит: $(git log -1 --oneline)"
  log_line "ok"
  exit 0
fi

step 1 "Забираем новый код из GitHub"
git pull --ff-only

step 2 "Устанавливаем библиотеки"
composer install --no-dev --optimize-autoloader --no-interaction

step 3 "Создаём недостающие таблицы"
php bin/init-db.php

step 4 "Перезапускаем PHP-FPM"
sudo systemctl reload php-fpm

step 5 "Фиксируем результат"
echo "Готово. На сервере коммит: $(git log -1 --oneline)"
log_line "ok"
