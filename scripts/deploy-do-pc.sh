#!/usr/bin/env bash
# Roda NO SEU PC. Envia o código de um app para a Pi, gera a imagem lá e recria o container.
# Serve para apps que ainda não estão no GitHub com o workflow de imagem.
# Uso: ./scripts/deploy-do-pc.sh <pasta-com-Dockerfile> <nome-do-app>
#  ex: ./scripts/deploy-do-pc.sh ../lanche-pdv/server lanche-pdv-server
# Pi: PI=maiterney@192.168.1.64 (padrão) ou outra via variável PI.
set -euo pipefail

PI="${PI:-maiterney@192.168.1.64}"
src="${1:?pasta com Dockerfile}"
app="${2:?nome do app (pasta em /srv/apps)}"
[[ -f "$src/Dockerfile" ]] || { echo "Sem Dockerfile em $src"; exit 1; }

excl=()
[[ -f "$src/.dockerignore" ]] && excl=(--exclude-from="$src/.dockerignore")

echo "==> Enviando código para $PI"
ssh "$PI" "mkdir -p ~/builds/$app"
rsync -a --delete "${excl[@]}" "$src"/ "$PI:~/builds/$app/"

echo "==> Gerando imagem $app:local na Pi"
ssh "$PI" "set -e
  cd ~/builds/$app && docker build -q -t $app:local . >/dev/null
  cd /srv/apps/$app && docker compose up -d 2>&1 | tail -1
  docker image prune -f >/dev/null
  sleep 8
  docker ps --filter name=^$app\$ --format '{{.Names}}: {{.Status}}'"
