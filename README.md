# server-rasp

Servidor caseiro de testes com painel web (CasaOS). Serve para subir backends e bancos e para atualizar apps automaticamente a partir do GitHub.
A visão completa e as decisões estão em [docs/PRD.md](docs/PRD.md).

Fase atual: **Raspberry Pi 3** (Raspberry Pi OS Lite **64-bit**).

## O que roda

| Serviço | Porta | Para quê |
|---|---|---|
| CasaOS | 80 | Painel: apps, containers, arquivos, recursos |
| Postgres 16 | 5432 | Banco compartilhado (um banco e um usuário por app) |
| Adminer | 8081 | Ver e editar tabelas pelo navegador |
| Watchtower | 8082 (API) | Atualiza apps quando sai imagem nova |
| Tailscale | — | Acesso de fora de casa, sem abrir porta |
| Uptime Kuma (opcional) | 3001 | Monitor e alertas |

## Instalação na Pi

1. Grave o **Raspberry Pi OS Lite (64-bit)** com o Raspberry Pi Imager. Nas opções, já defina usuário, Wi-Fi e SSH.
2. (Recomendado) Monte um SSD USB em `/srv/data`:
   ```bash
   lsblk                                   # descubra o disco, ex.: /dev/sda
   sudo mkfs.ext4 /dev/sda1                # APAGA o disco
   sudo mkdir -p /srv/data
   echo "UUID=$(sudo blkid -s UUID -o value /dev/sda1) /srv/data ext4 defaults,noatime,nofail 0 2" | sudo tee -a /etc/fstab
   sudo mount -a
   ```
3. Clone o repo e prepare o sistema:
   ```bash
   git clone <url-deste-repo> ~/server-rasp && cd ~/server-rasp
   sudo ./scripts/01-preparar-pi.sh
   sudo reboot                             # se o script pedir
   sudo ./scripts/02-instalar-casaos.sh
   ```
4. Configure e suba a stack base:
   ```bash
   cp stacks/base/.env.example stacks/base/.env
   nano stacks/base/.env                   # TS_AUTHKEY, PG_ADMIN_PASSWORD, WATCHTOWER_TOKEN
   # para gerar senhas: openssl rand -hex 24
   docker compose -f stacks/base/docker-compose.yml --env-file stacks/base/.env up -d
   ```
5. (Opcional) Monitor: `docker compose -f stacks/aux/docker-compose.yml up -d`

Depois disso, o painel abre em `http://<ip-da-pi>` ou, pelo Tailscale, em `http://raspberry-pi`.

## Subir um app

No repositório do app (precisa ter um `Dockerfile`):

1. Copie `templates/github-actions/docker-image.yml` para `.github/workflows/docker-image.yml` e faça o push.
   A imagem vai para `ghcr.io/<usuario>/<repo>:latest`.
2. Se o pacote for privado, preencha `GHCR_USER` e `GHCR_TOKEN` (um PAT com `read:packages`) no `.env` da base.
   Faça também `docker login ghcr.io` na Pi.

Na Pi:

```bash
./scripts/novo-banco.sh minha-api                # se precisar de banco → copia a DATABASE_URL
./scripts/novo-app.sh minha-api ghcr.io/usuario/minha-api:latest 3000   # responda "n" se ainda for preencher o .env
nano /srv/apps/minha-api/.env                    # cole a DATABASE_URL e as outras variáveis
docker compose -f /srv/apps/minha-api/docker-compose.yml up -d
```

O app aparece no CasaOS junto dos outros containers.

## Atualizar apps

- **Automático:** depois de um push na `main`, o GitHub Actions gera a imagem nova e o Watchtower aplica em até 5 minutos.
  Para desligar a atualização automática de um app, remova o label `com.centurylinklabs.watchtower.enable` do compose dele.
- **Manual, um app:** `./scripts/atualizar-app.sh minha-api`
- **Manual, todos agora:** `./scripts/atualizar-app.sh --todos`

## Acesso de fora

- O painel, o Adminer e o Postgres ficam acessíveis só na LAN e no Tailscale. Instale o app Tailscale nos seus aparelhos.
- Para expor **uma API** publicamente (outros aparelhos sem Tailscale), libere o Funnel na ACL da tailnet e rode:
  ```bash
  docker exec tailscale tailscale funnel --bg 3000
  # → https://raspberry-pi.<sua-tailnet>.ts.net
  ```

## Backup

```bash
./scripts/backup-postgres.sh          # gera /srv/data/backups/postgres-*.sql.gz e mantém 7 dias
crontab -e                            # 30 3 * * *  /home/<usuario>/server-rasp/scripts/backup-postgres.sh
```

## Limites da Pi 3

Cabem 2–4 APIs leves (Node, Python, Go) junto com a stack base, que usa ~450 MB.
Java, .NET, Mongo e stacks grandes ficam para o mini PC (Fase 2 no PRD). Os mesmos arquivos funcionam lá.
