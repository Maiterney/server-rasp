# PRD — server-rasp: servidor caseiro de testes

**Status:** Fase 1 (Raspberry Pi 3) em implementação · Fase 2 (mini PC) em espera
**Atualizado:** 2026-11-26

## 1. Problema

Preciso de um lugar sempre ligado para subir backends e bancos de dados de teste e para atualizar apps.
Também preciso de uma interface web amigável, no estilo do Umbrel, para ver e gerenciar tudo.
O umbrelOS não suporta a Raspberry Pi 3, e a Pi 3 (1 GB de RAM) não aguenta muitos projetos ao mesmo tempo.

## 2. Objetivos

- Painel web para ver containers, uso de recursos e logs, e para instalar apps.
- Subir um backend novo em poucos minutos, a partir de uma imagem Docker.
- Atualizar apps sem entrar por SSH: o push no GitHub gera uma imagem nova e o servidor atualiza (sozinho ou com um comando).
- Bancos de teste baratos em RAM (um Postgres compartilhado).
- Acesso de fora de casa sem abrir porta no roteador.
- Configuração versionada neste repositório, migrável da Pi para o mini PC sem retrabalho.

### Fora do escopo

- Painel próprio escrito do zero (estimado em 80–150 h; foi descartado em favor do CasaOS).
- Produção, alta disponibilidade, clusters.
- Build de imagens dentro do servidor (o build acontece no GitHub Actions).

## 3. Decisões tomadas

Vêm dos protótipos em `../prototipos/server-rasp-*`.

| Tema | Decisão | Motivo |
|---|---|---|
| Painel | **CasaOS** | Experiência parecida com a do Umbrel, roda em Pi 3 arm64 (~120 MB) e em x86 |
| Deploy / update | **Build no GitHub Actions → GHCR → servidor puxa** (Watchtower) | Compilar na Pi 3 é lento e estoura a RAM |
| Bancos | **Um Postgres compartilhado** + Adminer, com um banco e um usuário por app | ~100 MB no total, em vez de um container por app |
| Acesso | **Tailscale** em container: painel privado, API pública opcional via Funnel | Nada exposto na internet, funciona atrás de CGNAT |
| SO | **Raspberry Pi OS Lite 64-bit** (+ SSD USB, recomendado) | Imagens atuais exigem arm64; o SD se desgasta com banco |
| Máquina principal | **Mini PC corporativo usado** (i5 6ª–8ª ger., 16 GB, SSD) | 16x a RAM da Pi 3, x86, ~R$ 700–1.300 (preços a confirmar) |
| Software | **Montar** (Debian/Ubuntu + CasaOS), não comprar aparelho pronto | O "pronto" é software livre; aparelho fechado custa de 3 a 5 vezes mais |
| Pi 3 no longo prazo | **Auxiliar da rede**: monitor (Uptime Kuma), backup, depois Pi-hole | Vigiar o servidor de fora dele e guardar backups separados |

## 4. Fases

### Fase 1: Raspberry Pi 3 (agora)

A Pi 3 faz os dois papéis enquanto o mini PC não chega: é servidor de testes leve e já fica preparada para o papel de auxiliar.

Entregáveis (neste repo):
- `scripts/01-preparar-pi.sh`: checa o 64-bit, faz o update, cria swap zram, habilita o cgroup de memória e cria os diretórios de dados.
- `scripts/02-instalar-casaos.sh`: instala o CasaOS (que já traz o Docker).
- `stacks/base/`: Tailscale, Postgres, Adminer e Watchtower.
- `stacks/aux/`: Uptime Kuma (o papel definitivo da Pi).
- `stacks/apps/_modelo/` + `scripts/novo-app.sh`: criam um app a partir de uma imagem.
- `scripts/novo-banco.sh`: cria um banco e um usuário no Postgres compartilhado.
- `scripts/atualizar-app.sh`: atualização manual de um app (pull + recreate).
- `scripts/backup-postgres.sh`: dump diário dos bancos.
- `templates/github-actions/docker-image.yml`: workflow que gera a imagem `linux/arm64` (e `amd64`) no GHCR.

Limites esperados na Pi 3: 2–4 APIs leves (Node, Python, Go) + Postgres + Redis.
Java, .NET e Mongo ficam para a Fase 2.

**Critério de pronto:**
1. O painel do CasaOS abre por `http://<pi>` na rede local e pelo Tailscale.
2. Um app de exemplo, publicado via GitHub Actions, sobe com `novo-app.sh`.
3. Um push no repo do app gera uma imagem nova, que o Watchtower aplica em até 5 minutos.
4. O app conecta no Postgres compartilhado usando a URL gerada por `novo-banco.sh`.

### Fase 2: mini PC (futuro)

1. Comprar o mini PC usado (Lenovo M710q/M720q, Dell OptiPlex Micro, HP EliteDesk Mini; 16 GB).
2. Instalar Debian 12 ou Ubuntu Server e rodar `02-instalar-casaos.sh`, depois subir `stacks/base` (os mesmos arquivos funcionam em x86).
3. Migrar os apps (`/srv/apps/*`) e restaurar o dump do Postgres.
4. Na Pi 3, derrubar a `stacks/base` e deixar só a `stacks/aux`:
   - Uptime Kuma vigiando o mini PC, com alerta no Telegram;
   - backup noturno do Postgres do mini PC para o SSD da Pi;
   - Pi-hole (opcional);
   - Tailscale como porta de entrada reserva (subnet router).

## 5. Requisitos não funcionais

- **RAM na Pi 3:** a stack base usa no máximo ~450 MB, para sobrar espaço para os apps.
- **Segurança:** o painel, o Adminer e o Postgres não ficam expostos na internet. Só são acessados pela LAN e pelo Tailscale. Segredos ficam em `.env`, fora do git.
- **Portabilidade:** nenhum caminho é fixo além de `DATA_DIR` e `APPS_DIR`, e as imagens são multi-arch.

## 6. Riscos e pontos em aberto

- O cartão SD pode corromper com escrita constante; o mitigador é o SSD USB.
- O Watchtower original (containrrr) foi abandonado; uso o fork mantido `nickfedor/watchtower`.
- Imagens privadas no GHCR exigem um token (PAT `read:packages`) no Watchtower.
- O Funnel do Tailscale precisa ser liberado na ACL da tailnet.
- Os preços do mini PC precisam ser pesquisados antes da compra.
