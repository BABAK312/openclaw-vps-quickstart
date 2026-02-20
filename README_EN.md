# OpenClaw VPS Quickstart (English)

One-command, security-first OpenClaw deployment on Ubuntu VPS.

Full command reference:
- [COMMANDS_EN.md](COMMANDS_EN.md)
- [COMMANDS_RU.md](COMMANDS_RU.md)

## Quick Start

macOS / Linux:

```bash
curl -fsSL https://raw.githubusercontent.com/BABAK312/openclaw-vps-quickstart/v1.0.33/install.sh | bash -s -- --host <VPS_IP>
```

Windows (WSL2):

```powershell
wsl --install -d Ubuntu-24.04
wsl -d Ubuntu-24.04 -- bash -lc 'curl -fsSL https://raw.githubusercontent.com/BABAK312/openclaw-vps-quickstart/v1.0.33/install.sh | bash -s -- --host <VPS_IP>'
```

If initial SSH user is not `root`:

```bash
curl -fsSL https://raw.githubusercontent.com/BABAK312/openclaw-vps-quickstart/v1.0.33/install.sh | bash -s -- --host <VPS_IP> --initial-user <USER>
```

## What the Installer Configures

- Creates/reuses local key: `~/.ssh/openclaw_vps_ed25519`.
- Copies key to initial VPS user and validates key-only access.
- Creates service user `openclaw`.
- Enables hardening defaults:
  - `PasswordAuthentication no`
  - `PubkeyAuthentication yes`
  - UFW incoming deny + SSH allow
  - Fail2ban `sshd` jail
  - unattended-upgrades
- Installs/updates OpenClaw and configures gateway on loopback.
- Auto-reboots once when `/var/run/reboot-required` exists, waits for SSH, then runs final verify.
- Prints gateway token and quick UI URL.

## Useful Flags

- `--no-upgrade`: skip `apt upgrade` (faster rerun)
- `--extra-keys 1`: generate one extra device key (phone/tablet)
- `--show-extra-private-keys`: print extra private key text in terminal (also saved in log; use carefully)
- `--no-harden-ssh`: skip SSH hardening
- `--ssh-alias <name>`: add short local SSH alias in `~/.ssh/config` (example: `openclaw-1`)
- `--dir <PATH>`: use specific local quickstart directory
- `--no-auto-reboot`: keep manual reboot mode
- `--reboot-wait-timeout <seconds>`: override reboot wait timeout (default `420`)
- `--skip-verify`: skip final `verify.sh --repair` pass

Flag notes:
- `FORCE_COLOR=1` forces colored output for piped execution (`curl ... | bash`).
- Alias value is your local shortcut name, not a server-side identifier (`openclaw-1`, `openclaw-prod`, `openclaw-91` are all valid).

Example:

```bash
curl -fsSL https://raw.githubusercontent.com/BABAK312/openclaw-vps-quickstart/v1.0.33/install.sh | FORCE_COLOR=1 bash -s -- --host <VPS_IP> --extra-keys 1 --show-extra-private-keys --ssh-alias openclaw-1
```

## After Install

Create tunnel:

```bash
ssh -i ~/.ssh/openclaw_vps_ed25519 -N -L 18789:127.0.0.1:18789 openclaw@<VPS_IP>
```

Open Control UI:
- `http://127.0.0.1:18789`
- or quick token URL from installer output.

Initial provider/channel onboarding:

```bash
ssh -i ~/.ssh/openclaw_vps_ed25519 openclaw@<VPS_IP>
openclaw onboard
```

If you used `--ssh-alias`, connect with short command:

```bash
ssh openclaw-1
ssh -N -L 18789:127.0.0.1:18789 openclaw-1
```

Installer final output includes copy-ready commands (EN + RU) for:
- tunnel
- dashboard URL
- SSH connect
- onboarding
- gateway start/restart/stop/status

## Verify / Repair

```bash
./verify.sh --host <VPS_IP>
./scripts/smoke-test.sh --host <VPS_IP>
./verify.sh --host <VPS_IP> --repair
```

## Command Cheat Sheet

Install:

```bash
curl -fsSL https://raw.githubusercontent.com/BABAK312/openclaw-vps-quickstart/v1.0.33/install.sh | bash -s -- --host <VPS_IP>
```

Tunnel:

```bash
ssh -i ~/.ssh/openclaw_vps_ed25519 -N -L 18789:127.0.0.1:18789 openclaw@<VPS_IP>
```

Verify:

```bash
./verify.sh --host <VPS_IP>
```

Repair:

```bash
./scripts/repair-token-mismatch.sh --host <VPS_IP>
```

## Phone Access (Termius)

Generated extra key path on macOS:
- `~/.ssh/openclaw_vps_extra_1_ed25519`

Import this **private key** into Termius Keychain.

Host settings:
- Username: `openclaw`
- Address: `<VPS_IP>`
- Port: `22`
- Auth: imported key

## OpenClaw Update

```bash
ssh -i ~/.ssh/openclaw_vps_ed25519 openclaw@<VPS_IP> "~/.openclaw/bin/openclaw update status"
ssh -i ~/.ssh/openclaw_vps_ed25519 openclaw@<VPS_IP> "~/.openclaw/bin/openclaw update --yes"
```

## Reboot behavior

- Default: installer auto-reboots once if required.
- Manual mode: use `--no-auto-reboot`, then reboot yourself if needed:

```bash
ssh -i ~/.ssh/openclaw_vps_ed25519 root@<VPS_IP> "sudo reboot || reboot"
```

## Contacts

- Live landing (visual guide + Lobster Club): https://lobster-openclaw-landing.vercel.app
- Telegram (Lobster): https://t.me/+MofnVybrWDU4YTRl
- GitHub Issues: https://github.com/BABAK312/openclaw-vps-quickstart/issues

## License

See [LICENSE](LICENSE). All rights reserved.
