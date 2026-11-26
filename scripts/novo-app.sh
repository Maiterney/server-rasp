#!/usr/bin/env bash
# Cria e sobe um app a partir de uma imagem Docker.
# Uso: ./scripts/novo-app.sh <nome> <imagem> <porta-host> [porta-interna] [mem]
#  ex: ./scripts/novo-app.sh minha-api ghcr.io/usuario/minha-api:latest 3000
set -euo pipefail

APPS_DIR="${APPS_DIR:-/srv/apps}"
REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"

nome="${1:?nome do app}"
imagem="${2:?imagem (ex.: ghcr.io/usuario/app:latest)}"
porta="${3:?porta no host}"
porta_interna="${4:-$porta}"
mem="${5:-192m}"

[[ "$nome" =~ ^[a-z0-9][a-z0-9_-]+$ ]] || { echo "Nome inválido: use minúsculas, números, - ou _"; exit 1; }
dir="$APPS_DIR/$nome"
[[ -e "$dir" ]] && { echo "$dir já existe."; exit 1; }

if ss -ltn "( sport = :$porta )" 2>/dev/null | grep -q LISTEN; then
  echo "Porta $porta já está em uso."; exit 1
fi

mkdir -p "$dir"
sed -e "s|__NOME__|$nome|g" -e "s|__IMAGEM__|$imagem|g" \
    -e "s|__PORTA_INTERNA__|$porta_interna|g" -e "s|__PORTA__|$porta|g" \
    -e "s|__MEM__|$mem|g" \
    "$REPO_DIR/stacks/apps/_modelo/docker-compose.yml" > "$dir/docker-compose.yml"
touch "$dir/.env"
chmod 600 "$dir/.env"

echo "Criado $dir"
echo "Variáveis do app vão em $dir/.env (ex.: DATABASE_URL de ./scripts/novo-banco.sh $nome)"
read -r -p "Subir agora? [S/n] " r
if [[ "${r,,}" != "n" ]]; then
  docker compose -f "$dir/docker-compose.yml" up -d
  echo "Rodando em http://$(hostname -I | awk '{print $1}'):$porta"
fi
