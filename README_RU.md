# OpenClaw VPS Quickstart (Русский)

Безопасная установка OpenClaw на Ubuntu VPS одной командой.

## Быстрый старт

macOS / Linux:

```bash
curl -fsSL https://raw.githubusercontent.com/BABAK312/openclaw-vps-quickstart/v1.0.28/install.sh | bash -s -- --host <VPS_IP>
```

Windows (WSL2):

```powershell
wsl --install -d Ubuntu-24.04
wsl -d Ubuntu-24.04 -- bash -lc 'curl -fsSL https://raw.githubusercontent.com/BABAK312/openclaw-vps-quickstart/v1.0.28/install.sh | bash -s -- --host <VPS_IP>'
```

Если initial user не `root`:

```bash
curl -fsSL https://raw.githubusercontent.com/BABAK312/openclaw-vps-quickstart/v1.0.28/install.sh | bash -s -- --host <VPS_IP> --initial-user <USER>
```

## Полезные флаги

- `--no-upgrade`: пропустить `apt upgrade` (быстрее повторный прогон)
- `--extra-keys 1`: сгенерировать дополнительный ключ для телефона/планшета
- `--show-extra-private-keys`: вывести private key прямо в терминал (и в лог тоже; осторожно)
- `--no-harden-ssh`: пропустить SSH hardening

Пример:

```bash
curl -fsSL https://raw.githubusercontent.com/BABAK312/openclaw-vps-quickstart/v1.0.28/install.sh | FORCE_COLOR=1 bash -s -- --host <VPS_IP> --extra-keys 1 --show-extra-private-keys --no-upgrade
```

## После установки

Поднять туннель:

```bash
ssh -i ~/.ssh/openclaw_vps_ed25519 -N -L 18789:127.0.0.1:18789 openclaw@<VPS_IP>
```

Открыть UI:
- `http://127.0.0.1:18789`
- или быструю ссылку с токеном из вывода установщика.

Первичная настройка моделей/каналов:

```bash
ssh -i ~/.ssh/openclaw_vps_ed25519 openclaw@<VPS_IP>
openclaw onboard
```

## Проверка и ремонт

```bash
./verify.sh --host <VPS_IP>
./scripts/smoke-test.sh --host <VPS_IP>
./verify.sh --host <VPS_IP> --repair
```

## Подключение с телефона (Termius)

Путь к extra private key на macOS:
- `~/.ssh/openclaw_vps_extra_1_ed25519`

В Termius импортируется именно **private key**.

Параметры Host:
- Username: `openclaw`
- Address: `<VPS_IP>`
- Port: `22`
- Auth: импортированный ключ

## Обновление OpenClaw

```bash
ssh -i ~/.ssh/openclaw_vps_ed25519 openclaw@<VPS_IP> "~/.openclaw/bin/openclaw update status"
ssh -i ~/.ssh/openclaw_vps_ed25519 openclaw@<VPS_IP> "~/.openclaw/bin/openclaw update --yes"
```

## Reboot (если требуется)

```bash
ssh -i ~/.ssh/openclaw_vps_ed25519 root@<VPS_IP> "reboot"
```

## Контакты

- Telegram (Lobster): https://t.me/+MofnVybrWDU4YTRl
- GitHub Issues: https://github.com/BABAK312/openclaw-vps-quickstart/issues
