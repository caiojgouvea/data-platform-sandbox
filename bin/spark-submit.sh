#!/usr/bin/env bash
set -euo pipefail

# Uso: bin/spark-submit.sh src/dps/jobs/hello_spark.py [args...]
APP_ABS="$(realpath "${1:?Informe o caminho do .py}")"
APP_DIR="$(dirname "$APP_ABS")"
APP_BASE="$(basename "$APP_ABS")"
shift || true

# ajuste o nome do serviço abaixo para o seu serviço Spark no docker-compose
docker compose run --rm \
  -v "$APP_DIR":/app \
  -w /app \
  spark \
  spark-submit /app/"$APP_BASE" "$@"
