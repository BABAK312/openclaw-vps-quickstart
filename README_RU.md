# OpenClaw VPS Quickstart (Русский)

Безопасная установка OpenClaw на Ubuntu VPS одной командой.

Полный справочник команд:
- [COMMANDS_RU.md](COMMANDS_RU.md)
- [COMMANDS_EN.md](COMMANDS_EN.md)

## Быстрый старт

macOS / Linux:

```bash
curl -fsSL https://raw.githubusercontent.com/BABAK312/openclaw-vps-quickstart/v1.0.32/install.sh | bash -s -- --host <VPS_IP>
```

Windows (WSL2):

```powershell
wsl --install -d Ubuntu-24.04
wsl -d Ubuntu-24.04 -- bash -lc 'curl -fsSL https://raw.githubusercontent.com/BABAK312/openclaw-vps-quickstart/v1.0.32/install.sh | bash -s -- --host <VPS_IP>'
```

Если initial user не `root`:

```bash
curl -fsSL https://raw.githubusercontent.com/BABAK312/openclaw-vps-quickstart/v1.0.32/install.sh | bash -s -- --host <VPS_IP> --initial-user <USER>
```

## Что настраивает установщик

- Создаёт/использует локальный ключ `~/.ssh/openclaw_vps_ed25519`.
- Копирует ключ на VPS initial user и проверяет key-only вход.
- Создаёт отдельного пользователя `openclaw`.
- Включает hardening по умолчанию:
  - `PasswordAuthentication no`
  - `PubkeyAuthentication yes`
  - UFW: входящие deny + SSH allow
  - Fail2ban (`sshd`)
  - unattended-upgrades
- Ставит/обновляет OpenClaw и настраивает gateway на loopback.
- Если есть `/var/run/reboot-required`, автоматически делает один reboot, ждёт SSH и запускает финальную verify-проверку.
- Выводит gateway token и быструю ссылку для UI.

## Полезные флаги

- `--no-upgrade`: пропустить `apt upgrade` (быстрее повторный прогон)
- `--extra-keys 1`: сгенерировать дополнительный ключ для телефона/планшета
- `--show-extra-private-keys`: вывести private key прямо в терминал (и в лог тоже; осторожно)
- `--no-harden-ssh`: пропустить SSH hardening
- `--ssh-alias <name>`: добавить короткий SSH alias в `~/.ssh/config` (пример: `openclaw-1`)
- `--dir <PATH>`: использовать конкретную локальную папку quickstart
- `--no-auto-reboot`: оставить ручной reboot-режим
- `--reboot-wait-timeout <сек>`: изменить таймаут ожидания reboot (по умолчанию `420`)
- `--skip-verify`: пропустить финальный шаг `verify.sh --repair`

Пояснение флагов:
- `FORCE_COLOR=1` принудительно включает цветной вывод при запуске через `curl ... | bash`.
- Значение alias - это локальное имя-шорткат на твоём компьютере (`openclaw-1`, `openclaw-prod`, `openclaw-91` и т.п.).

Пример:

```bash
curl -fsSL https://raw.githubusercontent.com/BABAK312/openclaw-vps-quickstart/v1.0.32/install.sh | FORCE_COLOR=1 bash -s -- --host <VPS_IP> --extra-keys 1 --show-extra-private-keys --ssh-alias openclaw-1
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

Если использовал `--ssh-alias`, подключение короткой командой:

```bash
ssh openclaw-1
ssh -N -L 18789:127.0.0.1:18789 openclaw-1
```

В финальном выводе установщика теперь печатаются готовые команды (EN + RU):
- туннель
- URL дашборда
- SSH-подключение
- onboarding
- gateway status/start/restart/stop

## Проверка и ремонт

```bash
./verify.sh --host <VPS_IP>
./scripts/smoke-test.sh --host <VPS_IP>
./verify.sh --host <VPS_IP> --repair
```

## Шпаргалка команд

Установка:

```bash
curl -fsSL https://raw.githubusercontent.com/BABAK312/openclaw-vps-quickstart/v1.0.32/install.sh | bash -s -- --host <VPS_IP>
```

Туннель:

```bash
ssh -i ~/.ssh/openclaw_vps_ed25519 -N -L 18789:127.0.0.1:18789 openclaw@<VPS_IP>
```

Проверка:

```bash
./verify.sh --host <VPS_IP>
```

Ремонт token mismatch:

```bash
./scripts/repair-token-mismatch.sh --host <VPS_IP>
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

## Поведение reboot

- По умолчанию: установщик сам делает один reboot при необходимости.
- Ручной режим: добавь `--no-auto-reboot`, затем перезагрузи вручную:

```bash
ssh -i ~/.ssh/openclaw_vps_ed25519 root@<VPS_IP> "sudo reboot || reboot"
```

## Контакты

- Живой лендинг (подробный гайд с картинками + Lobster Club): https://lobster-openclaw-landing.vercel.app
- Telegram (Lobster): https://t.me/+MofnVybrWDU4YTRl
- GitHub Issues: https://github.com/BABAK312/openclaw-vps-quickstart/issues

## Лицензия

См. [LICENSE](LICENSE). Все права защищены.
