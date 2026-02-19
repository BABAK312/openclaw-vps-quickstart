# OpenClaw VPS Quickstart (English)

One-command, security-first OpenClaw deployment on Ubuntu VPS.

## Quick Start

macOS / Linux:

```bash
curl -fsSL https://raw.githubusercontent.com/BABAK312/openclaw-vps-quickstart/v1.0.30/install.sh | bash -s -- --host <VPS_IP>
```

Windows (WSL2):

```powershell
wsl --install -d Ubuntu-24.04
wsl -d Ubuntu-24.04 -- bash -lc 'curl -fsSL https://raw.githubusercontent.com/BABAK312/openclaw-vps-quickstart/v1.0.30/install.sh | bash -s -- --host <VPS_IP>'
```

If initial SSH user is not `root`:

```bash
curl -fsSL https://raw.githubusercontent.com/BABAK312/openclaw-vps-quickstart/v1.0.30/install.sh | bash -s -- --host <VPS_IP> --initial-user <USER>
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
- Prints gateway token and quick UI URL.

## Useful Flags

- `--no-upgrade`: skip `apt upgrade` (faster rerun)
- `--extra-keys 1`: generate one extra device key (phone/tablet)
- `--show-extra-private-keys`: print extra private key text in terminal (also saved in log; use carefully)
- `--no-harden-ssh`: skip SSH hardening

Example:

```bash
curl -fsSL https://raw.githubusercontent.com/BABAK312/openclaw-vps-quickstart/v1.0.30/install.sh | FORCE_COLOR=1 bash -s -- --host <VPS_IP> --extra-keys 1 --show-extra-private-keys --no-upgrade
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

## Verify / Repair

```bash
./verify.sh --host <VPS_IP>
./scripts/smoke-test.sh --host <VPS_IP>
./verify.sh --host <VPS_IP> --repair
```

## Command Cheat Sheet

Install:

```bash
curl -fsSL https://raw.githubusercontent.com/BABAK312/openclaw-vps-quickstart/v1.0.30/install.sh | bash -s -- --host <VPS_IP>
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

## Reboot (if required)

```bash
ssh -i ~/.ssh/openclaw_vps_ed25519 root@<VPS_IP> "reboot"
```

## Contacts

- Telegram (Lobster): https://t.me/+MofnVybrWDU4YTRl
- GitHub Issues: https://github.com/BABAK312/openclaw-vps-quickstart/issues

## License

See [LICENSE](LICENSE). All rights reserved.
