#!/usr/bin/env bash
# Cria um banco + usuário dedicados no Postgres compartilhado e imprime a DATABASE_URL.
# Uso: ./scripts/novo-banco.sh <nome>
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ENV_FILE="$REPO_DIR/stacks/base/.env"
admin="admin"
[[ -f "$ENV_FILE" ]] && admin="$(grep -E '^PG_ADMIN_USER=' "$ENV_FILE" | cut -d= -f2- || true)"
admin="${admin:-admin}"

nome="${1:?nome do banco}"
nome="${nome//-/_}"   # minha-api → minha_api
[[ "$nome" =~ ^[a-z][a-z0-9_]*$ ]] || { echo "Nome inválido: use minúsculas, números e _ (ex.: minha_api)"; exit 1; }
usuario="${nome}_user"
senha="$(openssl rand -hex 16)"

psql() { docker exec -i postgres psql -v ON_ERROR_STOP=1 -U "$admin" -d postgres "$@"; }

if psql -tAc "SELECT 1 FROM pg_database WHERE datname='$nome'" | grep -q 1; then
  echo "Banco $nome já existe."; exit 1
fi

psql <<SQL
CREATE ROLE "$usuario" LOGIN PASSWORD '$senha';
CREATE DATABASE "$nome" OWNER "$usuario";
REVOKE ALL ON DATABASE "$nome" FROM PUBLIC;
SQL

ip="$(hostname -I | awk '{print $1}')"
echo
echo "Dentro de containers (rede infra):"
echo "  DATABASE_URL=postgres://$usuario:$senha@postgres:5432/$nome"
echo "Do seu PC (LAN/Tailscale):"
echo "  postgres://$usuario:$senha@$ip:5432/$nome"
