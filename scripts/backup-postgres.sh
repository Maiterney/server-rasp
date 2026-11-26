#!/usr/bin/env bash
# Dump de todos os bancos do Postgres compartilhado; mantém os últimos N dias.
# Cron diário (crontab -e):  30 3 * * *  /home/pi/server-rasp/scripts/backup-postgres.sh
set -euo pipefail

DATA_DIR="${DATA_DIR:-/srv/data}"
DIAS="${DIAS:-7}"
REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
admin="$(grep -E '^PG_ADMIN_USER=' "$REPO_DIR/stacks/base/.env" 2>/dev/null | cut -d= -f2- || true)"
admin="${admin:-admin}"

destino="$DATA_DIR/backups"
mkdir -p "$destino"
arquivo="$destino/postgres-$(date +%F_%H%M).sql.gz"

docker exec postgres pg_dumpall -U "$admin" | gzip > "$arquivo"
find "$destino" -name 'postgres-*.sql.gz' -mtime +"$DIAS" -delete
echo "Backup: $arquivo ($(du -h "$arquivo" | cut -f1))"
