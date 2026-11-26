#!/usr/bin/env bash
# Instala o CasaOS (painel web). O instalador oficial também instala o Docker.
# Uso: sudo ./scripts/02-instalar-casaos.sh
set -euo pipefail

[[ $EUID -eq 0 ]] || { echo "Rode com sudo."; exit 1; }

if systemctl list-unit-files | grep -q '^casaos'; then
  echo "CasaOS já instalado."
else
  curl -fsSL https://get.casaos.io | bash
fi

# Permite usar docker sem sudo para o usuário que chamou o script.
if [[ -n "${SUDO_USER:-}" ]]; then
  usermod -aG docker "$SUDO_USER"
  echo "Usuário $SUDO_USER adicionado ao grupo docker (vale no próximo login)."
fi

ip="$(hostname -I | awk '{print $1}')"
echo
echo "Painel: http://$ip  (crie o usuário no primeiro acesso)"
echo "Próximo passo: configurar stacks/base/.env e rodar  docker compose -f stacks/base/docker-compose.yml up -d"
