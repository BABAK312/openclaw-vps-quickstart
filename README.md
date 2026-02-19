# 🦞 Lobster OpenClaw VPS Quickstart

Security-first OpenClaw setup for Ubuntu VPS in one command.

## Language

- English: [README_EN.md](README_EN.md)
- Русский: [README_RU.md](README_RU.md)

## Quick Install (latest)

```bash
curl -fsSL https://raw.githubusercontent.com/BABAK312/openclaw-vps-quickstart/v1.0.32/install.sh | bash -s -- --host <VPS_IP>
```

## 60-Second Flow

1. Install on VPS (from your local machine):

```bash
curl -fsSL https://raw.githubusercontent.com/BABAK312/openclaw-vps-quickstart/v1.0.32/install.sh | bash -s -- --host <VPS_IP>
```

2. Open SSH tunnel (new local terminal tab):

```bash
ssh -i ~/.ssh/openclaw_vps_ed25519 -N -L 18789:127.0.0.1:18789 openclaw@<VPS_IP>
```

3. Open Control UI locally: `http://127.0.0.1:18789`
4. First-time setup on VPS:

```bash
ssh -i ~/.ssh/openclaw_vps_ed25519 openclaw@<VPS_IP>
openclaw onboard
```

5. Verify health:

```bash
./verify.sh --host <VPS_IP>
```

## Common Install Options

- `--initial-user <USER>`: if your provider gives non-root initial SSH user.
- `--extra-keys 1`: generate and add one extra SSH key for phone/tablet.
- `--show-extra-private-keys`: print extra private key content in terminal/log (sensitive).
- `--no-upgrade`: skip `apt upgrade` stage (faster rerun; OpenClaw setup still runs).
- `--ssh-alias <NAME>`: add short SSH alias in local `~/.ssh/config`.
- `--no-auto-reboot`: disable automatic reboot when reboot-required is detected.

## What You Get

- SSH key based access (password auth disabled by default).
- Dedicated non-root user: `openclaw`.
- Host hardening baseline: `UFW`, `Fail2ban`, `unattended-upgrades`.
- OpenClaw gateway bound to loopback with token auth.
- Automatic reboot (if required) with SSH wait + post-reboot verify.
- Verification and repair scripts for post-install diagnostics.

## Important Paths

Local machine:

- `~/.ssh/openclaw_vps_ed25519` (main SSH private key)
- `~/.ssh/openclaw_vps_extra_1_ed25519` (extra device private key, if requested)
- `logs/bootstrap-<timestamp>.log`
- `logs/extra-ssh-keys-<timestamp>.txt`

VPS:

- `/home/openclaw/.openclaw/openclaw.json` (OpenClaw config)
- `/home/openclaw/.config/systemd/user/openclaw-gateway.service` (gateway service)

## Day-2 Commands

Update OpenClaw:

```bash
ssh -i ~/.ssh/openclaw_vps_ed25519 openclaw@<VPS_IP> "~/.openclaw/bin/openclaw update status"
ssh -i ~/.ssh/openclaw_vps_ed25519 openclaw@<VPS_IP> "~/.openclaw/bin/openclaw update --yes"
```

Repair token mismatch:

```bash
./scripts/repair-token-mismatch.sh --host <VPS_IP>
```

Run quick smoke tests:

```bash
./scripts/smoke-test.sh --host <VPS_IP>
```

## Repo Map

- `install.sh`: one-command entrypoint from local machine.
- `bootstrap.sh`: full VPS bootstrap and hardening flow.
- `verify.sh`: diagnostics and optional repair mode.
- `scripts/smoke-test.sh`: quick health checks.
- `scripts/repair-token-mismatch.sh`: gateway token mismatch fixer.
- `scripts/tunnel.sh`: local SSH tunnel helper for Control UI.
- `scripts/connect.sh`: SSH connect helper.
- `scripts/get-token.sh`: fetch gateway token from VPS.
- `LANDING.md`: long-form landing content.

## Project Links

- Landing content: [LANDING.md](LANDING.md)
- Issues: https://github.com/BABAK312/openclaw-vps-quickstart/issues
- Telegram (Lobster): https://t.me/+MofnVybrWDU4YTRl

## License

This project is distributed under [LICENSE](LICENSE) (`All Rights Reserved`).
