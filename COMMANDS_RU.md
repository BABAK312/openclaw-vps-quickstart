# OpenClaw VPS - Полный справочник команд (RU)

Практический каталог команд для локального компьютера и VPS.

## 1) Установка одной командой

Рекомендуется (с коротким SSH alias):

```bash
curl -fsSL https://raw.githubusercontent.com/BABAK312/openclaw-vps-quickstart/v1.0.32/install.sh | FORCE_COLOR=1 bash -s -- --host <VPS_IP> --ssh-alias openclaw-1
```

Минимальный вариант:

```bash
curl -fsSL https://raw.githubusercontent.com/BABAK312/openclaw-vps-quickstart/v1.0.32/install.sh | bash -s -- --host <VPS_IP>
```

Запуск из локальной папки quickstart (чтобы явно использовать текущую директорию):

```bash
curl -fsSL https://raw.githubusercontent.com/BABAK312/openclaw-vps-quickstart/v1.0.32/install.sh | FORCE_COLOR=1 bash -s -- --host <VPS_IP> --dir "<LOCAL_QUICKSTART_PATH>" --ssh-alias openclaw-1
```

## 2) Пояснение флагов установки

`FORCE_COLOR=1`
- Принудительно включает цветной вывод, когда скрипт запускается через `curl`.

`--host <VPS_IP>`
- Целевой IP/hostname VPS. Обязательный параметр.

`--initial-user <USER>`
- Первый SSH-пользователь от провайдера VPS (по умолчанию `root`).

`--ssh-alias <NAME>`
- Создаёт/обновляет локальный alias в `~/.ssh/config`.
- Имя произвольное: `openclaw-1`, `openclaw-prod`, `openclaw-91` и т.д.

`--extra-keys <N>`
- Генерирует и добавляет дополнительные SSH-ключи для других устройств.

`--no-upgrade`
- Пропускает этап `apt upgrade` (быстрее повторный прогон).

`--no-auto-reboot`
- Оставляет ручной режим reboot (по умолчанию reboot автоматический, если требуется).

`--reboot-wait-timeout <seconds>`
- Таймаут ожидания возврата SSH после авто-reboot (по умолчанию `420`).

`--skip-verify`
- Пропускает финальную проверку `verify --repair`.

`--dir <PATH>`
- Локальная рабочая папка quickstart-репозитория.

## 3) Подключение к VPS (пользователь OpenClaw)

Через alias:

```bash
ssh openclaw-1
```

Полная команда:

```bash
ssh -i ~/.ssh/openclaw_vps_ed25519 openclaw@<VPS_IP>
```

Под root:

```bash
ssh -i ~/.ssh/openclaw_vps_ed25519 root@<VPS_IP>
```

Под root через alias:

```bash
ssh openclaw-1 -l root
```

## 4) Открыть Control UI (панель)

Поднять локальный туннель через alias:

```bash
ssh -N -L 18789:127.0.0.1:18789 openclaw-1
```

Или полной командой:

```bash
ssh -i ~/.ssh/openclaw_vps_ed25519 -N -L 18789:127.0.0.1:18789 openclaw@<VPS_IP>
```

Потом открыть в браузере:
- `http://127.0.0.1:18789`
- или quick URL с `#token=...` из вывода установщика.

Получить актуальный token с VPS:

```bash
./scripts/get-token.sh --host <VPS_IP>
```

## 5) Основные команды OpenClaw на VPS

Первичная настройка:

```bash
openclaw onboard
```

Статус:

```bash
openclaw status
openclaw status --all
openclaw status --deep
```

Gateway service:

```bash
openclaw gateway status
openclaw gateway start
openclaw gateway stop
openclaw gateway restart
openclaw gateway install --force
```

Логи и диагностика:

```bash
openclaw logs --follow
openclaw doctor
openclaw doctor --fix --yes --non-interactive
openclaw security audit
openclaw security audit --deep
```

Обновление CLI:

```bash
openclaw update status
openclaw update --yes
```

## 6) Проверка и ремонт (из локального quickstart)

Проверка:

```bash
./verify.sh --host <VPS_IP>
```

Проверка с авторемонтом:

```bash
./verify.sh --host <VPS_IP> --repair
```

Быстрый smoke:

```bash
./scripts/smoke-test.sh --host <VPS_IP>
```

Ремонт token mismatch:

```bash
./scripts/repair-token-mismatch.sh --host <VPS_IP>
```

## 7) Reboot и post-upgrade

Поведение по умолчанию:
- Если есть `/var/run/reboot-required`, установщик сам делает reboot, ждёт SSH и запускает verify.

Ручной reboot (если использован `--no-auto-reboot`):

```bash
ssh -i ~/.ssh/openclaw_vps_ed25519 root@<VPS_IP> "sudo reboot || reboot"
```

Ручной reboot через alias:

```bash
ssh openclaw-1 -l root "sudo reboot || reboot"
```

## 8) Дополнительные helper-скрипты

Подключение:

```bash
./scripts/connect.sh --host <VPS_IP>
```

Туннель:

```bash
./scripts/tunnel.sh --host <VPS_IP>
```

## 9) Локальный reset для чистого ретеста (macOS)

```bash
./scripts/reset-local-macos.sh --server-host <VPS_IP> --remove-ssh-key --yes
find ~/.ssh -maxdepth 1 -type f \( -name 'openclaw_vps_extra_*_ed25519' -o -name 'openclaw_vps_extra_*_ed25519.pub' \) -delete
```

## 10) Управление alias в SSH config

Проверить alias-блок:

```bash
cat ~/.ssh/config
```

Удалить alias вручную:
- Удалить строки между:
  - `# >>> openclaw-vps-quickstart alias <NAME> >>>`
  - `# <<< openclaw-vps-quickstart alias <NAME> <<<`
