#!/usr/bin/env bash
# Prepara a Raspberry Pi (Pi OS Lite 64-bit) para rodar o servidor.
# Uso: sudo DATA_DIR=/srv/data APPS_DIR=/srv/apps ./scripts/01-preparar-pi.sh
set -euo pipefail

DATA_DIR="${DATA_DIR:-/srv/data}"
APPS_DIR="${APPS_DIR:-/srv/apps}"

[[ $EUID -eq 0 ]] || { echo "Rode com sudo."; exit 1; }

arch="$(uname -m)"
if [[ "$arch" != "aarch64" && "$arch" != "x86_64" ]]; then
  echo "SO $arch detectado. Instale o Raspberry Pi OS Lite 64-bit (aarch64)." >&2
  exit 1
fi

echo "==> Atualizando pacotes"
apt-get update
apt-get -y full-upgrade
apt-get -y install curl ca-certificates git jq

echo "==> Swap em zram"
if swapon --show=NAME --noheadings | grep -q zram; then
  echo "zram já ativo, mantendo."
else
  apt-get -y install zram-tools
  cat > /etc/default/zramswap <<'EOF'
ALGO=zstd
PERCENT=50
PRIORITY=100
EOF
  systemctl restart zramswap
  # O swapfile em disco desgasta o SD; desliga se existir.
  if systemctl list-unit-files | grep -q '^dphys-swapfile'; then
    dphys-swapfile swapoff || true
    systemctl disable --now dphys-swapfile || true
  fi
fi

echo "==> cgroup de memória (para mem_limit dos containers)"
precisa_reboot=0
cmdline=""
for f in /boot/firmware/cmdline.txt /boot/cmdline.txt; do
  [[ -f "$f" ]] && { cmdline="$f"; break; }
done
if [[ -n "$cmdline" ]]; then
  if ! grep -q 'cgroup_enable=memory' "$cmdline"; then
    cp "$cmdline" "$cmdline.bak"
    sed -i '1 s/$/ cgroup_enable=memory cgroup_memory=1/' "$cmdline"
    precisa_reboot=1
    echo "Adicionado em $cmdline (backup em $cmdline.bak)."
  else
    echo "Já habilitado."
  fi
else
  echo "cmdline.txt não encontrado (não é Raspberry Pi?), pulando."
fi

echo "==> Diretórios de dados"
mkdir -p "$DATA_DIR"/{tailscale,postgres,backups,uptime-kuma} "$APPS_DIR"
if ! findmnt -n "$DATA_DIR" >/dev/null && ! findmnt -n "$(dirname "$DATA_DIR")" >/dev/null; then
  echo "AVISO: $DATA_DIR está no cartão SD. Recomendo montar um SSD USB nele (ver README)."
fi

echo
echo "Pronto. Próximo passo: sudo ./scripts/02-instalar-casaos.sh"
[[ $precisa_reboot -eq 1 ]] && echo ">>> Reinicie a Pi antes (sudo reboot) para ativar o cgroup de memória."
exit 0
