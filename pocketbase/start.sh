#!/bin/sh
# Запуск PocketBase в контейнере: схема, демонстрационные данные, сервер.
set -e

# Пароль суперпользователя (панель /_/) задаётся переменной окружения
# на хостинге, в репозитории его нет. Без переменной — учебный пароль.
PB_SUPERUSER_PASSWORD="${PB_SUPERUSER_PASSWORD:-Autoservice2026}"
export PB_SUPERUSER_PASSWORD

# При первом запуске команда применяет миграцию и создаёт суперпользователя.
./pocketbase superuser upsert admin@autoservice.local "$PB_SUPERUSER_PASSWORD"

# Демонстрационные данные заливаются через API на внутреннем порту,
# пока сервер ещё не открыт снаружи. Если база не пустая, seed.mjs её не трогает.
./pocketbase serve --http 127.0.0.1:8091 &
PID=$!
until wget -q -O /dev/null http://127.0.0.1:8091/api/health 2>/dev/null; do sleep 0.5; done
API_URL=http://127.0.0.1:8091 node seed.mjs
kill "$PID"
wait "$PID" || true

# Хостинг передаёт порт в переменной PORT.
exec ./pocketbase serve --http "0.0.0.0:${PORT:-8090}"
