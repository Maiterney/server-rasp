#!/usr/bin/env bash
# Atualiza apps manualmente (puxa imagem nova e recria o container).
# Uso: ./scripts/atualizar-app.sh <nome>   → um app de $APPS_DIR
#      ./scripts/atualizar-app.sh --todos  → pede ao Watchtower para checar todos agora
set -euo pipefail

APPS_DIR="${APPS_DIR:-/srv/apps}"
REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
alvo="${1:?nome do app ou --todos}"

if [[ "$alvo" == "--todos" ]]; then
  token="$(grep -E '^WATCHTOWER_TOKEN=' "$REPO_DIR/stacks/base/.env" | cut -d= -f2-)"
  curl -fsS -H "Authorization: Bearer $token" http://localhost:8082/v1/update
  echo "Watchtower disparado. Acompanhe: docker logs -f watchtower"
  exit 0
fi

compose="$APPS_DIR/$alvo/docker-compose.yml"
[[ -f "$compose" ]] || { echo "App não encontrado: $compose"; exit 1; }

antes="$(docker inspect -f '{{.Image}}' "$alvo" 2>/dev/null || true)"
docker compose -f "$compose" pull
docker compose -f "$compose" up -d
depois="$(docker inspect -f '{{.Image}}' "$alvo")"
docker image prune -f >/dev/null

if [[ "$antes" == "$depois" ]]; then
  echo "$alvo já estava na última versão."
else
  echo "$alvo atualizado: ${antes:7:12} → ${depois:7:12}"
fi
